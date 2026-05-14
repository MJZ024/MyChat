package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/mychat/server/pkg/util"
)

type Claims struct {
	UserID   int64  `json:"uid"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

func JWTAuth(publicKey []byte) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			util.Unauthorized(c, "missing authorization header")
			c.Abort()
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenStr == authHeader {
			util.Unauthorized(c, "invalid authorization format")
			c.Abort()
			return
		}

		key, err := jwt.ParseRSAPublicKeyFromPEM(publicKey)
		if err != nil {
			util.InternalError(c, "invalid public key")
			c.Abort()
			return
		}

		token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
			return key, nil
		})
		if err != nil || !token.Valid {
			util.Unauthorized(c, "invalid or expired token")
			c.Abort()
			return
		}

		claims, ok := token.Claims.(*Claims)
		if !ok {
			util.Unauthorized(c, "invalid token claims")
			c.Abort()
			return
		}

		c.Set("uid", claims.UserID)
		c.Set("username", claims.Username)
		c.Next()
	}
}

func CORSMiddleware(allowedOrigins []string) gin.HandlerFunc {
	hasWildcard := false
	for _, o := range allowedOrigins {
		if o == "*" {
			hasWildcard = true
			break
		}
	}

	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		if origin != "" {
			if hasWildcard || util.IsOriginAllowed(allowedOrigins, origin) {
				if hasWildcard {
					c.Header("Access-Control-Allow-Origin", "*")
				} else {
					c.Header("Access-Control-Allow-Origin", origin)
				}
			}
		}

		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
