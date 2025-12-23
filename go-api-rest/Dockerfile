# Etapa de construcción
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Instalar dependencias necesarias
RUN apk add --no-cache protobuf-dev git

# Copiar go.mod y descargar dependencias
COPY go-api-rest/go.mod go-api-rest/go.sum* ./
RUN go mod download

# Instalar herramientas de protobuf
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.31.0
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0

# Copiar código fuente
COPY go-api-rest/*.go ./

# Crear directorio proto
RUN mkdir -p proto

# Generar código desde proto
COPY proto/struct_saales.proto proto/
RUN protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/struct_saales.proto

# Compilar la aplicación
RUN go build -o app main.go

# Etapa final
FROM alpine:latest

WORKDIR /root/

# Instalar ca-certificates para HTTPS
RUN apk --no-cache add ca-certificates

COPY --from=builder /app/app .

EXPOSE 8080

CMD ["./app"]
