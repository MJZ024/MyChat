package connect

import (
	"encoding/json"

	"github.com/mychat/server/pkg/protocol"
	"go.uber.org/zap"
	"google.golang.org/protobuf/proto"
)

type WSHandler struct {
	logger        *zap.Logger
	OnSendMessage func(client *Client, req *protocol.SendMessageRequest)
	OnSyncRequest func(client *Client, req *protocol.SyncRequest)
	OnAck         func(client *Client, req *protocol.AckRequest)
	OnTyping      func(client *Client, req *protocol.TypingRequest)
	OnRead        func(client *Client, req *protocol.MessageReadRequest)
	OnRecall      func(client *Client, req *protocol.MessageRecallRequest)
	// JSON callbacks
	OnJSONSendMessage func(client *Client, msg *JSONIncomingMessage)
	OnJSONTyping      func(client *Client, msg *JSONIncomingMessage)
	OnJSONRecall      func(client *Client, msg *JSONIncomingMessage)
	OnJSONRead        func(client *Client, msg *JSONIncomingMessage)
}

func NewWSHandler(logger *zap.Logger) *WSHandler {
	return &WSHandler{logger: logger}
}

func (h *WSHandler) HandleMessage(client *Client, msgType protocol.MessageType, payload []byte) {
	switch msgType {
	case protocol.MessageType_HEARTBEAT:
		data, _ := EncodeEnvelope(protocol.MessageType_HEARTBEAT_ACK, &protocol.AckRequest{})
		client.send <- data

	case protocol.MessageType_SEND_MESSAGE:
		req := &protocol.SendMessageRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			h.logger.Error("unmarshal send_message", zap.Error(err))
			return
		}
		if h.OnSendMessage != nil {
			h.OnSendMessage(client, req)
		}

	case protocol.MessageType_SYNC_REQUEST:
		req := &protocol.SyncRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			h.logger.Error("unmarshal sync_request", zap.Error(err))
			return
		}
		if h.OnSyncRequest != nil {
			h.OnSyncRequest(client, req)
		}

	case protocol.MessageType_ACK:
		req := &protocol.AckRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			return
		}
		if h.OnAck != nil {
			h.OnAck(client, req)
		}

	case protocol.MessageType_TYPING:
		req := &protocol.TypingRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			return
		}
		if h.OnTyping != nil {
			h.OnTyping(client, req)
		}

	case protocol.MessageType_MESSAGE_READ:
		req := &protocol.MessageReadRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			return
		}
		if h.OnRead != nil {
			h.OnRead(client, req)
		}

	case protocol.MessageType_MESSAGE_RECALL:
		req := &protocol.MessageRecallRequest{}
		if err := proto.Unmarshal(payload, req); err != nil {
			return
		}
		if h.OnRecall != nil {
			h.OnRecall(client, req)
		}

	default:
		h.logger.Warn("unknown message type", zap.Int32("type", int32(msgType)))
	}
}

// HandleJSONMessage 处理客户端 JSON 消息
func (h *WSHandler) HandleJSONMessage(client *Client, msg *JSONIncomingMessage) {
	switch msg.Type {
	case "heartbeat":
		data, _ := json.Marshal(map[string]interface{}{
			"type":      "heartbeat_ack",
			"timestamp": msg.Timestamp,
		})
		client.send <- data

	case "send_message":
		if h.OnJSONSendMessage != nil {
			h.OnJSONSendMessage(client, msg)
		}

	case "typing":
		if h.OnJSONTyping != nil {
			h.OnJSONTyping(client, msg)
		}

	case "message_read":
		if h.OnJSONRead != nil {
			h.OnJSONRead(client, msg)
		}

	case "message_recall":
		if h.OnJSONRecall != nil {
			h.OnJSONRecall(client, msg)
		}

	default:
		h.logger.Debug("unknown json message type", zap.String("type", msg.Type))
	}
}

func SendToClient(client *Client, msgType protocol.MessageType, payload proto.Message) {
	data, err := EncodeEnvelope(msgType, payload)
	if err != nil {
		return
	}
	select {
	case client.send <- data:
	default:
	}
}

// SendJSONToClient sends a JSON message to a specific client
func SendJSONToClient(client *Client, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	select {
	case client.send <- data:
	default:
	}
}

