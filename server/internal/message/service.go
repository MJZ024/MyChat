package message

import (
	"errors"
	"fmt"
	"time"

	"github.com/mychat/server/internal/connect"
	"github.com/mychat/server/internal/model"
	"github.com/mychat/server/pkg/protocol"
	"go.uber.org/zap"
	"google.golang.org/protobuf/proto"
	"gorm.io/gorm"
)

type Service struct {
	db     *gorm.DB
	hub    *connect.Hub
	logger *zap.Logger
}

func NewService(db *gorm.DB, hub *connect.Hub, logger *zap.Logger) *Service {
	return &Service{db: db, hub: hub, logger: logger}
}

func (s *Service) GetOrCreateSingleConversation(uid1, uid2 int64) (int64, error) {
	// Find conversation where both users are members and type=single
	var convID int64
	err := s.db.Raw(`
		SELECT cm1.conversation_id
		FROM conversation_members cm1
		JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
		JOIN conversations c ON c.id = cm1.conversation_id
		WHERE cm1.user_id = ? AND cm2.user_id = ? AND c.type = 1
		LIMIT 1
	`, uid1, uid2).Scan(&convID).Error

	if err == nil && convID > 0 {
		// Ensure user_conversations exist
		for _, uid := range []int64{uid1, uid2} {
			s.db.Where("user_id = ? AND conversation_id = ?", uid, convID).
				FirstOrCreate(&model.UserConversation{
					UserID:         uid,
					ConversationID: convID,
				})
		}
		return convID, nil
	}

	// Create new conversation
	conv := model.Conversation{Type: 1} // 1=single
	if err := s.db.Create(&conv).Error; err != nil {
		return 0, fmt.Errorf("create conversation: %w", err)
	}

	members := []model.ConversationMember{
		{ConversationID: conv.ID, UserID: uid1},
		{ConversationID: conv.ID, UserID: uid2},
	}
	if err := s.db.Create(&members).Error; err != nil {
		return 0, fmt.Errorf("create members: %w", err)
	}

	// Create user_conversations
	uc := []model.UserConversation{
		{UserID: uid1, ConversationID: conv.ID},
		{UserID: uid2, ConversationID: conv.ID},
	}
	s.db.Create(&uc)

	return conv.ID, nil
}

func (s *Service) SendMessage(senderUID int64, req *protocol.SendMessageRequest) (*protocol.ChatMessage, error) {
	if req.ChatType == protocol.ChatType_SINGLE {
		return s.sendSingleMessage(senderUID, req)
	}
	return s.sendGroupMessage(senderUID, req)
}

func (s *Service) sendSingleMessage(senderUID int64, req *protocol.SendMessageRequest) (*protocol.ChatMessage, error) {
	var toUID int64
	if _, err := fmt.Sscanf(req.ToId, "%d", &toUID); err != nil {
		return nil, errors.New("消息发送目标无效")
	}

	convID, err := s.GetOrCreateSingleConversation(senderUID, toUID)
	if err != nil {
		return nil, err
	}

	msg, err := s.storeAndBroadcast(senderUID, convID, toUID, req)
	if err != nil {
		return nil, err
	}

		// Also send to sender's other devices
		s.hub.SendToUser(senderUID, s.makeRecvEnvelope(msg))
		// Push to recipient in real-time
		if toUID > 0 && toUID != senderUID {
			s.hub.SendToUser(toUID, s.makeRecvEnvelope(msg))
		}

		return msg, nil
		}

func (s *Service) sendGroupMessage(senderUID int64, req *protocol.SendMessageRequest) (*protocol.ChatMessage, error) {
	var convID int64
	if _, err := fmt.Sscanf(req.ToId, "%d", &convID); err != nil {
		return nil, errors.New("群聊ID无效")
	}

	// Verify sender is member
	var count int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, senderUID).
		Count(&count)
	if count == 0 {
		return nil, errors.New("你不是该群成员")
	}

	// Get all member UIDs
	var memberIDs []int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", convID).
		Pluck("user_id", &memberIDs)

	msg, err := s.storeAndBroadcast(senderUID, convID, 0, req)
	if err != nil {
		return nil, err
	}

	// Broadcast to all members
	s.hub.SendToUsers(memberIDs, s.makeRecvEnvelope(msg))

	return msg, nil
}

func (s *Service) storeAndBroadcast(senderUID, convID, toUID int64, req *protocol.SendMessageRequest) (*protocol.ChatMessage, error) {
	// Get next seq for conversation
	var maxSeq int64
	s.db.Model(&model.Message{}).Where("conversation_id = ?", convID).Select("COALESCE(MAX(seq), 0)").Scan(&maxSeq)
	nextSeq := maxSeq + 1

	dbMsg := model.Message{
		ConversationID: convID,
		SenderID:       senderUID,
		Seq:            nextSeq,
		ContentType:    int(req.ContentType),
		Content:        req.Content,
	}
	if req.ReplyTo != "" {
		var replyID int64
		if _, err := fmt.Sscanf(req.ReplyTo, "%d", &replyID); err == nil {
			dbMsg.ReplyToID = &replyID
		}
	}

	if err := s.db.Create(&dbMsg).Error; err != nil {
		return nil, fmt.Errorf("store message: %w", err)
	}

	// Build preview text
	preview := req.Content
	switch req.ContentType {
	case protocol.ContentType_IMAGE:
		preview = "[图片]"
	case protocol.ContentType_VOICE:
		preview = "[语音]"
	case protocol.ContentType_FILE:
		preview = "[文件]"
	}
	if len(preview) > 50 {
		preview = preview[:50]
	}

	// Upsert user_conversations for all members
	now := time.Now()
	var memberIDs []int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", convID).
		Pluck("user_id", &memberIDs)
	for _, mid := range memberIDs {
		s.db.Where("user_id = ? AND conversation_id = ?", mid, convID).
			FirstOrCreate(&model.UserConversation{
				UserID:         mid,
				ConversationID: convID,
			})
		updates := map[string]interface{}{
			"last_msg_time":   now,
			"last_msg_preview": preview,
		}
		if mid != senderUID {
			updates["unread_count"] = gorm.Expr("unread_count + 1")
		}
		s.db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", mid, convID).
			Updates(updates)
	}

	chatMsg := &protocol.ChatMessage{
		MsgId:       fmt.Sprintf("%d", dbMsg.ID),
		FromUid:     senderUID,
		ToId:        req.ToId,
		ChatType:    req.ChatType,
		ContentType: req.ContentType,
		Content:     req.Content,
		ReplyTo:     req.ReplyTo,
		CreatedAt:   dbMsg.CreatedAt.UnixMilli(),
	}

	return chatMsg, nil
}

func (s *Service) GetHistory(convID, lastSeq, minSeq int64, limit int) ([]*protocol.ChatMessage, error) {
	var msgs []model.Message
	query := s.db.Where("conversation_id = ? AND recalled = false", convID)
	if lastSeq > 0 {
		query = query.Where("seq < ?", lastSeq)
	}
	if minSeq > 0 {
		query = query.Where("seq > ?", minSeq)
	}
	query = query.Order("seq DESC").Limit(limit)

	if err := query.Find(&msgs).Error; err != nil {
		return nil, err
	}

	result := make([]*protocol.ChatMessage, 0, len(msgs))
	for i := len(msgs) - 1; i >= 0; i-- {
		m := msgs[i]
		result = append(result, &protocol.ChatMessage{
			MsgId:       fmt.Sprintf("%d", m.ID),
			FromUid:     m.SenderID,
			ToId:        fmt.Sprintf("%d", m.ConversationID),
			ContentType: protocol.ContentType(m.ContentType),
			Content:     m.Content,
			CreatedAt:   m.CreatedAt.UnixMilli(),
		})
	}

	return result, nil
}

func (s *Service) RecallMessage(msgID, senderUID int64) error {
	result := s.db.Model(&model.Message{}).
		Where("id = ? AND sender_id = ?", msgID, senderUID).
		Update("recalled", true)
	if result.RowsAffected == 0 {
		return errors.New("消息不存在或无权操作")
	}
	return nil
}

func (s *Service) GetSyncMessages(uid int64, lastSeq int64, limit int) ([]*protocol.ChatMessage, error) {
	// Get all conversations for this user
	var convIDs []int64
	s.db.Model(&model.UserConversation{}).
		Where("user_id = ?", uid).
		Pluck("conversation_id", &convIDs)

	if len(convIDs) == 0 {
		return nil, nil
	}

	var msgs []model.Message
	s.db.Where("conversation_id IN ? AND seq > ? AND recalled = false", convIDs, lastSeq).
		Order("seq ASC").
		Limit(limit).
		Find(&msgs)

	result := make([]*protocol.ChatMessage, 0, len(msgs))
	for _, m := range msgs {
		result = append(result, &protocol.ChatMessage{
			MsgId:       fmt.Sprintf("%d", m.ID),
			FromUid:     m.SenderID,
			ToId:        fmt.Sprintf("%d", m.ConversationID),
			ContentType: protocol.ContentType(m.ContentType),
			Content:     m.Content,
			CreatedAt:   m.CreatedAt.UnixMilli(),
		})
	}

	return result, nil
}

func (s *Service) makeRecvEnvelope(msg *protocol.ChatMessage) *protocol.Envelope {
	data, _ := proto.Marshal(msg)
	return &protocol.Envelope{
		Type:      protocol.MessageType_RECV_MESSAGE,
		Payload:   data,
		Timestamp: time.Now().UnixMilli(),
	}
}

// ForwardMessages 转发消息到指定会话
func (s *Service) ForwardMessages(senderUID int64, msgIDs []int64, targetConvID int64) ([]*protocol.ChatMessage, error) {
	// Verify sender is member of target conversation
	var count int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", targetConvID, senderUID).
		Count(&count)
	if count == 0 {
		return nil, errors.New("你不是目标会话的成员")
	}

	var sourceMsgs []model.Message
	if err := s.db.Where("id IN ? AND recalled = false", msgIDs).Find(&sourceMsgs).Error; err != nil {
		return nil, fmt.Errorf("fetch source messages: %w", err)
	}
	if len(sourceMsgs) == 0 {
		return nil, errors.New("未找到消息")
	}

	// Get max seq
	var maxSeq int64
	s.db.Model(&model.Message{}).Where("conversation_id = ?", targetConvID).
		Select("COALESCE(MAX(seq), 0)").Scan(&maxSeq)

	var forwarded []*protocol.ChatMessage
	for i, src := range sourceMsgs {
		nextSeq := maxSeq + int64(i) + 1
		newMsg := model.Message{
			ConversationID: targetConvID,
			SenderID:       senderUID,
			Seq:            nextSeq,
			ContentType:    src.ContentType,
			Content:        src.Content,
		}
		if err := s.db.Create(&newMsg).Error; err != nil {
			return nil, fmt.Errorf("create forwarded message: %w", err)
		}

		forwarded = append(forwarded, &protocol.ChatMessage{
			MsgId:       fmt.Sprintf("%d", newMsg.ID),
			FromUid:     senderUID,
			ToId:        fmt.Sprintf("%d", targetConvID),
			ContentType: protocol.ContentType(newMsg.ContentType),
			Content:     newMsg.Content,
			CreatedAt:   newMsg.CreatedAt.UnixMilli(),
		})
	}

	// Upsert user_conversations for all members
	now := time.Now()
	cnt := len(forwarded)
	var fwdMemberIDs []int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", targetConvID).
		Pluck("user_id", &fwdMemberIDs)
	for _, mid := range fwdMemberIDs {
		s.db.Where("user_id = ? AND conversation_id = ?", mid, targetConvID).
			FirstOrCreate(&model.UserConversation{
				UserID:         mid,
				ConversationID: targetConvID,
			})
		updates := map[string]interface{}{
			"last_msg_time": now,
		}
		if mid != senderUID {
			updates["unread_count"] = gorm.Expr("unread_count + ?", cnt)
		}
		s.db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", mid, targetConvID).
			Updates(updates)
	}

	// Broadcast to target conversation members
	var memberIDs []int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", targetConvID).
		Pluck("user_id", &memberIDs)
	for _, msg := range forwarded {
		s.hub.SendToUsers(memberIDs, s.makeRecvEnvelope(msg))
	}

	return forwarded, nil
}

// SearchMessages 搜索用户的所有可见消息
func (s *Service) SearchMessages(uid int64, query string, convID int64, limit int) ([]map[string]interface{}, error) {
	var results []map[string]interface{}

	convIDs := []int64{}
	if convID > 0 {
		convIDs = append(convIDs, convID)
	} else {
		s.db.Model(&model.ConversationMember{}).
			Where("user_id = ?", uid).
			Pluck("conversation_id", &convIDs)
	}

	if len(convIDs) == 0 {
		return nil, nil
	}

	like := "%" + query + "%"
	err := s.db.Model(&model.Message{}).
		Select("messages.*, users.nickname as sender_name, users.avatar_url as sender_avatar").
		Joins("JOIN users ON users.id = messages.sender_id").
		Where("messages.conversation_id IN ? AND messages.content_type = 0 AND messages.content ILIKE ? AND messages.recalled = false", convIDs, like).
		Order("messages.created_at DESC").
		Limit(limit).
		Find(&results).Error

	return results, err
}

// GetMessageByID 获取单条消息（用于回复引用）
func (s *Service) GetMessageByID(msgID int64) (*protocol.ChatMessage, error) {
	var msg model.Message
	if err := s.db.First(&msg, msgID).Error; err != nil {
		return nil, err
	}
	return &protocol.ChatMessage{
		MsgId:       fmt.Sprintf("%d", msg.ID),
		FromUid:     msg.SenderID,
		ToId:        fmt.Sprintf("%d", msg.ConversationID),
		ContentType: protocol.ContentType(msg.ContentType),
		Content:     msg.Content,
		CreatedAt:   msg.CreatedAt.UnixMilli(),
	}, nil
}

// MakeRecvJSON 生成 JSON 格式的接收消息
func MakeRecvJSON(msg *protocol.ChatMessage) map[string]interface{} {
	return map[string]interface{}{
		"type": "recv_message",
		"data": map[string]interface{}{
			"msg_id":       msg.MsgId,
			"from_uid":     msg.FromUid,
			"to_id":        msg.ToId,
			"chat_type":    int32(msg.ChatType),
			"content_type": int32(msg.ContentType),
			"content":      msg.Content,
			"reply_to":     msg.ReplyTo,
			"created_at":   msg.CreatedAt,
		},
	}
}
