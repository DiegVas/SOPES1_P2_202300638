# Multi-stage build para optimizar el tamaño de la imagen

# Stage 1: Builder
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copiar archivos de dependencias
COPY go.mod go.sum* ./

# Descargar dependencias
RUN go mod download

# Copiar código fuente
COPY . .

# Construir el binario
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o kafka-consumer .

# Stage 2: Runtime
FROM alpine:latest

# Instalar certificados CA para conexiones HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copiar el binario desde el builder
COPY --from=builder /app/kafka-consumer .

# Crear usuario no-root para seguridad
RUN adduser -D -u 1000 consumeruser && \
    chown consumeruser:consumeruser /root/kafka-consumer

USER consumeruser

# El consumidor se ejecuta continuamente
CMD ["./kafka-consumer"]
