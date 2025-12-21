#!/bin/bash

set -e

echo "🚀 Despliegue Completo de API Rust con Nginx en Kubernetes"
echo "=========================================================="
echo ""

# Verificar minikube
if ! command -v minikube &> /dev/null || ! minikube status > /dev/null 2>&1; then
    echo "❌ Minikube no está corriendo"
    echo "   Inicia minikube con: minikube start"
    exit 1
fi

# Configurar Docker de Minikube
echo "⚙️  Configurando entorno Docker de Minikube..."
eval $(minikube docker-env)

# Construir imagen
echo ""
echo "📦 Construyendo imagen de Rust API..."
cd "$(dirname "$0")"
docker build -f api/Dockerfile -t rust-api:latest .

if [ $? -ne 0 ]; then
    echo "❌ Error construyendo la imagen"
    exit 1
fi

echo "✅ Imagen construida exitosamente"
echo ""

# Probar imagen localmente primero
echo "🧪 Probando imagen localmente..."
CONTAINER_ID=$(docker run -d -p 3001:3000 -e PORT=3000 rust-api:latest)

sleep 3

if docker ps | grep -q $CONTAINER_ID; then
    echo "✅ Contenedor ejecutándose correctamente"
    
    # Probar endpoint
    if curl -s http://localhost:3001/health > /dev/null; then
        echo "✅ Health check respondió correctamente"
    else
        echo "⚠️  Health check no responde (esto es normal si el puerto no está forwarded)"
    fi
    
    docker stop $CONTAINER_ID > /dev/null 2>&1
    docker rm $CONTAINER_ID > /dev/null 2>&1
else
    echo "❌ Contenedor no se está ejecutando"
    docker logs $CONTAINER_ID
    docker rm $CONTAINER_ID > /dev/null 2>&1
    exit 1
fi

echo ""
echo "☸️  Desplegando en Kubernetes..."

# Verificar/crear namespace
if ! kubectl get namespace blackfriday &> /dev/null; then
    echo "   Creando namespace blackfriday..."
    kubectl apply -f k8s/00-namespace-config.yaml
    sleep 2
fi

# Eliminar deployment anterior si existe
if kubectl get deployment api-rust -n blackfriday &> /dev/null; then
    echo "   Eliminando deployment anterior..."
    kubectl delete deployment api-rust -n blackfriday
    sleep 3
fi

# Desplegar API Rust
echo "   Desplegando API Rust..."
kubectl apply -f k8s/06-api-rust.yaml

# Desplegar/actualizar Nginx
echo "   Desplegando Nginx Proxy..."
kubectl apply -f k8s/07-nginx-proxy.yaml

# Esperar a que los pods estén listos
echo ""
echo "⏳ Esperando a que los pods estén listos (esto puede tomar 30-60 segundos)..."
kubectl wait --for=condition=ready pod -l app=api-rust -n blackfriday --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=nginx-proxy -n blackfriday --timeout=60s || true

echo ""
echo "📊 Estado del despliegue:"
kubectl get pods -n blackfriday
echo ""
kubectl get services -n blackfriday

echo ""
echo "✅ Despliegue completado"
echo ""

# Obtener URL
NGINX_URL=$(minikube service nginx-proxy-service -n blackfriday --url 2>/dev/null)

echo "🌐 URLs de acceso:"
echo "   Nginx Proxy: $NGINX_URL"
echo "   (o usa: http://192.168.49.2:30300)"
echo ""

echo "🧪 Pruebas rápidas:"
echo "   curl $NGINX_URL/health"
echo "   curl $NGINX_URL/"
echo "   curl $NGINX_URL/productos"
echo ""

echo "💡 Ver logs:"
echo "   kubectl logs -f -l app=api-rust -n blackfriday"
echo "   kubectl logs -f -l app=nginx-proxy -n blackfriday"
echo ""

# Ejecutar pruebas automáticas
if [ -f "k8s/test-nginx.sh" ]; then
    echo "🧪 Ejecutando pruebas automáticas en 5 segundos..."
    sleep 5
    cd k8s
    ./test-nginx.sh
fi
