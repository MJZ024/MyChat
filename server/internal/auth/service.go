package auth

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/mychat/server/internal/model"
	"github.com/mychat/server/pkg/middleware"
	"github.com/mychat/server/pkg/util"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type Service struct {
	db         *gorm.DB
	cfg        util.JWTConfig
	privateKey *rsa.PrivateKey
	publicKey  *rsa.PublicKey
}

func NewService(db *gorm.DB, cfg util.JWTConfig) (*Service, error) {
	s := &Service{db: db, cfg: cfg}
	if err := s.loadOrGenerateKeys(); err != nil {
		return nil, fmt.Errorf("failed to load keys: %w", err)
	}
	return s, nil
}

func (s *Service) loadOrGenerateKeys() error {
	privData, err := os.ReadFile(s.cfg.PrivateKeyPath)
	if err == nil {
		block, _ := pem.Decode(privData)
		if block != nil {
			s.privateKey, err = x509.ParsePKCS1PrivateKey(block.Bytes)
			if err == nil {
				pubData, _ := os.ReadFile(s.cfg.PublicKeyPath)
				pubBlock, _ := pem.Decode(pubData)
				if pubBlock != nil {
					pub, err := x509.ParsePKIXPublicKey(pubBlock.Bytes)
					if err == nil {
						s.publicKey = pub.(*rsa.PublicKey)
						return nil
					}
				}
			}
		}
	}

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return fmt.Errorf("generate RSA key: %w", err)
	}
	s.privateKey = key
	s.publicKey = &key.PublicKey

	os.MkdirAll("configs", 0755)

	privFile, err := os.Create(s.cfg.PrivateKeyPath)
	if err != nil {
		return fmt.Errorf("create private key file: %w", err)
	}
	defer privFile.Close()
	pem.Encode(privFile, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})

	pubBytes, _ := x509.MarshalPKIXPublicKey(s.publicKey)
	pubFile, err := os.Create(s.cfg.PublicKeyPath)
	if err != nil {
		return fmt.Errorf("create public key file: %w", err)
	}
	defer pubFile.Close()
	pem.Encode(pubFile, &pem.Block{Type: "PUBLIC KEY", Bytes: pubBytes})

	return nil
}

type RegisterRequest struct {
	Phone    string `json:"phone"`
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=6,max=50"`
	Nickname string `json:"nickname"`
}

type RegisterResponse struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
}

func (s *Service) Register(req RegisterRequest) (*RegisterResponse, error) {
	var count int64
	s.db.Model(&model.User{}).Where("username = ?", req.Username).Count(&count)
	if count > 0 {
		return nil, errors.New("用户名已存在")
	}

	if req.Phone != "" {
		s.db.Model(&model.User{}).Where("phone = ?", req.Phone).Count(&count)
		if count > 0 {
			return nil, errors.New("手机号已注册")
		}
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	user := model.User{
		Phone:        req.Phone,
		Username:     req.Username,
		PasswordHash: string(hash),
		Nickname:     req.Nickname,
	}
	if user.Nickname == "" {
		user.Nickname = user.Username
	}

	if err := s.db.Create(&user).Error; err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	return &RegisterResponse{UserID: user.ID, Username: user.Username}, nil
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	UserID       int64  `json:"user_id"`
	Username     string `json:"username"`
	Nickname     string `json:"nickname"`
	AvatarURL    string `json:"avatar_url"`
}

func (s *Service) Login(req LoginRequest) (*LoginResponse, error) {
	var user model.User
	if err := s.db.Where("username = ?", req.Username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("用户不存在")
		}
		return nil, fmt.Errorf("database error: %w", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("密码错误")
	}

	accessToken, err := s.generateToken(user.ID, user.Username, s.cfg.AccessDuration())
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.generateToken(user.ID, user.Username, s.cfg.RefreshDuration())
	if err != nil {
		return nil, err
	}

	return &LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(s.cfg.AccessTTL),
		UserID:       user.ID,
		Username:     user.Username,
		Nickname:     user.Nickname,
		AvatarURL:    user.AvatarURL,
	}, nil
}

func (s *Service) generateToken(userID int64, username string, duration time.Duration) (string, error) {
	claims := &middleware.Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(duration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	return token.SignedString(s.privateKey)
}

func (s *Service) PublicKey() []byte {
	pubBytes, _ := x509.MarshalPKIXPublicKey(s.publicKey)
	return pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: pubBytes})
}
