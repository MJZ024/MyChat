package connect

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/mychat/server/pkg/protocol"
	"github.com/mychat/server/pkg/util"
	"go.uber.org/zap"
	"google.golang.org/protobuf/proto"
)

// JSONIncomingMessage 客户端 JSON 消息格式
type JSONIncomingMessage struct {
	Type      string                 `json:"type"`
	Data      map[string]interface{} `json:"data"`
	Timestamp int64                  `json:"timestamp"`
	Seq       int64                  `json:"seq"`
}

// JSONMessageHandler 处理 JSON 格式的 WS 消息
type JSONMessageHandler interface {
	HandleJSONMessage(client *Client, msg *JSONIncomingMessage)
}

// Hub 管理所有 WebSocket 连接
type Hub struct {
	mu             sync.RWMutex
	clients        map[int64]map[*Client]bool // uid -> set of clients (multi-device)
	register       chan *Client
	unregister     chan *Client
	broadcast      chan *BroadcastMessage
	logger         *zap.Logger
	wsCfg          util.WebSocketConfig
	allowedOrigins []string
	msgHandler     MessageHandler
	jsonHandler    JSONMessageHandler
	onStatusChange func(uid int64, online bool)
}

// BroadcastMessage 广播消息
type BroadcastMessage struct {
	TargetUIDs []int64
	Envelope   *protocol.Envelope
}

// MessageHandler 处理收到的 protobuf 消息
type MessageHandler interface {
	HandleMessage(client *Client, msgType protocol.MessageType, payload []byte)
}

// Client 代表一个 WebSocket 连接
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
	UID  int64
}

func NewHub(logger *zap.Logger, wsCfg util.WebSocketConfig, allowedOrigins []string, handler MessageHandler) *Hub {
	return &Hub{
		clients:        make(map[int64]map[*Client]bool),
		register:       make(chan *Client, 64),
		unregister:     make(chan *Client, 64),
		broadcast:      make(chan *BroadcastMessage, 256),
		logger:         logger,
		wsCfg:          wsCfg,
		allowedOrigins: allowedOrigins,
		msgHandler:     handler,
	}
}

func (h *Hub) SetJSONHandler(handler JSONMessageHandler) {
	h.jsonHandler = handler
}

func (h *Hub) SetOnStatusChange(fn func(uid int64, online bool)) {
	h.onStatusChange = fn
}

func (h *Hub) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.logger.Info("hub shutting down")
			return
		case client := <-h.register:
			h.mu.Lock()
			wasOffline := len(h.clients[client.UID]) == 0
			if h.clients[client.UID] == nil {
				h.clients[client.UID] = make(map[*Client]bool)
			}
			h.clients[client.UID][client] = true
			h.mu.Unlock()
			h.logger.Info("client connected", zap.Int64("uid", client.UID))
			if wasOffline && h.onStatusChange != nil {
				h.onStatusChange(client.UID, true)
			}

		case client := <-h.unregister:
			h.mu.Lock()
			if clients, ok := h.clients[client.UID]; ok {
				if _, exists := clients[client]; exists {
					delete(clients, client)
					if len(clients) == 0 {
						delete(h.clients, client.UID)
					}
				}
			}
			nowOffline := len(h.clients[client.UID]) == 0
			h.mu.Unlock()
			close(client.send)
			h.logger.Info("client disconnected", zap.Int64("uid", client.UID))
			if nowOffline && h.onStatusChange != nil {
				h.onStatusChange(client.UID, false)
			}

		case msg := <-h.broadcast:
			h.mu.RLock()
			for _, uid := range msg.TargetUIDs {
				if clients, ok := h.clients[uid]; ok {
					data, _ := proto.Marshal(msg.Envelope)
					for c := range clients {
						select {
						case c.send <- data:
						default:
							// Client buffer full, skip
						}
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) IsOnline(uid int64) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	clients, ok := h.clients[uid]
	return ok && len(clients) > 0
}

func (h *Hub) GetOnlineUsers() []int64 {
	h.mu.RLock()
	defer h.mu.RUnlock()
	uids := make([]int64, 0, len(h.clients))
	for uid := range h.clients {
		uids = append(uids, uid)
	}
	return uids
}

func (h *Hub) SendToUser(uid int64, envelope *protocol.Envelope) {
	h.broadcast <- &BroadcastMessage{
		TargetUIDs: []int64{uid},
		Envelope:   envelope,
	}
}

func (h *Hub) SendToUsers(uids []int64, envelope *protocol.Envelope) {
	h.broadcast <- &BroadcastMessage{
		TargetUIDs: uids,
		Envelope:   envelope,
	}
}

// SendJSONToUser 发送 JSON 消息给指定用户的所有设备
func (h *Hub) SendJSONToUser(uid int64, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	if clients, ok := h.clients[uid]; ok {
		for c := range clients {
			select {
			case c.send <- data:
			default:
			}
		}
	}
}

// SendJSONToUsers 发送 JSON 消息给多个用户
func (h *Hub) SendJSONToUsers(uids []int64, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, uid := range uids {
		if clients, ok := h.clients[uid]; ok {
			for c := range clients {
				select {
				case c.send <- data:
				default:
				}
			}
		}
	}
}

func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request, uid int64) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin: func(r *http.Request) bool {
			if len(h.allowedOrigins) == 0 {
				return true
			}
			return util.IsOriginAllowed(h.allowedOrigins, r.Header.Get("Origin"))
		},
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.logger.Error("websocket upgrade failed", zap.Error(err))
		return
	}

	client := &Client{
		hub:  h,
		conn: conn,
		send: make(chan []byte, 256),
		UID:  uid,
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(c.hub.wsCfg.MaxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(c.hub.wsCfg.PongTimeoutDuration()))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(c.hub.wsCfg.PongTimeoutDuration()))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				c.hub.logger.Error("websocket read error", zap.Error(err))
			} else if netErr, ok := err.(interface{ Timeout() bool }); ok && netErr.Timeout() {
				c.hub.logger.Warn("pong timeout, closing dead connection",
					zap.Int64("uid", c.UID))
			}
			break
		}

		// Try protobuf first
		envelope := &protocol.Envelope{}
		if err := proto.Unmarshal(message, envelope); err == nil {
			c.hub.msgHandler.HandleMessage(c, envelope.Type, envelope.Payload)
			continue
		}

		// Fallback: try JSON format (used by Flutter client)
		var jsonMsg JSONIncomingMessage
		if err := json.Unmarshal(message, &jsonMsg); err == nil && jsonMsg.Type != "" {
			if c.hub.jsonHandler != nil {
				c.hub.jsonHandler.HandleJSONMessage(c, &jsonMsg)
			}
			continue
		}

		c.hub.logger.Error("failed to unmarshal message")
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(c.hub.wsCfg.PingPeriodDuration())
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(c.hub.wsCfg.WriteTimeoutDuration()))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			// JSON messages are sent as text, protobuf as binary
			msgType := websocket.BinaryMessage
			if len(message) > 0 && message[0] == '{' {
				msgType = websocket.TextMessage
			}
			if err := c.conn.WriteMessage(msgType, message); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(c.hub.wsCfg.WriteTimeoutDuration()))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// EncodeEnvelope 供其他模块发送消息时使用
func EncodeEnvelope(msgType protocol.MessageType, payload proto.Message) ([]byte, error) {
	data, err := proto.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal payload: %w", err)
	}

	envelope := &protocol.Envelope{
		Type:      msgType,
		Payload:   data,
		Timestamp: time.Now().UnixMilli(),
	}

	return proto.Marshal(envelope)
}

// EncodeEnvelopeBase64 编码为 base64（供调试用）
func EncodeEnvelopeBase64(msgType protocol.MessageType, payload proto.Message) (string, error) {
	data, err := EncodeEnvelope(msgType, payload)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(data), nil
}
