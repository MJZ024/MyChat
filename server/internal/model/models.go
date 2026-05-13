package model

import (
	"time"
)

// User 用户表
type User struct {
	ID           int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Phone        string    `gorm:"size:20" json:"phone"`
	Username     string    `gorm:"uniqueIndex;size:50;not null" json:"username"`
	PasswordHash string    `gorm:"size:255;not null" json:"-"`
	Nickname     string    `gorm:"size:100" json:"nickname"`
	AvatarURL    string    `gorm:"size:500" json:"avatar_url"`
	Bio          string    `gorm:"size:500" json:"bio"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

func (User) TableName() string { return "users" }

// Contact 好友关系
type Contact struct {
	ID        int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    int64     `gorm:"uniqueIndex:idx_contact_pair;not null" json:"user_id"`
	FriendID  int64     `gorm:"uniqueIndex:idx_contact_pair;not null" json:"friend_id"`
	Alias     string    `gorm:"size:100" json:"alias"`
	Blocked   bool      `gorm:"default:false" json:"blocked"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (Contact) TableName() string { return "contacts" }

// FriendRequest 好友申请
type FriendRequest struct {
	ID        int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	FromUID   int64     `gorm:"index;not null" json:"from_uid"`
	ToUID     int64     `gorm:"index;not null" json:"to_uid"`
	Message   string    `gorm:"size:200" json:"message"`
	Status    int       `gorm:"default:0" json:"status"` // 0=pending 1=accepted 2=rejected
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (FriendRequest) TableName() string { return "friend_requests" }

// Conversation 会话（单聊/群聊统一表示）
type Conversation struct {
	ID        int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Type      int       `gorm:"not null" json:"type"` // 1=single 2=group
	Name      string    `gorm:"size:200" json:"name"`
	AvatarURL string    `gorm:"size:500" json:"avatar_url"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (Conversation) TableName() string { return "conversations" }

// ConversationMember 会话成员
type ConversationMember struct {
	ID             int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	ConversationID int64     `gorm:"uniqueIndex:idx_conv_user;not null" json:"conversation_id"`
	UserID         int64     `gorm:"uniqueIndex:idx_conv_user;not null" json:"user_id"`
	Role           int       `gorm:"default:0" json:"role"` // 0=member 1=admin 2=owner
	LastReadSeq    int64     `gorm:"default:0" json:"last_read_seq"`
	JoinedAt       time.Time `gorm:"autoCreateTime" json:"joined_at"`
}

func (ConversationMember) TableName() string { return "conversation_members" }

// Message 消息
type Message struct {
	ID             int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	ConversationID int64     `gorm:"index;not null" json:"conversation_id"`
	SenderID       int64     `gorm:"index;not null" json:"sender_id"`
	Seq            int64     `gorm:"not null" json:"seq"`
	ContentType    int       `gorm:"not null" json:"content_type"` // 1=text 2=image 3=voice 4=file 5=video
	Content        string    `gorm:"type:text;not null" json:"content"`
	ReplyToID      *int64    `json:"reply_to_id"`
	Recalled       bool      `gorm:"default:false" json:"recalled"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (Message) TableName() string { return "messages" }

// UserConversation 用户会话（每人看到的会话列表）
type UserConversation struct {
	ID             int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID         int64      `gorm:"uniqueIndex:idx_user_conv;not null" json:"user_id"`
	ConversationID int64      `gorm:"uniqueIndex:idx_user_conv;not null" json:"conversation_id"`
	Pinned         bool       `gorm:"default:false" json:"pinned"`
	Muted          bool       `gorm:"default:false" json:"muted"`
	UnreadCount    int        `gorm:"default:0" json:"unread_count"`
	LastMsgPreview string     `gorm:"size:200" json:"last_msg_preview"`
	LastMsgTime    *time.Time `json:"last_msg_time"`
	UpdatedAt      time.Time  `gorm:"autoUpdateTime" json:"updated_at"`
}

func (UserConversation) TableName() string { return "user_conversations" }

// Device 设备表（多设备同步）
type Device struct {
	ID          int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID      int64     `gorm:"index;not null" json:"user_id"`
	DeviceToken string    `gorm:"size:500" json:"device_token"`
	Platform    string    `gorm:"size:20" json:"platform"` // android / windows
	LastActive  time.Time `json:"last_active"`
}

func (Device) TableName() string { return "devices" }

// Group 群组扩展信息
type Group struct {
	ID             int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	ConversationID int64     `gorm:"uniqueIndex;not null" json:"conversation_id"`
	Announcement   string    `gorm:"size:1000" json:"announcement"`
	MaxMembers     int       `gorm:"default:500" json:"max_members"`
	CreatedBy      int64     `gorm:"not null" json:"created_by"`
}

func (Group) TableName() string { return "groups" }
