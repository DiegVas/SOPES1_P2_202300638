#!/bin/bash

echo "🔨 Generando código Go desde proto..."

# Crear directorio proto si no existe
mkdir -p proto

# Generar archivos .pb.go
protoc --proto_path=../proto \
    --go_out=proto --go_opt=paths=source_relative \
    --go-grpc_out=proto --go-grpc_opt=paths=source_relative \
    struct_saales.proto

if [ $? -eq 0 ]; then
    echo "✅ Código generado exitosamente en proto/"
else
    echo "❌ Error al generar código"
    exit 1
fi
