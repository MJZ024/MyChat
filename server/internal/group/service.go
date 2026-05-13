package group

import (
	"errors"
	"fmt"

	"github.com/mychat/server/internal/model"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type Service struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewService(db *gorm.DB, logger *zap.Logger) *Service {
	return &Service{db: db, logger: logger}
}

// CreateGroup creates a group conversation
func (s *Service) CreateGroup(creatorUID int64, name string, memberUIDs []int64) (*model.Conversation, error) {
	conv := model.Conversation{
		Type: 2, // group
		Name: name,
	}
	if err := s.db.Create(&conv).Error; err != nil {
		return nil, fmt.Errorf("create conversation: %w", err)
	}

	// Add creator as owner
	members := []model.ConversationMember{
		{
			ConversationID: conv.ID,
			UserID:         creatorUID,
			Role:           2, // owner
		},
	}

	// Add other members
	for _, uid := range memberUIDs {
		if uid == creatorUID {
			continue
		}
		members = append(members, model.ConversationMember{
			ConversationID: conv.ID,
			UserID:         uid,
			Role:           0, // member
		})
	}

	if err := s.db.Create(&members).Error; err != nil {
		return nil, fmt.Errorf("create members: %w", err)
	}

	// Create group extension
	group := model.Group{
		ConversationID: conv.ID,
		MaxMembers:     500,
		CreatedBy:      creatorUID,
	}
	if err := s.db.Create(&group).Error; err != nil {
		return nil, fmt.Errorf("create group: %w", err)
	}

	// Create user_conversations for all members
	allUIDs := append([]int64{creatorUID}, memberUIDs...)
	ucs := make([]model.UserConversation, 0, len(allUIDs))
	for _, uid := range allUIDs {
		ucs = append(ucs, model.UserConversation{
			UserID:         uid,
			ConversationID: conv.ID,
		})
	}
	s.db.Create(&ucs)

	return &conv, nil
}

// InviteMember adds a member to a group
func (s *Service) InviteMember(groupConvID, inviterUID, targetUID int64) error {
	// Verify inviter is a member with admin+ role
	if !s.isAtLeast(groupConvID, inviterUID, 1) {
		return errors.New("没有邀请权限")
	}

	// Check if already a member
	var count int64
	s.db.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", groupConvID, targetUID).
		Count(&count)
	if count > 0 {
		return errors.New("已经是群成员")
	}

	// Check max members
	var group model.Group
	if err := s.db.Where("conversation_id = ?", groupConvID).First(&group).Error; err == nil {
		var memberCount int64
		s.db.Model(&model.ConversationMember{}).
			Where("conversation_id = ?", groupConvID).
			Count(&memberCount)
		if int(memberCount) >= group.MaxMembers {
			return errors.New("群已满员")
		}
	}

	member := model.ConversationMember{
		ConversationID: groupConvID,
		UserID:         targetUID,
		Role:           0,
	}
	if err := s.db.Create(&member).Error; err != nil {
		return fmt.Errorf("create member: %w", err)
	}

	// Create user_conversation
	uc := model.UserConversation{
		UserID:         targetUID,
		ConversationID: groupConvID,
	}
	s.db.Create(&uc)

	return nil
}

// LeaveGroup removes a member from a group
func (s *Service) LeaveGroup(groupConvID, uid int64) error {
	var member model.ConversationMember
	if err := s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, uid).First(&member).Error; err != nil {
		return errors.New("你不是群成员")
	}
	if member.Role == 2 {
		return errors.New("群主不能退群，请先转让群主")
	}

	s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, uid).Delete(&model.ConversationMember{})
	s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, uid).Delete(&model.UserConversation{})
	return nil
}

// KickMember removes a member (admin/owner only)
func (s *Service) KickMember(groupConvID, operatorUID, targetUID int64) error {
	if !s.isAtLeast(groupConvID, operatorUID, 1) {
		return errors.New("没有权限")
	}

	var target model.ConversationMember
	if err := s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, targetUID).First(&target).Error; err != nil {
		return errors.New("\u76ee\u6807\u7528\u6237\u4e0d\u662f\u7fa4\u6210\u5458")
	}
	if target.Role == 2 {
		return errors.New("不能踢出群主")
	}

	s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, targetUID).Delete(&model.ConversationMember{})
	s.db.Where("conversation_id = ? AND user_id = ?", groupConvID, targetUID).Delete(&model.UserConversation{})
	return nil
}

// GetGroupMembers returns all members of a group
func (s *Service) GetGroupMembers(groupConvID int64) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	err := s.db.Model(&model.ConversationMember{}).
		Select("conversation_members.role, conversation_members.joined_at, users.id as uid, users.username, users.nickname, users.avatar_url").
		Joins("JOIN users ON users.id = conversation_members.user_id").
		Where("conversation_members.conversation_id = ?", groupConvID).
		Order("conversation_members.role DESC").
		Find(&results).Error
	return results, err
}

// UpdateGroupInfo updates group name/avatar
func (s *Service) UpdateGroupInfo(groupConvID, operatorUID int64, updates map[string]interface{}) error {
	if !s.isAtLeast(groupConvID, operatorUID, 1) {
		return errors.New("没有权限")
	}

	allowed := map[string]bool{"name": true, "avatar_url": true}
	filtered := make(map[string]interface{})
	for k, v := range updates {
		if allowed[k] {
			filtered[k] = v
		}
	}
	if len(filtered) == 0 {
		return errors.New("没有有效的更新字段")
	}

	return s.db.Model(&model.Conversation{}).Where("id = ?", groupConvID).Updates(filtered).Error
}

// GetGroupInfo returns group details
func (s *Service) GetGroupInfo(groupConvID int64) (*model.Conversation, *model.Group, error) {
	var conv model.Conversation
	if err := s.db.First(&conv, groupConvID).Error; err != nil {
		return nil, nil, err
	}
	var group model.Group
	s.db.Where("conversation_id = ?", groupConvID).First(&group)
	return &conv, &group, nil
}

func (s *Service) isAtLeast(convID, uid int64, minRole int) bool {
	var member model.ConversationMember
	if err := s.db.Where("conversation_id = ? AND user_id = ?", convID, uid).First(&member).Error; err != nil {
		return false
	}
	return member.Role >= minRole
}
