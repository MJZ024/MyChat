package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/mychat/server/internal/auth"
	"github.com/mychat/server/internal/connect"
	"github.com/mychat/server/internal/contact"
	"github.com/mychat/server/internal/group"
	"github.com/mychat/server/internal/message"
	"github.com/mychat/server/internal/model"
	"github.com/mychat/server/internal/storage"
	"github.com/mychat/server/pkg/middleware"
	"github.com/mychat/server/pkg/protocol"
	"github.com/mychat/server/pkg/util"
	"go.uber.org/zap"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	cfg, err := util.LoadConfig("configs/config.yaml")
	if err != nil {
		fmt.Printf("failed to load config: %v\n", err)
		os.Exit(1)
	}

	logger := util.NewLogger(cfg.Log)
	defer logger.Sync()

	// Database
	db, err := gorm.Open(postgres.Open(cfg.Database.DSN()), &gorm.Config{})
	if err != nil {
		logger.Fatal("failed to connect database", zap.Error(err))
	}

	// Auto-migrate
	if err := db.AutoMigrate(
		&model.User{},
		&model.Contact{},
		&model.FriendRequest{},
		&model.Conversation{},
		&model.ConversationMember{},
		&model.Message{},
		&model.UserConversation{},
		&model.Device{},
		&model.Group{},
	); err != nil {
		logger.Fatal("failed to migrate database", zap.Error(err))
	}
	logger.Info("database migrated")

	// Auth service
	authSvc, err := auth.NewService(db, cfg.JWT)
	if err != nil {
		logger.Fatal("failed to init auth service", zap.Error(err))
	}

	// WebSocket hub
	wsHandler := connect.NewWSHandler(logger)
	hub := connect.NewHub(logger, cfg.WebSocket, wsHandler)
	hub.SetJSONHandler(wsHandler) // wsHandler handles both protobuf and JSON

	// Services
	msgSvc := message.NewService(db, hub, logger)
	contactSvc := contact.NewService(db, logger)
	groupSvc := group.NewService(db, logger)
	storageSvc := storage.NewService(cfg.MinIO, logger)

	// ---- Wire WS handler callbacks (protobuf path) ----

	wsHandler.OnSendMessage = func(c *connect.Client, req *protocol.SendMessageRequest) {
		msg, err := msgSvc.SendMessage(c.UID, req)
		if err != nil {
			logger.Error("send message failed", zap.Error(err))
			return
		}
		connect.SendToClient(c, protocol.MessageType_RECV_MESSAGE, msg)
	}

	wsHandler.OnSyncRequest = func(c *connect.Client, req *protocol.SyncRequest) {
		limit := int(req.Limit)
		if limit <= 0 || limit > 100 {
			limit = 50
		}
		msgs, err := msgSvc.GetSyncMessages(c.UID, req.LastSeq, limit)
		if err != nil {
			logger.Error("sync failed", zap.Error(err))
			return
		}
		connect.SendToClient(c, protocol.MessageType_SYNC_RESPONSE, &protocol.SyncResponse{
			Messages: msgs,
			HasMore:  len(msgs) >= limit,
		})
	}

	wsHandler.OnRecall = func(c *connect.Client, req *protocol.MessageRecallRequest) {
		var msgID int64
		if _, err := fmt.Sscanf(req.MsgId, "%d", &msgID); err != nil {
			return
		}
		if err := msgSvc.RecallMessage(msgID, c.UID); err != nil {
			logger.Error("recall failed", zap.Error(err))
			return
		}
		connect.SendToClient(c, protocol.MessageType_ACK, &protocol.AckRequest{})
	}

	// ---- Wire JSON WS callbacks (Flutter client path) ----

	wsHandler.OnJSONSendMessage = func(c *connect.Client, msg *connect.JSONIncomingMessage) {
		data := msg.Data
		toID, _ := data["to_id"].(string)
		content, _ := data["content"].(string)
		replyTo, _ := data["reply_to"].(string)
		chatType := protocol.ChatType_SINGLE
		if ct, ok := data["chat_type"].(float64); ok && int32(ct) == 1 {
			chatType = protocol.ChatType_GROUP
		}
		contentType := protocol.ContentType_TEXT
		if ct, ok := data["content_type"].(float64); ok {
			contentType = protocol.ContentType(int32(ct))
		}

		req := &protocol.SendMessageRequest{
			ToId:        toID,
			ChatType:    chatType,
			ContentType: contentType,
			Content:     content,
			ReplyTo:     replyTo,
		}

		chatMsg, err := msgSvc.SendMessage(c.UID, req)
		if err != nil {
			logger.Error("json send message failed", zap.Error(err))
			connect.SendJSONToClient(c, map[string]interface{}{
				"type":    "error",
				"message": err.Error(),
			})
			return
		}

		recvJSON := message.MakeRecvJSON(chatMsg)
		var senderUser model.User
		db.First(&senderUser, c.UID)
		recvJSON["data"].(map[string]interface{})["from_nickname"] = senderUser.Nickname

		// Send back to sender
		connect.SendJSONToClient(c, recvJSON)

		// Also send to recipient (for single chat) or group members
		if chatMsg.ChatType == protocol.ChatType_SINGLE {
			var toUID int64
			fmt.Sscanf(chatMsg.ToId, "%d", &toUID)
			logger.Info("json send_message",
				zap.Int64("sender", c.UID),
				zap.Int64("to_uid", toUID),
				zap.Bool("to_online", hub.IsOnline(toUID)),
			)
			if toUID > 0 && toUID != c.UID {
				hub.SendJSONToUser(toUID, recvJSON)
			}
		} else if chatMsg.ChatType == protocol.ChatType_GROUP {
			var convID int64
			fmt.Sscanf(chatMsg.ToId, "%d", &convID)
			if convID > 0 {
				var memberIDs []int64
				db.Model(&model.ConversationMember{}).
					Where("conversation_id = ? AND user_id != ?", convID, c.UID).
					Pluck("user_id", &memberIDs)
				logger.Info("json group send_message",
					zap.Int64("sender", c.UID),
					zap.Int64("conv_id", convID),
					zap.Int("member_count", len(memberIDs)),
				)
				hub.SendJSONToUsers(memberIDs, recvJSON)
			}
		}
	}

	wsHandler.OnJSONTyping = func(c *connect.Client, msg *connect.JSONIncomingMessage) {
		data := msg.Data
		toID, _ := data["to_id"].(string)
		chatType, _ := data["chat_type"].(float64)

		// Convert to_id to uid for single chat
		var targetUIDs []int64
		if int32(chatType) == 1 {
			// Group: send to all members except sender
			var convID int64
			fmt.Sscanf(toID, "%d", &convID)
			var memberIDs []int64
			db.Model(&model.ConversationMember{}).
				Where("conversation_id = ? AND user_id != ?", convID, c.UID).
				Pluck("user_id", &memberIDs)
			targetUIDs = memberIDs
		} else {
			var uid int64
			fmt.Sscanf(toID, "%d", &uid)
			targetUIDs = []int64{uid}
		}

		typingJSON := map[string]interface{}{
			"type": "typing",
			"data": map[string]interface{}{
				"from_uid":  c.UID,
				"to_id":     toID,
				"chat_type": chatType,
			},
		}
		hub.SendJSONToUsers(targetUIDs, typingJSON)
	}

	wsHandler.OnJSONRecall = func(c *connect.Client, msg *connect.JSONIncomingMessage) {
		data := msg.Data
		msgIDStr, _ := data["msg_id"].(string)
		var msgID int64
		fmt.Sscanf(msgIDStr, "%d", &msgID)
		if err := msgSvc.RecallMessage(msgID, c.UID); err != nil {
			logger.Error("json recall failed", zap.Error(err))
		}
	}

	wsHandler.OnJSONRead = func(c *connect.Client, msg *connect.JSONIncomingMessage) {
		data := msg.Data
		convIDStr, _ := data["conversation_id"].(string)
		var convID int64
		fmt.Sscanf(convIDStr, "%d", &convID)
		if convID > 0 {
			db.Model(&model.UserConversation{}).
				Where("user_id = ? AND conversation_id = ?", c.UID, convID).
				Update("unread_count", 0)
		}
		// Echo back so the client can refresh the conversation list
		connect.SendJSONToClient(c, map[string]interface{}{
			"type": "message_read",
			"data": map[string]interface{}{"conversation_id": convIDStr},
		})
	}

	// Hub status change: broadcast to friends
	hub.SetOnStatusChange(func(uid int64, online bool) {
		var friendIDs []int64
		db.Model(&model.Contact{}).
			Where("friend_id = ? AND blocked = false", uid).
			Pluck("user_id", &friendIDs)
		statusJSON := map[string]interface{}{
			"type": "online_status",
			"data": map[string]interface{}{
				"uid":    uid,
				"online": online,
			},
		}
		hub.SendJSONToUsers(friendIDs, statusJSON)
	})

	// Start hub
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go hub.Run(ctx)

	// Setup Gin
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.Default()
	r.Use(middleware.CORSMiddleware())

	// Static file serving for uploads
	r.Static("/uploads", "./uploads")

	// Public routes
	r.POST("/api/auth/register", handleRegister(authSvc))
	r.POST("/api/auth/login", handleLogin(authSvc))

	// Protected routes
	api := r.Group("/api")
	api.Use(middleware.JWTAuth(authSvc.PublicKey()))
	{
		// User
		api.GET("/user/profile", handleGetProfile(db))
		api.PUT("/user/profile", handleUpdateProfile(db))
		api.GET("/user/:id", handleGetUserPublic(db))
		api.GET("/user/search", handleSearchUsers(contactSvc))

		// Online status
		api.GET("/users/status", handleBatchOnlineStatus(hub, contactSvc))

		// Contacts
		api.GET("/contacts", handleGetContacts(contactSvc))
		api.POST("/contacts/request", handleSendFriendRequest(contactSvc, hub, db))
		api.GET("/contacts/requests", handleGetPendingRequests(contactSvc))
		api.POST("/contacts/accept/:id", handleAcceptFriendRequest(contactSvc, hub, db))
		api.POST("/contacts/reject/:id", handleRejectFriendRequest(contactSvc))
		api.DELETE("/contacts/:uid", handleDeleteFriend(db, contactSvc, hub))
		api.POST("/contacts/block/:uid", handleBlockUser(contactSvc))
		api.POST("/contacts/unblock/:uid", handleUnblockUser(contactSvc))

		// Conversations & Messages
		api.GET("/conversations", handleGetConversations(db))
		api.POST("/conversations/single/:uid", handleGetOrCreateSingleConversation(msgSvc))
		api.GET("/conversations/:id/state", handleGetConversationState(db))
			api.PUT("/conversations/:id/toggle-mute", handleToggleMute(db))
		api.PUT("/conversations/:id/toggle-pin", handleTogglePin(db))
		api.GET("/messages/:conversation_id", handleGetMessages(db, msgSvc))
		api.DELETE("/messages/:conversation_id", handleClearMessages(db))
		api.POST("/messages/forward", handleForwardMessages(msgSvc))
		api.GET("/messages/search", handleSearchMessages(msgSvc))

		// Groups
		api.POST("/groups", handleCreateGroup(groupSvc, hub))
		api.GET("/groups/:id/members", handleGetGroupMembers(groupSvc))
		api.POST("/groups/:id/invite", handleInviteMember(groupSvc))
		api.POST("/groups/:id/leave", handleLeaveGroup(groupSvc))
		api.POST("/groups/:id/kick", handleKickMember(groupSvc))
		api.PUT("/groups/:id", handleUpdateGroupInfo(groupSvc))
		api.GET("/groups/:id", handleGetGroupInfo(groupSvc))

		// Upload
		api.POST("/upload", handleUpload(storageSvc))
	}

	// WebSocket
	r.GET("/ws", func(c *gin.Context) {
		token := c.Query("token")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
			return
		}
		claims, err := validateToken(token, authSvc.PublicKey())
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}
		hub.ServeWS(c.Writer, c.Request, claims.UserID)
	})

	// Start server
	srv := &http.Server{
		Addr:    cfg.Server.Addr(),
		Handler: r,
	}

	go func() {
		logger.Info("server starting", zap.String("addr", cfg.Server.Addr()))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("listen failed", zap.Error(err))
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*1e9)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Fatal("forced shutdown", zap.Error(err))
	}
	logger.Info("server exited")
}

func validateToken(tokenStr string, publicKeyPEM []byte) (*middleware.Claims, error) {
	key, err := jwt.ParseRSAPublicKeyFromPEM(publicKeyPEM)
	if err != nil {
		return nil, err
	}

	token, err := jwt.ParseWithClaims(tokenStr, &middleware.Claims{}, func(t *jwt.Token) (interface{}, error) {
		return key, nil
	})
	if err != nil || !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	claims, ok := token.Claims.(*middleware.Claims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}

// === Auth handlers ===

func handleRegister(authSvc *auth.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req auth.RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		resp, err := authSvc.Register(req)
		if err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, resp)
	}
}

func handleLogin(authSvc *auth.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req auth.LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		resp, err := authSvc.Login(req)
		if err != nil {
			util.Unauthorized(c, err.Error())
			return
		}
		util.Success(c, resp)
	}
}

// === User handlers ===

func handleGetProfile(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var user model.User
		if err := db.First(&user, uid).Error; err != nil {
			util.NotFound(c, "user not found")
			return
		}
		util.Success(c, user)
	}
}

func handleGetUserPublic(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var uid int64
		fmt.Sscanf(c.Param("id"), "%d", &uid)
		var user model.User
		if err := db.First(&user, uid).Error; err != nil {
			util.NotFound(c, "用户不存在")
			return
		}
		util.Success(c, map[string]interface{}{
			"id":         user.ID,
			"username":   user.Username,
			"nickname":   user.Nickname,
			"avatar_url": user.AvatarURL,
			"bio":        user.Bio,
		})
	}
}

func handleUpdateProfile(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var updates map[string]interface{}
		if err := c.ShouldBindJSON(&updates); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		allowed := map[string]bool{"nickname": true, "bio": true, "avatar_url": true}
		filtered := make(map[string]interface{})
		for k, v := range updates {
			if allowed[k] {
				filtered[k] = v
			}
		}
		if len(filtered) == 0 {
			util.BadRequest(c, "no valid fields to update")
			return
		}
		db.Model(&model.User{}).Where("id = ?", uid).Updates(filtered)
		util.Success(c, nil)
	}
}

func handleSearchUsers(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		query := c.Query("q")
		if query == "" {
			util.BadRequest(c, "missing search query")
			return
		}
		users, err := contactSvc.SearchUsers(query, uid)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, users)
	}
}

// === Online status handler ===

func handleBatchOnlineStatus(hub *connect.Hub, contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uidsStr := c.Query("uids")
		if uidsStr == "" {
			util.BadRequest(c, "missing uids")
			return
		}
		parts := strings.Split(uidsStr, ",")
		result := make(map[int64]bool)
		for _, p := range parts {
			var uid int64
			fmt.Sscanf(strings.TrimSpace(p), "%d", &uid)
			if uid > 0 {
				result[uid] = hub.IsOnline(uid)
			}
		}
		util.Success(c, result)
	}
}

// === Contact handlers ===

func handleGetContacts(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		friends, err := contactSvc.GetFriendList(uid)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, friends)
	}
}

func handleSendFriendRequest(contactSvc *contact.Service, hub *connect.Hub, db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var req struct {
			ToUID   int64  `json:"to_uid"`
			Message string `json:"message"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		result, err := contactSvc.SendFriendRequest(uid, req.ToUID, req.Message)
		if err != nil {
			util.BadRequest(c, err.Error())
			return
		}

		// Notify target user via WS
		var fromUser model.User
		db.First(&fromUser, uid)
		hub.SendJSONToUser(req.ToUID, map[string]interface{}{
			"type": "friend_request",
			"data": map[string]interface{}{
				"from_uid":      uid,
				"from_nickname": fromUser.Nickname,
				"from_avatar":   fromUser.AvatarURL,
				"message":       req.Message,
				"request_id":    result.ID,
			},
		})

		util.Success(c, result)
	}
}

func handleGetPendingRequests(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		requests, err := contactSvc.GetPendingRequests(uid)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, requests)
	}
}

func handleAcceptFriendRequest(contactSvc *contact.Service, hub *connect.Hub, db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		requestID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid request id")
			return
		}

		// Get the request to find the requester
		var fr model.FriendRequest
		if err := db.First(&fr, requestID).Error; err != nil {
			util.NotFound(c, "request not found")
			return
		}

		if err := contactSvc.AcceptFriendRequest(requestID, uid); err != nil {
			util.BadRequest(c, err.Error())
			return
		}

		// Re-create user_conversations if the conversation still exists
		var convID int64
		db.Raw(`
			SELECT cm1.conversation_id
			FROM conversation_members cm1
			JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
			JOIN conversations c ON c.id = cm1.conversation_id
			WHERE cm1.user_id = ? AND cm2.user_id = ? AND c.type = 1
			LIMIT 1
		`, uid, fr.FromUID).Scan(&convID)
		if convID > 0 {
			db.Create(&[]model.UserConversation{
				{UserID: uid, ConversationID: convID},
				{UserID: fr.FromUID, ConversationID: convID},
			})
		}
		// Notify the requester that their friend request was accepted
		var accepter model.User
		db.First(&accepter, uid)
		hub.SendJSONToUser(fr.FromUID, map[string]interface{}{
			"type": "friend_accept",
			"data": map[string]interface{}{
				"from_uid":      uid,
				"from_nickname": accepter.Nickname,
				"from_avatar":   accepter.AvatarURL,
			},
		})

		util.Success(c, nil)
	}
}

func handleRejectFriendRequest(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		requestID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid request id")
			return
		}
		if err := contactSvc.RejectFriendRequest(requestID, uid); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleDeleteFriend(db *gorm.DB, contactSvc *contact.Service, hub *connect.Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		friendUID, err := strconv.ParseInt(c.Param("uid"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid uid")
			return
		}
		if err := contactSvc.DeleteFriend(uid, friendUID); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		// Find and remove the single-chat conversation for both
		var convID int64
		db.Raw(`
			SELECT cm1.conversation_id
			FROM conversation_members cm1
			JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
			JOIN conversations c ON c.id = cm1.conversation_id
			WHERE cm1.user_id = ? AND cm2.user_id = ? AND c.type = 1
			LIMIT 1
		`, uid, friendUID).Scan(&convID)
		if convID > 0 {
			db.Where("user_id IN ? AND conversation_id = ?", []int64{uid, friendUID}, convID).Delete(&model.UserConversation{})
		}
		// Notify both users via WS
		hub.SendJSONToUser(uid, map[string]interface{}{
			"type": "friend_deleted",
			"data": map[string]interface{}{"uid": friendUID},
		})
		hub.SendJSONToUser(friendUID, map[string]interface{}{
			"type": "friend_deleted",
			"data": map[string]interface{}{"uid": uid},
		})
		util.Success(c, nil)
	}
}

func handleBlockUser(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		targetUID, err := strconv.ParseInt(c.Param("uid"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid uid")
			return
		}
		if err := contactSvc.BlockUser(uid, targetUID); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleUnblockUser(contactSvc *contact.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		targetUID, err := strconv.ParseInt(c.Param("uid"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid uid")
			return
		}
		if err := contactSvc.UnblockUser(uid, targetUID); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

// === Conversation & Message handlers ===

func handleGetConversations(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var rows []struct {
			model.UserConversation
			Name      string `json:"name"`
			AvatarURL string `json:"avatar_url"`
			Type      int    `json:"type"`
			PeerUID   int64  `json:"peer_uid"`
		}
		db.Table("user_conversations uc").
			Select("uc.*, c.name, c.avatar_url, c.type, COALESCE((SELECT cm.user_id FROM conversation_members cm WHERE cm.conversation_id = uc.conversation_id AND cm.user_id != uc.user_id LIMIT 1), 0) as peer_uid").
			Joins("JOIN conversations c ON c.id = uc.conversation_id").
			Where("uc.user_id = ?", uid).
			Order("uc.pinned DESC, uc.last_msg_time DESC").
			Find(&rows)

		// Fill in names for unnamed single chats
		for i := range rows {
			if rows[i].Type == 1 && rows[i].Name == "" && rows[i].PeerUID > 0 {
				var peer model.User
				if err := db.First(&peer, rows[i].PeerUID).Error; err == nil {
					rows[i].Name = peer.Nickname
				}
			}
		}
		util.Success(c, rows)
	}
}

func handleGetMessages(db *gorm.DB, msgSvc *message.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var convID int64
		fmt.Sscanf(c.Param("conversation_id"), "%d", &convID)
		var lastSeq int64
		fmt.Sscanf(c.DefaultQuery("last_seq", "0"), "%d", &lastSeq)
		limit := 50
		msgs, err := msgSvc.GetHistory(convID, lastSeq, limit)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		// Enrich with sender nicknames
		senderUIDs := make(map[int64]string)
		for _, m := range msgs {
			senderUIDs[m.FromUid] = ""
		}
		uidList := make([]int64, 0, len(senderUIDs))
		for uid := range senderUIDs {
			uidList = append(uidList, uid)
		}
		var users []model.User
		db.Where("id IN ?", uidList).Find(&users)
		for _, u := range users {
			senderUIDs[u.ID] = u.Nickname
		}
		result := make([]map[string]interface{}, len(msgs))
		for i, m := range msgs {
			result[i] = map[string]interface{}{
				"msg_id":       m.MsgId,
				"from_uid":     m.FromUid,
				"to_id":        m.ToId,
				"chat_type":    int32(m.ChatType),
				"content_type": int32(m.ContentType),
				"content":      m.Content,
				"reply_to":     m.ReplyTo,
				"created_at":   m.CreatedAt,
				"from_nickname": senderUIDs[m.FromUid],
			}
		}
		util.Success(c, result)
	}
}

func handleGetConversationState(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var convID int64
		fmt.Sscanf(c.Param("id"), "%d", &convID)
		var uc model.UserConversation
		if err := db.Where("user_id = ? AND conversation_id = ?", uid, convID).First(&uc).Error; err != nil {
			util.NotFound(c, "会话不存在")
			return
		}
		util.Success(c, map[string]bool{"muted": uc.Muted, "pinned": uc.Pinned})
	}
}

func handleToggleMute(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var convID int64
		fmt.Sscanf(c.Param("id"), "%d", &convID)
		result := db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", uid, convID).
			Update("muted", gorm.Expr("NOT muted"))
		if result.RowsAffected == 0 {
			util.NotFound(c, "会话不存在")
			return
		}
		var muted bool
		db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", uid, convID).
			Select("muted").Scan(&muted)
		util.Success(c, map[string]bool{"muted": muted})
	}
}

func handleTogglePin(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var convID int64
		fmt.Sscanf(c.Param("id"), "%d", &convID)
		result := db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", uid, convID).
			Update("pinned", gorm.Expr("NOT pinned"))
		if result.RowsAffected == 0 {
			util.NotFound(c, "会话不存在")
			return
		}
		var pinned bool
		db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", uid, convID).
			Select("pinned").Scan(&pinned)
		util.Success(c, map[string]bool{"pinned": pinned})
	}
}

func handleClearMessages(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var convID int64
		fmt.Sscanf(c.Param("conversation_id"), "%d", &convID)
		db.Where("conversation_id = ?", convID).Delete(&model.Message{})
		db.Model(&model.UserConversation{}).
			Where("user_id = ? AND conversation_id = ?", uid, convID).
			Updates(map[string]interface{}{
				"unread_count":     0,
				"last_msg_preview": "",
			})
		util.Success(c, nil)
	}
}

func handleGetOrCreateSingleConversation(msgSvc *message.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		targetUID, err := strconv.ParseInt(c.Param("uid"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid uid")
			return
		}
		convID, err := msgSvc.GetOrCreateSingleConversation(uid, targetUID)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, map[string]interface{}{"conversation_id": convID})
	}
}

func handleForwardMessages(msgSvc *message.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var req struct {
			MessageIDs      []int64 `json:"message_ids"`
			TargetConvID    int64   `json:"target_conv_id"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		if len(req.MessageIDs) == 0 || req.TargetConvID == 0 {
			util.BadRequest(c, "message_ids and target_conv_id required")
			return
		}
		msgs, err := msgSvc.ForwardMessages(uid, req.MessageIDs, req.TargetConvID)
		if err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, msgs)
	}
}

func handleSearchMessages(msgSvc *message.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		query := c.Query("q")
		if query == "" {
			util.BadRequest(c, "missing search query")
			return
		}
		var convID int64
		fmt.Sscanf(c.DefaultQuery("conversation_id", "0"), "%d", &convID)
		results, err := msgSvc.SearchMessages(uid, query, convID, 50)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, results)
	}
}

// === Group handlers ===

func handleCreateGroup(groupSvc *group.Service, hub *connect.Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		var req struct {
			Name       string  `json:"name"`
			MemberUIDs []int64 `json:"member_uids"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		if req.Name == "" {
			util.BadRequest(c, "group name required")
			return
		}
		conv, err := groupSvc.CreateGroup(uid, req.Name, req.MemberUIDs)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}

		// Notify all members via WS to refresh conversation list
		allMembers := append([]int64{uid}, req.MemberUIDs...)
		hub.SendJSONToUsers(allMembers, map[string]interface{}{
			"type": "group_created",
			"data": map[string]interface{}{
				"conversation_id": conv.ID,
				"name":            conv.Name,
				"type":            conv.Type,
			},
		})

		util.Success(c, gin.H{
			"conversation_id": conv.ID,
			"name":            conv.Name,
			"type":            conv.Type,
		})
	}
}

func handleGetGroupMembers(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		members, err := groupSvc.GetGroupMembers(convID)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, members)
	}
}

func handleInviteMember(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		var req struct {
			UID int64 `json:"uid"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		if err := groupSvc.InviteMember(convID, uid, req.UID); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleLeaveGroup(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		if err := groupSvc.LeaveGroup(convID, uid); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleKickMember(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		var req struct {
			UID int64 `json:"uid"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		if err := groupSvc.KickMember(convID, uid, req.UID); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleUpdateGroupInfo(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := c.GetInt64("uid")
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		var updates map[string]interface{}
		if err := c.ShouldBindJSON(&updates); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		if err := groupSvc.UpdateGroupInfo(convID, uid, updates); err != nil {
			util.BadRequest(c, err.Error())
			return
		}
		util.Success(c, nil)
	}
}

func handleGetGroupInfo(groupSvc *group.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		convID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			util.BadRequest(c, "invalid group id")
			return
		}
		conv, group, err := groupSvc.GetGroupInfo(convID)
		if err != nil {
			util.NotFound(c, "group not found")
			return
		}
		util.Success(c, gin.H{
			"conversation": conv,
			"group":        group,
		})
	}
}

// === Upload handler ===

func handleUpload(storageSvc *storage.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		file, err := c.FormFile("file")
		if err != nil {
			util.BadRequest(c, "no file provided")
			return
		}
		result, err := storageSvc.UploadFile(file)
		if err != nil {
			util.InternalError(c, err.Error())
			return
		}
		util.Success(c, result)
	}
}
