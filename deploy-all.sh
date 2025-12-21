#!/bin/bash

# Script de Despliegue Completo - Black Friday System
# Detiene la ejecución al primer error

set -e  # Detener al primer error
set -u  # Tratar variables no definidas como error
set -o pipefail  # Detectar errores en pipes

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar errores y salir
error_exit() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    exit 1
}

# Función para mostrar información
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Función para mostrar éxito
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Función para mostrar advertencias
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Black Friday System - Despliegue Completo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# PASO 1: Verificar Prerequisitos
# ============================================
info "PASO 1: Verificando prerequisitos..."

command -v minikube >/dev/null 2>&1 || error_exit "minikube no está instalado"
command -v kubectl >/dev/null 2>&1 || error_exit "kubectl no está instalado"
command -v docker >/dev/null 2>&1 || error_exit "docker no está instalado"
command -v go >/dev/null 2>&1 || error_exit "go no está instalado"

success "Todos los prerequisitos están instalados"
echo ""

# ============================================
# PASO 2: Iniciar Minikube
# ============================================
info "PASO 2: Verificando estado de Minikube..."

if minikube status | grep -q "Running"; then
    success "Minikube ya está corriendo"
else
    info "Iniciando Minikube..."
    minikube start || error_exit "No se pudo iniciar Minikube"
    success "Minikube iniciado correctamente"
fi

# Verificar kubectl
kubectl get nodes >/dev/null 2>&1 || error_exit "kubectl no puede conectarse al cluster"

MINIKUBE_IP=$(minikube ip)
info "IP de Minikube: $MINIKUBE_IP"
echo ""

# ============================================
# PASO 3: Crear Namespace
# ============================================
info "PASO 3: Creando namespace blackfriday..."

kubectl create namespace blackfriday --dry-run=client -o yaml | kubectl apply -f - || error_exit "No se pudo crear el namespace"
success "Namespace blackfriday creado/verificado"
echo ""

# ============================================
# PASO 4: Generar Archivos Proto
# ============================================
info "PASO 4: Generando archivos proto..."

if [ ! -f "grpc-server/generate.sh" ]; then
    error_exit "No se encuentra grpc-server/generate.sh"
fi

cd grpc-server
chmod +x generate.sh
./generate.sh || error_exit "No se pudieron generar los archivos proto"
cd ..

# Copiar proto a go-api-rest
rm -rf go-api-rest/proto
cp -r grpc-server/proto go-api-rest/ || error_exit "No se pudo copiar proto a go-api-rest"

# Verificar que los archivos existen
if [ ! -d "grpc-server/proto" ] || [ ! -d "go-api-rest/proto" ]; then
    error_exit "Los archivos proto no se generaron correctamente"
fi

success "Archivos proto generados correctamente"
echo ""

# ============================================
# PASO 5: Construir Imágenes Docker
# ============================================
info "PASO 5: Construyendo imágenes Docker..."

# Configurar Docker para usar daemon de minikube
eval $(minikube docker-env) || error_exit "No se pudo configurar Docker con Minikube"

info "Construyendo API Rust..."
docker build -t rust-api:latest -f api/Dockerfile . || error_exit "Error construyendo rust-api"
success "rust-api construida"

info "Construyendo Go API REST..."
docker build -t go-api-rest:latest -f go-api-rest/Dockerfile.simple go-api-rest || error_exit "Error construyendo go-api-rest"
success "go-api-rest construida"

info "Construyendo gRPC Server..."
docker build -t grpc-server:latest -f grpc-server/Dockerfile.simple grpc-server || error_exit "Error construyendo grpc-server"
success "grpc-server construida"

info "Construyendo Kafka Consumer..."
docker build -t kafka-consumer:latest ./kafka-consumer || error_exit "Error construyendo kafka-consumer"
success "kafka-consumer construida"

info "Construyendo Locust..."
docker build -t locust:latest ./locust || error_exit "Error construyendo locust"
success "locust construida"

# Verificar que todas las imágenes existen
docker images | grep -E "rust-api|go-api-rest|grpc-server|kafka-consumer|locust" || error_exit "No se encontraron todas las imágenes"
success "Todas las imágenes Docker construidas correctamente"
echo ""

# ============================================
# PASO 6: Desplegar Componentes en Orden
# ============================================
info "PASO 6: Desplegando componentes en Kubernetes..."

# 6.1 Zookeeper
info "Desplegando Zookeeper..."
kubectl apply -f k8s/01-zookeeper.yaml || error_exit "Error desplegando Zookeeper"
kubectl wait --for=condition=ready pod -l app=zookeeper -n blackfriday --timeout=120s || error_exit "Zookeeper no está listo"
success "Zookeeper desplegado"

# 6.2 Kafka
info "Desplegando Kafka..."
kubectl apply -f k8s/02-kafka.yaml || error_exit "Error desplegando Kafka"
sleep 30
kubectl wait --for=condition=ready pod -l app=kafka -n blackfriday --timeout=120s || error_exit "Kafka no está listo"
success "Kafka desplegado"

# 6.3 Valkey
info "Desplegando Valkey..."
kubectl apply -f k8s/08-valkey.yaml || error_exit "Error desplegando Valkey"
sleep 20
kubectl wait --for=condition=ready pod -l app=valkey -n blackfriday --timeout=120s || error_exit "Valkey no está listo"
success "Valkey desplegado"

# 6.4 gRPC Servers
info "Desplegando gRPC Servers..."
kubectl apply -f k8s/11-grpc-server-1.yaml || error_exit "Error desplegando grpc-server-1"
kubectl apply -f k8s/12-grpc-server-2.yaml || error_exit "Error desplegando grpc-server-2"
sleep 15
kubectl wait --for=condition=ready pod -l app=grpc-server-1 -n blackfriday --timeout=90s || error_exit "grpc-server-1 no está listo"
kubectl wait --for=condition=ready pod -l app=grpc-server-2 -n blackfriday --timeout=90s || error_exit "grpc-server-2 no está listo"
success "gRPC Servers desplegados"

# 6.5 Go API REST
info "Desplegando Go API REST..."
kubectl apply -f k8s/10-go-api-rest.yaml || error_exit "Error desplegando go-api-rest"
sleep 15
kubectl wait --for=condition=ready pod -l app=go-api-rest -n blackfriday --timeout=90s || error_exit "go-api-rest no está listo"
success "Go API REST desplegado"

# 6.6 API Rust
info "Desplegando API Rust..."
kubectl apply -f k8s/06-api-rust.yaml || error_exit "Error desplegando api-rust"
sleep 15
kubectl wait --for=condition=ready pod -l app=api-rust -n blackfriday --timeout=120s || error_exit "api-rust no está listo"
success "API Rust desplegado"

# 6.7 Nginx Proxy
info "Desplegando Nginx Proxy..."
kubectl apply -f k8s/07-nginx-proxy.yaml || error_exit "Error desplegando nginx-proxy"
sleep 10
kubectl wait --for=condition=ready pod -l app=nginx-proxy -n blackfriday --timeout=90s || error_exit "nginx-proxy no está listo"
success "Nginx Proxy desplegado"

# 6.8 Kafka Consumer
info "Desplegando Kafka Consumer..."
kubectl apply -f k8s/09-kafka-consumer.yaml || error_exit "Error desplegando kafka-consumer"
sleep 10
kubectl wait --for=condition=ready pod -l app=kafka-consumer -n blackfriday --timeout=90s || error_exit "kafka-consumer no está listo"
success "Kafka Consumer desplegado"

# 6.9 Locust
info "Desplegando Locust..."
kubectl apply -f k8s/13-locust.yaml || error_exit "Error desplegando locust"
success "Locust desplegado"

# 6.10 Grafana
info "Desplegando Grafana..."
kubectl apply -f k8s/14-grafana.yaml || error_exit "Error desplegando grafana"
sleep 20
kubectl wait --for=condition=ready pod -l app=grafana -n blackfriday --timeout=120s || error_exit "Grafana no está listo"
success "Grafana desplegado"

echo ""
success "Todos los componentes desplegados correctamente"
echo ""

# ============================================
# PASO 7: Verificar Estado
# ============================================
info "PASO 7: Verificando estado de los pods..."
echo ""

kubectl get pods -n blackfriday

echo ""
FAILED_PODS=$(kubectl get pods -n blackfriday --no-headers | grep -v "Running" | grep -v "Completed" || true)
if [ -n "$FAILED_PODS" ]; then
    warning "Algunos pods no están en estado Running:"
    echo "$FAILED_PODS"
else
    success "Todos los pods están en estado Running"
fi

echo ""

# ============================================
# PASO 8: Prueba de Funcionamiento
# ============================================
info "PASO 8: Realizando prueba de funcionamiento..."

info "Esperando 5 segundos para que todos los servicios estén listos..."
sleep 5

info "Probando health check..."
if curl -s http://$MINIKUBE_IP:30300/health | grep -q "OK"; then
    success "API respondiendo correctamente"
else
    warning "API no responde correctamente en /health"
fi

info "Realizando compra de prueba..."
RESPONSE=$(curl -s -X POST http://$MINIKUBE_IP:30300/comprar \
  -H "Content-Type: application/json" \
  -d '{"producto_id": "prod001", "cantidad": 1, "usuario": "test-deploy"}')

if echo "$RESPONSE" | grep -q "exitoso"; then
    success "Compra de prueba exitosa"
    echo "Respuesta: $RESPONSE"
else
    warning "La compra de prueba falló"
    echo "Respuesta: $RESPONSE"
fi

echo ""
info "Esperando 5 segundos para que el mensaje se procese..."
sleep 5

info "Verificando datos en Valkey..."
TOTAL_COMPRAS=$(kubectl exec -n blackfriday valkey-0 -- valkey-cli GET "total:compras" 2>/dev/null || echo "0")
if [ "$TOTAL_COMPRAS" != "0" ] && [ -n "$TOTAL_COMPRAS" ]; then
    success "Datos almacenados en Valkey: $TOTAL_COMPRAS compras totales"
else
    warning "No se encontraron datos en Valkey (esto puede ser normal en el primer despliegue)"
fi

echo ""

# ============================================
# PASO 9: Mostrar URLs de Acceso
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DESPLIEGUE COMPLETADO EXITOSAMENTE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}URLs de Acceso:${NC}"
echo -e "${BLUE}========================================${NC}"
echo "API REST:    http://$MINIKUBE_IP:30300"
echo "Locust:      http://$MINIKUBE_IP:30089"
echo "Grafana:     http://$MINIKUBE_IP:30000"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Credenciales Grafana:${NC}"
echo "  Usuario: admin"
echo "  Password: admin"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Comandos Útiles:${NC}"
echo "  Ver pods:        kubectl get pods -n blackfriday"
echo "  Ver servicios:   kubectl get svc -n blackfriday"
echo "  Ver logs:        kubectl logs -n blackfriday -l app=<nombre-app>"
echo "  Reiniciar pod:   kubectl rollout restart deployment <nombre> -n blackfriday"
echo ""
echo -e "${GREEN}¡Sistema listo para usar!${NC}"
echo ""
