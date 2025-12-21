#!/bin/bash

echo "🚀 Desplegando Nginx Proxy para API de Rust en Kubernetes..."
echo ""

# Verificar que kubectl esté instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl no está instalado"
    echo "   Instala kubectl con: sudo snap install kubectl --classic"
    exit 1
fi

# Verificar si minikube está corriendo
if command -v minikube &> /dev/null; then
    if ! minikube status > /dev/null 2>&1; then
        echo "⚠️  Minikube no está corriendo"
        echo "   Inicia minikube con: minikube start"
        exit 1
    fi
    
    echo "⚙️  Configurando entorno de Docker de Minikube..."
    eval $(minikube -p minikube docker-env)
    
    # Construir imagen de Rust API en minikube
    echo "📦 Construyendo imagen de Rust API..."
    cd "$(dirname "$0")/.." || exit
    docker build -f api/Dockerfile -t rust-api:latest .
    if [ $? -ne 0 ]; then
        echo "❌ Error construyendo Rust API"
        exit 1
    fi
    echo "✅ Imagen de Rust API construida"
    echo ""
fi

# Aplicar manifiestos
echo "☸️  Desplegando recursos en Kubernetes..."
echo ""

# Crear namespace si no existe
echo "0️⃣  Verificando namespace..."
if ! kubectl get namespace blackfriday &> /dev/null; then
    echo "   Creando namespace blackfriday..."
    kubectl apply -f k8s/00-namespace-config.yaml
    if [ $? -ne 0 ]; then
        echo "❌ Error creando namespace"
        exit 1
    fi
    echo "✅ Namespace creado"
    sleep 2
else
    echo "✅ Namespace blackfriday ya existe"
fi
echo ""

echo "1️⃣  Desplegando API de Rust..."
kubectl apply -f k8s/06-api-rust.yaml
if [ $? -ne 0 ]; then
    echo "❌ Error desplegando API de Rust"
    exit 1
fi
echo "✅ API de Rust desplegada"
echo ""

echo "2️⃣  Desplegando Nginx Proxy..."
kubectl apply -f k8s/07-nginx-proxy.yaml
if [ $? -ne 0 ]; then
    echo "❌ Error desplegando Nginx Proxy"
    exit 1
fi
echo "✅ Nginx Proxy desplegado"
echo ""

# Esperar a que los pods estén listos
echo "⏳ Esperando a que los pods estén listos..."
sleep 5

# Mostrar estado
echo ""
echo "📊 Estado de los pods:"
kubectl get pods -n blackfriday -l app=api-rust
kubectl get pods -n blackfriday -l app=nginx-proxy

echo ""
echo "📊 Estado de los servicios:"
kubectl get services -n blackfriday | grep -E "api-rust-service|nginx-proxy-service"

echo ""
echo "✅ Despliegue completado"
echo ""

# Obtener la URL de acceso
if command -v minikube &> /dev/null; then
    NGINX_URL=$(minikube service nginx-proxy-service -n blackfriday --url 2>/dev/null)
    if [ -n "$NGINX_URL" ]; then
        echo "🌐 Nginx Proxy disponible en: $NGINX_URL"
    else
        echo "🌐 Nginx Proxy disponible en: http://localhost:30300"
    fi
else
    echo "🌐 Nginx Proxy disponible en: http://localhost:30300"
fi

echo ""
echo "🧪 Pruebas rápidas:"
echo "   # Health check de nginx"
echo "   curl http://localhost:30300/health"
echo ""
echo "   # Obtener productos (a través de nginx)"
echo "   curl http://localhost:30300/productos"
echo ""
echo "💡 Para ver logs:"
echo "   kubectl logs -f -l app=nginx-proxy -n blackfriday"
echo "   kubectl logs -f -l app=api-rust -n blackfriday"
echo ""
