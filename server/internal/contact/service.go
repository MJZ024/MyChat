package contact

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

// SearchUsers searches users by username or nickname
func (s *Service) SearchUsers(query string, selfUID int64) ([]model.User, error) {
	var users []model.User
	like := "%" + query + "%"
	err := s.db.Where("(username ILIKE ? OR nickname ILIKE ?) AND id != ?", like, like, selfUID).
		Limit(20).
		Find(&users).Error
	return users, err
}

// SendFriendRequest creates a friend request
func (s *Service) SendFriendRequest(fromUID, toUID int64, message string) (*model.FriendRequest, error) {
	if fromUID == toUID {
		return nil, errors.New("不能添加自己为好友")
	}

	// Check if already friends
	var count int64
	s.db.Model(&model.Contact{}).
		Where("user_id = ? AND friend_id = ? AND blocked = false", fromUID, toUID).
		Count(&count)
	if count > 0 {
		return nil, errors.New("已经是好友")
	}

	// Check pending request
	s.db.Model(&model.FriendRequest{}).
		Where("from_uid = ? AND to_uid = ? AND status = 0", fromUID, toUID).
		Count(&count)
	if count > 0 {
		return nil, errors.New("已发送过好友申请，请等待对方同意")
	}

	req := &model.FriendRequest{
		FromUID: fromUID,
		ToUID:   toUID,
		Message: message,
		Status:  0,
	}
	if err := s.db.Create(req).Error; err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	return req, nil
}

// AcceptFriendRequest accepts a friend request
func (s *Service) AcceptFriendRequest(requestID, selfUID int64) error {
	var req model.FriendRequest
	if err := s.db.First(&req, requestID).Error; err != nil {
		return errors.New("请求不存在")
	}
	if req.ToUID != selfUID {
		return errors.New("不是你的好友请求")
	}
	if req.Status != 0 {
		return errors.New("请求已处理")
	}

	return s.db.Transaction(func(tx *gorm.DB) error {
		// Update request status
		if err := tx.Model(&req).Update("status", 1).Error; err != nil {
			return err
		}

		// Create bidirectional contacts
		contacts := []model.Contact{
			{UserID: req.FromUID, FriendID: req.ToUID},
			{UserID: req.ToUID, FriendID: req.FromUID},
		}
		if err := tx.Create(&contacts).Error; err != nil {
			return fmt.Errorf("create contacts: %w", err)
		}

		return nil
	})
}

// RejectFriendRequest rejects a friend request
func (s *Service) RejectFriendRequest(requestID, selfUID int64) error {
	result := s.db.Model(&model.FriendRequest{}).
		Where("id = ? AND to_uid = ? AND status = 0", requestID, selfUID).
		Update("status", 2)
	if result.RowsAffected == 0 {
		return errors.New("请求不存在或已处理")
	}
	return nil
}

// GetFriendList returns the friend list for a user
func (s *Service) GetFriendList(uid int64) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	err := s.db.Model(&model.Contact{}).
		Select("contacts.id as contact_id, contacts.alias, contacts.blocked, users.id as uid, users.username, users.nickname, users.avatar_url").
		Joins("JOIN users ON users.id = contacts.friend_id").
		Where("contacts.user_id = ?", uid).
		Order("users.nickname ASC").
		Find(&results).Error
	return results, err
}

// DeleteFriend removes a friend (both directions)
func (s *Service) DeleteFriend(uid, friendID int64) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		tx.Where("user_id = ? AND friend_id = ?", uid, friendID).Delete(&model.Contact{})
		tx.Where("user_id = ? AND friend_id = ?", friendID, uid).Delete(&model.Contact{})
		return nil
	})
}

// BlockUser blocks a user
func (s *Service) BlockUser(uid, targetUID int64) error {
	result := s.db.Model(&model.Contact{}).
		Where("user_id = ? AND friend_id = ?", uid, targetUID).
		Update("blocked", true)
	if result.RowsAffected == 0 {
		return errors.New("不是好友关系")
	}
	return nil
}

// UnblockUser removes a block
func (s *Service) UnblockUser(uid, targetUID int64) error {
	result := s.db.Model(&model.Contact{}).
		Where("user_id = ? AND friend_id = ?", uid, targetUID).
		Update("blocked", false)
	if result.RowsAffected == 0 {
		return errors.New("不是好友关系")
	}
	return nil
}

// GetPendingRequests returns pending friend requests for a user
func (s *Service) GetPendingRequests(uid int64) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	err := s.db.Model(&model.FriendRequest{}).
		Select("friend_requests.id, friend_requests.message, friend_requests.status, friend_requests.created_at, users.id as from_uid, users.username as from_username, users.nickname as from_nickname, users.avatar_url as from_avatar").
		Joins("JOIN users ON users.id = friend_requests.from_uid").
		Where("friend_requests.to_uid = ? AND friend_requests.status = 0", uid).
		Order("friend_requests.created_at DESC").
		Find(&results).Error
	return results, err
}

// IsFriend checks if two users are friends
func (s *Service) IsFriend(uid, targetUID int64) bool {
	var count int64
	s.db.Model(&model.Contact{}).
		Where("user_id = ? AND friend_id = ? AND blocked = false", uid, targetUID).
		Count(&count)
	return count > 0
}
