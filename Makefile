.PHONY: help build run-api run-grpc docker-build docker-up docker-down test clean proto-go proto-rust

help:
	@echo "📚 Comandos disponibles:"
	@echo "  make build         - Compilar API REST y servidor gRPC"
	@echo "  make run-api       - Ejecutar API REST (Rust)"
	@echo "  make run-grpc      - Ejecutar servidor gRPC (Go)"
	@echo "  make docker-build  - Construir imágenes Docker"
	@echo "  make docker-up     - Levantar servicios con Docker Compose"
	@echo "  make docker-down   - Detener servicios Docker"
	@echo "  make test          - Ejecutar tests de la API"
	@echo "  make clean         - Limpiar archivos compilados"
	@echo "  make proto-go      - Generar código Go desde proto"
	@echo "  make proto-rust    - Generar código Rust desde proto"

# Compilar proyectos
build:
	@echo "🔨 Compilando API REST (Rust)..."
	cd api && cargo build --release
	@echo "🔨 Compilando servidor gRPC (Go)..."
	cd grpc-server && go build -o server main.go
	@echo "✅ Compilación completa"

# Ejecutar API REST
run-api:
	@echo "🚀 Iniciando API REST..."
	cd api && cargo run --release

# Ejecutar servidor gRPC
run-grpc:
	@echo "🚀 Iniciando servidor gRPC..."
	cd grpc-server && go run main.go

# Docker
docker-build:
	@echo "🐳 Construyendo imágenes Docker..."
	docker-compose build

docker-up:
	@echo "🐳 Levantando servicios..."
	docker-compose up -d
	@echo "✅ Servicios levantados"
	@echo "   API REST: http://localhost:3000"
	@echo "   gRPC Server: localhost:50051"

docker-down:
	@echo "🛑 Deteniendo servicios..."
	docker-compose down

docker-logs:
	docker-compose logs -f

# Testing
test:
	@echo "🧪 Ejecutando tests..."
	./test_api.sh

# Limpiar
clean:
	@echo "🧹 Limpiando archivos compilados..."
	cd api && cargo clean
	cd grpc-server && go clean
	@echo "✅ Limpieza completa"

# Generar código desde proto
proto-go:
	@echo "🔨 Generando código Go desde proto..."
	cd grpc-server && ./generate.sh

proto-rust:
	@echo "🔨 Generando código Rust desde proto..."
	@echo "El código Rust se genera automáticamente durante cargo build"
	cd api && cargo build

# Desarrollo completo
dev: proto-go
	@echo "🚀 Iniciando modo desarrollo..."
	@echo "Iniciando servidor gRPC en segundo plano..."
	cd grpc-server && go run main.go &
	@sleep 2
	@echo "Iniciando API REST..."
	cd api && cargo run

# Instalar dependencias
deps:
	@echo "📦 Instalando dependencias..."
	cd api && cargo fetch
	cd grpc-server && go mod download
	@echo "✅ Dependencias instaladas"
