.PHONY: build run test clean proto docker-up docker-down

build:
	go build -o bin/mychat-server ./cmd/server

run:
	go run ./cmd/server

test:
	go test ./...

clean:
	rm -rf bin/

proto:
	protoc --go_out=pkg/protocol --go_opt=paths=source_relative \
		--go-grpc_out=pkg/protocol --go-grpc_opt=paths=source_relative \
		../shared/protos/protocol.proto

docker-up:
	cd deploy && docker-compose up -d

docker-down:
	cd deploy && docker-compose down

docker-build:
	cd deploy && docker-compose up -d --build

migrate-up:
	migrate -path migrations -database "postgres://mychat:mychat123@localhost:5432/mychat?sslmode=disable" up

migrate-down:
	migrate -path migrations -database "postgres://mychat:mychat123@localhost:5432/mychat?sslmode=disable" down 1

generate-keys:
	openssl genrsa -out configs/private.pem 2048
	openssl rsa -in configs/private.pem -pubout -out configs/public.pem
