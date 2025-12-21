#!/bin/bash

echo "🐳 Construyendo imágenes Docker en Minikube..."
echo ""

# Verificar que minikube esté corriendo
if ! minikube status > /dev/null 2>&1; then
    echo "❌ Minikube no está corriendo"
    echo "   Inicia minikube con: minikube start --driver=docker"
    exit 1
fi

# Ir al directorio raíz del proyecto
cd "$(dirname "$0")/.." || exit

# Configurar el entorno de Docker de Minikube
echo "⚙️  Configurando entorno de Docker de Minikube..."
eval $(minikube docker-env)
echo ""

# Construir imágenes
echo "📦 Construyendo Rust API..."
docker build -f api/Dockerfile -t rust-api:latest .
if [ $? -ne 0 ]; then
    echo "❌ Error construyendo Rust API"
    exit 1
fi
echo "✅ Rust API construida"
echo ""

echo "📦 Construyendo Go API REST..."
docker build -f go-api-rest/Dockerfile -t go-api-rest:latest .
if [ $? -ne 0 ]; then
    echo "❌ Error construyendo Go API REST"
    exit 1
fi
echo "✅ Go API REST construida"
echo ""

echo "📦 Construyendo gRPC Server..."
docker build -f grpc-server/Dockerfile -t grpc-server:latest .
if [ $? -ne 0 ]; then
    echo "❌ Error construyendo gRPC Server"
    exit 1
fi
echo "✅ gRPC Server construido"
echo ""

echo "🎉 Todas las imágenes construidas exitosamente"
echo ""
echo "📋 Imágenes disponibles:"
eval $(minikube docker-env)
docker images | grep -E "(rust-api|go-api-rest|grpc-server)"
