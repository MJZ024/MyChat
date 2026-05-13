package util

import (
	"fmt"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server    ServerConfig    `mapstructure:"server"`
	Database  DatabaseConfig  `mapstructure:"database"`
	Redis     RedisConfig     `mapstructure:"redis"`
	MinIO     MinIOConfig     `mapstructure:"minio"`
	NATS      NATSConfig      `mapstructure:"nats"`
	JWT       JWTConfig       `mapstructure:"jwt"`
	WebSocket WebSocketConfig `mapstructure:"websocket"`
	Log       LogConfig       `mapstructure:"log"`
}

type ServerConfig struct {
	Host string `mapstructure:"host"`
	Port int    `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
}

func (s ServerConfig) Addr() string {
	return fmt.Sprintf("%s:%d", s.Host, s.Port)
}

type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	DBName   string `mapstructure:"dbname"`
	SSLMode  string `mapstructure:"sslmode"`
}

func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode)
}

type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

func (r RedisConfig) Addr() string {
	return fmt.Sprintf("%s:%d", r.Host, r.Port)
}

type MinIOConfig struct {
	Endpoint  string `mapstructure:"endpoint"`
	AccessKey string `mapstructure:"access_key"`
	SecretKey string `mapstructure:"secret_key"`
	Bucket    string `mapstructure:"bucket"`
	UseSSL    bool   `mapstructure:"use_ssl"`
}

type NATSConfig struct {
	URL string `mapstructure:"url"`
}

type JWTConfig struct {
	PrivateKeyPath string `mapstructure:"private_key_path"`
	PublicKeyPath  string `mapstructure:"public_key_path"`
	AccessTTL      int    `mapstructure:"access_ttl"`
	RefreshTTL     int    `mapstructure:"refresh_ttl"`
}

func (j JWTConfig) AccessDuration() time.Duration {
	return time.Duration(j.AccessTTL) * time.Second
}

func (j JWTConfig) RefreshDuration() time.Duration {
	return time.Duration(j.RefreshTTL) * time.Second
}

type WebSocketConfig struct {
	MaxMessageSize int64 `mapstructure:"max_message_size"`
	PingPeriod     int   `mapstructure:"ping_period"`
	PongTimeout    int   `mapstructure:"pong_timeout"`
	WriteTimeout   int   `mapstructure:"write_timeout"`
}

func (w WebSocketConfig) PingPeriodDuration() time.Duration {
	return time.Duration(w.PingPeriod) * time.Second
}

func (w WebSocketConfig) PongTimeoutDuration() time.Duration {
	return time.Duration(w.PongTimeout) * time.Second
}

func (w WebSocketConfig) WriteTimeoutDuration() time.Duration {
	return time.Duration(w.WriteTimeout) * time.Second
}

type LogConfig struct {
	Level    string `mapstructure:"level"`
	Output   string `mapstructure:"output"`
	FilePath string `mapstructure:"file_path"`
}

func LoadConfig(path string) (*Config, error) {
	viper.SetConfigFile(path)
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &cfg, nil
}
