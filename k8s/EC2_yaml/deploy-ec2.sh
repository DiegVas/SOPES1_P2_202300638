#!/bin/bash

# Script de Despliegue para AWS EC2 - Arquitectura Distribuida
set -e

# Colores para la terminal
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# CONFIGURACIÓN - CAMBIA ESTO
NAMESPACE="blackfriday"
ZOT_IP="3.129.65.122:30000"
PUBLIC_IP="18.220.40.168"

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Función para esperar que los pods estén listos
wait_for_pods() {
  local label=$1
  local timeout=${2:-300}
  local count=0
  
  info "Esperando que los pods con label '$label' estén listos..."
  while [ $count -lt $timeout ]; do
    ready=$($KUBECTL_CMD get pods -n $NAMESPACE -l $label -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -o true | wc -l || echo 0)
    total=$($KUBECTL_CMD get pods -n $NAMESPACE -l $label --no-headers 2>/dev/null | wc -l || echo 0)
    
    if [ "$total" -gt 0 ] && [ "$ready" -eq "$total" ]; then
      success "Todos los pods con label '$label' están listos ($ready/$total)"
      return 0
    fi
    
    echo -ne "\r⏳ Esperando pods... ($ready/$total listos) - ${count}s"
    sleep 5
    count=$((count + 5))
  done
  
  echo ""
  warning "Timeout esperando pods con label '$label'"
  $KUBECTL_CMD get pods -n $NAMESPACE -l $label
  return 1
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Despliegue en EC2 - Stack Black Friday${NC}"
echo -e "${BLUE}========================================${NC}"

# 0. Verificar que Kubernetes está funcionando
info "Verificando cluster de Kubernetes..."

# Detectar tipo de instalación (kubectl, k3s, microk8s)
KUBECTL_CMD=""
if command -v kubectl &> /dev/null; then
    KUBECTL_CMD="kubectl"
elif command -v k3s &> /dev/null; then
    KUBECTL_CMD="k3s kubectl"
    info "Detectado K3s, usando 'k3s kubectl'"
elif command -v microk8s &> /dev/null; then
    KUBECTL_CMD="microk8s kubectl"
    info "Detectado MicroK8s, usando 'microk8s kubectl'"
else
    error "No se encontró kubectl, k3s ni microk8s instalado"
    error "Por favor instala Kubernetes primero"
    exit 1
fi

# Verificar que el cluster responde
if ! $KUBECTL_CMD cluster-info &> /dev/null; then
    error "El cluster de Kubernetes no está respondiendo"
    error "Posibles soluciones:"
    echo "  1. Verificar que el servicio está corriendo:"
    echo "     sudo systemctl status kubelet  # o k3s, microk8s"
    echo "  2. Reiniciar el servicio:"
    echo "     sudo systemctl restart kubelet"
    echo "  3. Verificar logs:"
    echo "     sudo journalctl -xeu kubelet -f"
    exit 1
fi

success "✓ Cluster de Kubernetes funcionando correctamente"

# Verificar conectividad con Zot
info "Verificando conectividad con Zot registry en $ZOT_IP..."
if curl -s --connect-timeout 5 "http://$ZOT_IP/v2/" > /dev/null; then
  success "✓ Zot registry accesible en $ZOT_IP"
else
  error "✗ No se puede conectar con Zot registry en $ZOT_IP"
  error "Asegúrate de que el registro Zot esté funcionando y accesible"
  exit 1
fi

# 1. Verificar Namespace
info "Configurando Namespace: $NAMESPACE"
$KUBECTL_CMD create namespace $NAMESPACE --dry-run=client -o yaml | $KUBECTL_CMD apply -f - || {
    error "Error creando namespace. Intentando con sudo..."
    sudo $KUBECTL_CMD create namespace $NAMESPACE --dry-run=client -o yaml | sudo $KUBECTL_CMD apply -f -
}

# 1.5 Aplicar ConfigMap
info "Aplicando configuración base..."
$KUBECTL_CMD apply -f 00-namespace-config.yaml -n $NAMESPACE 2>/dev/null || \
$KUBECTL_CMD delete pods --all -n $NAMESPACE --grace-period=10 --force 2>/dev/null || \
    sudo $KUBECTL_CMDBECTL_CMD apply -f 00-namespace-config.yaml -n $NAMESPACE

# 2. Limpieza (Opcional: borrar pods previos para asegurar reinicio fresco)
warning "Limpiando recursos existentes en el namespace..."
sudo kubectl delete pods --all -n $NAMESPACE --grace-period=10 --force 2>/dev/null || true
sleep 5

# 3. Despliegue de Base de Datos y Mensajería (Infraestructura)
info "Desplegando infraestructura básica..."

# Desplegamos en orden de dependencia
info "→ Desplegando Zookeeper..."
$KUBECTL_CMD apply -f 01-zookeeper.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 01-zookeeper.yaml -n $NAMESPACE
wait_for_pods "app=zookeeper" 60

info "→ Desplegando Kafka..."
$KUBECTL_CMD apply -f 02-kafka.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 02-kafka.yaml -n $NAMESPACE
wait_for_pods "app=kafka" 90

info "→ Desplegando Valkey..."
$KUBECTL_CMD apply -f 08-valkey.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 08-valkey.yaml -n $NAMESPACE
wait_for_pods "app=valkey" 60

success "Infraestructura básica desplegada correctamente"
sleep 5

# 4. Despliegue de Servicios de Aplicación
info "Desplegando microservicios..."

info "→ Desplegando gRPC Servers..."
$KUBECTL_CMD apply -f 11-grpc-server-1.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 11-grpc-server-1.yaml -n $NAMESPACE
$KUBECTL_CMD apply -f 12-grpc-server-2.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 12-grpc-server-2.yaml -n $NAMESPACE
wait_for_pods "app=grpc-server-1" 120
wait_for_pods "app=grpc-server-2" 120

info "→ Desplegando Go API REST..."
$KUBECTL_CMD apply -f 10-go-api-rest.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 10-go-api-rest.yaml -n $NAMESPACE
wait_for_pods "app=go-api-rest" 120

info "→ Desplegando Rust API..."
$KUBECTL_CMD apply -f 06-api-rust.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 06-api-rust.yaml -n $NAMESPACE
wait_for_pods "app=api-rust" 120

info "→ Desplegando Kafka Consumer..."
$KUBECTL_CMD apply -f 09-kafka-consumer.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 09-kafka-consumer.yaml -n $NAMESPACE
wait_for_pods "app=kafka-consumer" 120

success "Microservicios desplegados correctamente"

# 5. Despliegue de Herramientas y Proxy
info "Desplegando Nginx, Locust y Grafana..."

info "→ Desplegando Nginx Proxy..."
$KUBECTL_CMD apply -f 07-nginx-proxy.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 07-nginx-proxy.yaml -n $NAMESPACE
wait_for_pods "app=nginx-proxy" 90

info "→ Desplegando Locust..."
$KUBECTL_CMD apply -f 13-locust.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 13-locust.yaml -n $NAMESPACE
wait_for_pods "app=locust" 90

info "→ Desplegando Grafana..."
$KUBECTL_CMD apply -f 14-grafana.yaml -n $NAMESPACE || sudo $KUBECTL_CMD apply -f 14-grafana.yaml -n $NAMESPACE
wait_for_pods "app=grafana" 90

success "Herramientas y proxy desplegados correctamente"

echo ""
info "========================================="
info "Verificando estado final de los servicios..."
echo ""
$KUBECTL_CMD get pods -n $NAMESPACE -o wide || sudo $KUBECTL_CMD get pods -n $NAMESPACE -o wide

echo ""
info "Verificando servicios..."
$KUBECTL_CMD get svc -n $NAMESPACE || sudo $KUBECTL_CMD get svc -n $NAMESPACE

echo ""
success "========================================"
success "🚀 DESPLIEGUE EN EC2 FINALIZADO"
success "========================================"
echo ""
echo -e "${YELLOW}📊 URLs de Acceso Externo:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Grafana:  ${BLUE}http://$PUBLIC_IP:32000${NC}"
echo -e "Locust:   ${BLUE}http://$PUBLIC_IP:30089${NC}"
echo -e "API Go:   ${BLUE}http://$PUBLIC_IP:30080${NC}"
echo -e "Nginx:    ${BLUE}http://$PUBLIC_IP:30081${NC}"
echo ""
echo -e "${YELLOW}🔧 Registro de Imágenes:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Zot:      ${BLUE}http://$ZOT_IP${NC}"
echo ""
echo -e "${YELLOW}💡 Comandos útiles:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Ver logs:     sudo kubectl logs -f <pod-name> -n $NAMESPACE"
echo "Ver pods:     sudo kubectl get pods -n $NAMESPACE"
echo "Describir:    sudo kubectl describe pod <pod-name> -n $NAMESPACE"
echo "Reiniciar:    sudo kubectl rollout restart deployment <deployment-name> -n $NAMESPACE"
