# Etapa de construcción
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Instalar protoc y plugins
RUN apk add --no-cache protobuf-dev git

# Copiar módulos de Go
COPY grpc-server/go.mod grpc-server/go.sum* ./
RUN go mod download

# Copiar código fuente
COPY grpc-server/*.go ./

# Crear directorio proto si no existe
RUN mkdir -p proto

# Copiar proto desde la carpeta raíz
COPY proto/struct_saales.proto proto/

# Instalar herramientas de protobuf
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.31.0
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0

# Generar código desde proto
RUN protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/struct_saales.proto

# Compilar la aplicación
RUN go build -o server main.go

# Etapa final
FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/server .

EXPOSE 50051

CMD ["./server"]
