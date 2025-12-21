#!/bin/bash

# Verificar que kubectl esté instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl no está instalado"
    echo ""
    echo "📝 Opciones:"
    echo "   1. Instalar kubectl:"
    echo "      sudo snap install kubectl --classic"
    echo "   2. Usar Docker Compose en su lugar:"
    echo "      cd .. && docker-compose up --build"
    exit 1
fi

echo "🚀 Desplegando aplicación Black Friday en Kubernetes..."
echo ""

# Ir al directorio raíz del proyecto
cd "$(dirname "$0")/.." || exit

# Construir imágenes Docker
echo "📦 1. Construyendo imágenes Docker..."
echo "   - Construyendo Rust API..."
docker build -f api/Dockerfile -t rust-api:latest .

echo "   - Construyendo Go API REST..."
docker build -f go-api-rest/Dockerfile -t go-api-rest:latest .

echo "   - Construyendo gRPC Server..."
docker build -f grpc-server/Dockerfile -t grpc-server:latest .

echo ""
echo "✅ Imágenes construidas"
echo ""

# Aplicar manifiestos de Kubernetes
echo "☸️  2. Aplicando manifiestos de Kubernetes..."
kubectl apply -f k8s/00-namespace-config.yaml
echo "   ⏳ Esperando namespace..."
sleep 2

kubectl apply -f k8s/01-zookeeper.yaml
echo "   ⏳ Esperando Zookeeper..."
sleep 5

kubectl apply -f k8s/02-kafka.yaml
echo "   ⏳ Esperando Kafka..."
sleep 10

kubectl apply -f k8s/03-grpc-server-1.yaml
kubectl apply -f k8s/04-grpc-server-2.yaml
echo "   ⏳ Esperando gRPC Servers..."
sleep 5

kubectl apply -f k8s/05-go-api-rest.yaml
echo "   ⏳ Esperando Go API REST..."
sleep 5

kubectl apply -f k8s/06-api-rust.yaml
echo "   ⏳ Esperando Rust API..."
sleep 5

kubectl apply -f k8s/07-nginx-proxy.yaml
echo "   ⏳ Esperando Nginx Proxy..."
sleep 5

echo ""
echo "✅ Despliegue completado"
echo ""

# Mostrar estado
echo "📊 Estado de los pods:"
kubectl get pods -n blackfriday

echo ""
echo "📊 Estado de los servicios:"
kubectl get services -n blackfriday

echo ""
echo "🌐 Endpoints disponibles:"
echo "   - Nginx Proxy (acceso a Rust API): http://localhost:30300"
echo "   - Go API REST: http://localhost:30080"
echo ""
echo "💡 Para ver logs:"
echo "   kubectl logs -f <pod-name> -n blackfriday"
echo ""
echo "💡 Para escalar réplicas:"
echo "   kubectl scale deployment grpc-server-1 --replicas=2 -n blackfriday"
echo "   kubectl scale deployment grpc-server-2 --replicas=3 -n blackfriday"
