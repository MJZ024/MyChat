package storage

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/mychat/server/pkg/util"
	"go.uber.org/zap"
)

type Service struct {
	cfg    util.MinIOConfig
	logger *zap.Logger
	// Local filesystem path for uploads (fallback when MinIO not available)
	uploadDir string
	// Base URL for serving uploads
	baseURL string
}

func NewService(cfg util.MinIOConfig, logger *zap.Logger) *Service {
	uploadDir := "./uploads"
	os.MkdirAll(uploadDir, 0755)

	return &Service{
		cfg:       cfg,
		logger:    logger,
		uploadDir: uploadDir,
		baseURL:   "/uploads",
	}
}

// UploadResult contains the result of an upload
type UploadResult struct {
	URL      string `json:"url"`
	FileName string `json:"file_name"`
	FileSize int64  `json:"file_size"`
	FileType string `json:"file_type"`
}

// UploadFile saves a file to local filesystem
func (s *Service) UploadFile(file *multipart.FileHeader) (*UploadResult, error) {
	src, err := file.Open()
	if err != nil {
		return nil, fmt.Errorf("open file: %w", err)
	}
	defer src.Close()

	ext := strings.ToLower(filepath.Ext(file.Filename))
	if ext == "" {
		ext = ".bin"
	}

	fileType := s.detectFileType(ext)
	datePath := time.Now().Format("2006/01/02")
	dir := filepath.Join(s.uploadDir, datePath)
	os.MkdirAll(dir, 0755)

	// Generate unique filename
	filename := fmt.Sprintf("%d%s", time.Now().UnixNano(), ext)
	filePath := filepath.Join(dir, filename)

	dst, err := os.Create(filePath)
	if err != nil {
		return nil, fmt.Errorf("create file: %w", err)
	}
	defer dst.Close()

	written, err := io.Copy(dst, src)
	if err != nil {
		return nil, fmt.Errorf("write file: %w", err)
	}

	url := fmt.Sprintf("%s/%s/%s", s.baseURL, datePath, filename)

	return &UploadResult{
		URL:      url,
		FileName: file.Filename,
		FileSize: written,
		FileType: fileType,
	}, nil
}

func (s *Service) detectFileType(ext string) string {
	switch ext {
	case ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp":
		return "image"
	case ".mp3", ".wav", ".ogg", ".aac", ".m4a", ".amr":
		return "voice"
	case ".mp4", ".avi", ".mov", ".mkv", ".webm":
		return "video"
	default:
		return "file"
	}
}
