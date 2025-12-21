#!/bin/bash

# Script de Despliegue Optimizado - Bajo Consumo de Recursos
# Para PCs con recursos limitados

set -e
set -u
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Black Friday System - Despliegue OPTIMIZADO${NC}"
echo -e "${BLUE}   (Modo bajo consumo de recursos)${NC}"
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
# PASO 2: Configurar Minikube con Recursos Limitados
# ============================================
info "PASO 2: Configurando Minikube con recursos limitados..."

if minikube status | grep -q "Running"; then
    warning "Minikube ya está corriendo. Para aplicar configuración de recursos, detén y reinicia con:"
    warning "  minikube stop && minikube start --cpus=2 --memory=4096"
    info "Continuando con la configuración actual..."
else
    info "Iniciando Minikube con recursos limitados (2 CPUs, 4GB RAM)..."
    minikube start --cpus=2 --memory=4096 || error_exit "No se pudo iniciar Minikube"
    success "Minikube iniciado con recursos optimizados"
fi

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

rm -rf go-api-rest/proto
cp -r grpc-server/proto go-api-rest/ || error_exit "No se pudo copiar proto a go-api-rest"

if [ ! -d "grpc-server/proto" ] || [ ! -d "go-api-rest/proto" ]; then
    error_exit "Los archivos proto no se generaron correctamente"
fi

success "Archivos proto generados correctamente"
echo ""

# ============================================
# PASO 5: Construir Imágenes Docker (una por una para no saturar)
# ============================================
info "PASO 5: Construyendo imágenes Docker (una por una)..."

eval $(minikube docker-env) || error_exit "No se pudo configurar Docker con Minikube"

info "Construyendo API Rust..."
docker build -t rust-api:latest -f api/Dockerfile . || error_exit "Error construyendo rust-api"
success "rust-api construida"
sleep 2

info "Construyendo Go API REST..."
docker build -t go-api-rest:latest -f go-api-rest/Dockerfile.simple go-api-rest || error_exit "Error construyendo go-api-rest"
success "go-api-rest construida"
sleep 2

info "Construyendo gRPC Server..."
docker build -t grpc-server:latest -f grpc-server/Dockerfile.simple grpc-server || error_exit "Error construyendo grpc-server"
success "grpc-server construida"
sleep 2

info "Construyendo Kafka Consumer..."
docker build -t kafka-consumer:latest ./kafka-consumer || error_exit "Error construyendo kafka-consumer"
success "kafka-consumer construida"
sleep 2

info "Construyendo Locust..."
docker build -t locust:latest ./locust || error_exit "Error construyendo locust"
success "locust construida"

docker images | grep -E "rust-api|go-api-rest|grpc-server|kafka-consumer|locust" || error_exit "No se encontraron todas las imágenes"
success "Todas las imágenes Docker construidas correctamente"
echo ""

# ============================================
# PASO 6: Desplegar Componentes ESENCIALES PRIMERO
# ============================================
info "PASO 6: Desplegando componentes esenciales (uno por uno)..."

# 6.1 Zookeeper
info "Desplegando Zookeeper..."
kubectl apply -f k8s/01-zookeeper.yaml || error_exit "Error desplegando Zookeeper"
info "Esperando a que Zookeeper esté listo (max 2 min)..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n blackfriday --timeout=120s || error_exit "Zookeeper no está listo"
success "Zookeeper desplegado"
sleep 5

# 6.2 Kafka
info "Desplegando Kafka..."
kubectl apply -f k8s/02-kafka.yaml || error_exit "Error desplegando Kafka"
info "Esperando 30 segundos para inicialización de Kafka..."
sleep 30
kubectl wait --for=condition=ready pod -l app=kafka -n blackfriday --timeout=120s || error_exit "Kafka no está listo"
success "Kafka desplegado"
sleep 5

# 6.3 Valkey
info "Desplegando Valkey..."
kubectl apply -f k8s/08-valkey.yaml || error_exit "Error desplegando Valkey"
info "Esperando 20 segundos para inicialización de Valkey..."
sleep 20
kubectl wait --for=condition=ready pod -l app=valkey -n blackfriday --timeout=120s || error_exit "Valkey no está listo"
success "Valkey desplegado"
sleep 5

# 6.4 gRPC Server 1 (solo 1 réplica)
info "Desplegando gRPC Server 1..."
kubectl apply -f k8s/11-grpc-server-1.yaml || error_exit "Error desplegando grpc-server-1"
sleep 10
kubectl wait --for=condition=ready pod -l app=grpc-server-1 -n blackfriday --timeout=90s || error_exit "grpc-server-1 no está listo"
success "gRPC Server 1 desplegado"

# 6.5 gRPC Server 2 (reducir a 1 réplica)
info "Desplegando gRPC Server 2 (1 réplica)..."
kubectl apply -f k8s/12-grpc-server-2.yaml || error_exit "Error desplegando grpc-server-2"
kubectl scale deployment grpc-server-2 --replicas=1 -n blackfriday
sleep 10
kubectl wait --for=condition=ready pod -l app=grpc-server-2 -n blackfriday --timeout=90s || error_exit "grpc-server-2 no está listo"
success "gRPC Server 2 desplegado (1 réplica)"

# 6.6 Go API REST (reducir a 1 réplica)
info "Desplegando Go API REST (1 réplica)..."
kubectl apply -f k8s/10-go-api-rest.yaml || error_exit "Error desplegando go-api-rest"
kubectl scale deployment go-api-rest --replicas=1 -n blackfriday
sleep 10
kubectl wait --for=condition=ready pod -l app=go-api-rest -n blackfriday --timeout=90s || error_exit "go-api-rest no está listo"
success "Go API REST desplegado (1 réplica)"

# 6.7 API Rust (reducir a 1 réplica)
info "Desplegando API Rust (1 réplica)..."
kubectl apply -f k8s/06-api-rust.yaml || error_exit "Error desplegando api-rust"
kubectl scale deployment api-rust --replicas=1 -n blackfriday
sleep 10
kubectl wait --for=condition=ready pod -l app=api-rust -n blackfriday --timeout=120s || error_exit "api-rust no está listo"
success "API Rust desplegado (1 réplica)"

# 6.8 Nginx Proxy (reducir a 1 réplica)
info "Desplegando Nginx Proxy (1 réplica)..."
kubectl apply -f k8s/07-nginx-proxy.yaml || error_exit "Error desplegando nginx-proxy"
kubectl scale deployment nginx-proxy --replicas=1 -n blackfriday
sleep 10
kubectl wait --for=condition=ready pod -l app=nginx-proxy -n blackfriday --timeout=90s || error_exit "nginx-proxy no está listo"
success "Nginx Proxy desplegado (1 réplica)"

# 6.9 Kafka Consumer (reducir a 1 réplica)
info "Desplegando Kafka Consumer (1 réplica)..."
kubectl apply -f k8s/09-kafka-consumer.yaml || error_exit "Error desplegando kafka-consumer"
kubectl scale deployment kafka-consumer --replicas=1 -n blackfriday
sleep 10
kubectl wait --for=condition=ready pod -l app=kafka-consumer -n blackfriday --timeout=90s || error_exit "kafka-consumer no está listo"
success "Kafka Consumer desplegado (1 réplica)"

# 6.10 Locust
info "Desplegando Locust..."
kubectl apply -f k8s/13-locust.yaml || error_exit "Error desplegando locust"
success "Locust desplegado"

# 6.11 Grafana
info "Desplegando Grafana..."
kubectl apply -f k8s/14-grafana.yaml || error_exit "Error desplegando grafana"
info "Esperando a que Grafana esté listo (puede tardar)..."
sleep 20
kubectl wait --for=condition=ready pod -l app=grafana -n blackfriday --timeout=120s || error_exit "Grafana no está listo"
success "Grafana desplegado"

echo ""
success "Todos los componentes desplegados con configuración optimizada"
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

info "Esperando 10 segundos para que todos los servicios estén completamente listos..."
sleep 10

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
    warning "No se encontraron datos en Valkey"
fi

echo ""

# ============================================
# PASO 9: Mostrar Configuración Final
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DESPLIEGUE OPTIMIZADO COMPLETADO${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuración de réplicas (optimizada):${NC}"
echo "  • Zookeeper: 1 réplica"
echo "  • Kafka: 1 réplica"
echo "  • Valkey: 2 réplicas (StatefulSet)"
echo "  • gRPC Server 1: 1 réplica"
echo "  • gRPC Server 2: 1 réplica"
echo "  • Go API REST: 1 réplica"
echo "  • API Rust: 1 réplica"
echo "  • Nginx Proxy: 1 réplica"
echo "  • Kafka Consumer: 1 réplica"
echo "  • Locust: 1 réplica"
echo "  • Grafana: 1 réplica"
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
echo "  Ver recursos:    kubectl top pods -n blackfriday"
echo "  Ver pods:        kubectl get pods -n blackfriday"
echo "  Ver logs:        kubectl logs -n blackfriday -l app=<nombre-app>"
echo ""
echo -e "${GREEN}¡Sistema listo con consumo optimizado!${NC}"
echo ""
