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
ZOT_IP="18.219.92.152:30000"
PUBLIC_IP="13.58.12.224"

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Despliegue en EC2 - Stack Black Friday${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Instalar NGINX Ingress Controller
info "Instalando NGINX Ingress Controller..."
if ! sudo kubectl get namespace ingress-nginx &>/dev/null; then
    info "Instalando NGINX Ingress Controller..."
    sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml
    
    info "Esperando que el Ingress Controller esté listo..."
    sleep 10
    sudo kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=120s || warning "Timeout esperando Ingress Controller, continuando..."
    
    # Configurar como NodePort
    sudo kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080,"name":"http"},{"port":443,"nodePort":30443,"name":"https"}]}}' || true
    success "Ingress Controller instalado"
else
    success "Ingress Controller ya está instalado"
fi

# 2. Verificar Namespace
info "Configurando Namespace: $NAMESPACE"
sudo kubectl create namespace $NAMESPACE --dry-run=client -o yaml | sudo kubectl apply -f -

# 3. Limpieza (Opcional: borrar pods previos para asegurar reinicio fresco)
info "Limpiando pods existentes en el namespace..."
sudo kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force || true

# 4. Actualizar referencias de imágenes al Zot remoto
info "Actualizando referencias de imágenes a Zot remoto: $ZOT_IP"
for file in k8s/*.yaml; do
    if [ -f "$file" ]; then
        # Reemplazar referencias de imágenes al nuevo Zot
        sudo sed -i "s|image: 10\.111\.22\.66:5000/|image: $ZOT_IP/|g" "$file"
        sudo sed -i "s|image: localhost:5000/|image: $ZOT_IP/|g" "$file"
    fi
done
success "Referencias de imágenes actualizadas"

# 5. Despliegue de Base de Datos y Mensajería (Infraestructura)
info "Desplegando infraestructura básica..."

su6o kubectl apply -f k8s/01-zookeeper.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/02-kafka.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/08-valkey.yaml -n $NAMESPACE

info "Esperando a que la infraestructura esté lista..."
sleep 15

# 4. Despliegue de Servicios de Aplicación
info "Desplegando microservicios..."
sudo kubectl apply -f k8s/11-grpc-server-1.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/12-grpc-server-2.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/10-go-api-rest.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/06-api-rust.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/09-kafka-consumer.yaml -n $NAMESPACE

# 7. Despliegue de Herramientas y Proxy
info "Desplegando Nginx Proxy (capa interna), Locust y Grafana..."
sudo kubectl apply -f k8s/07-nginx-proxy.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/13-locust.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/14-grafana.yaml -n $NAMESPACE

# 8. Despliegue de Ingress (Punto de entrada)
info "Desplegando Ingress Controller resources..."
if [ -f "k8s/15-ingress.yaml" ]; then
echo ""
info "Verificando Ingress..."
sudo kubectl get ingress -n $NAMESPACE

echo ""
success "========================================"
success "🚀 DESPLIEGUE EN EC2 FINALIZADO"
success "========================================"
echo ""
echo -e "${GREEN}📊 Arquitectura Implementada:${NC}"
echo "Cliente → Ingress Controller (puerto 30080) → NGINX Proxy → API Rust"
echo ""
echo -e "${YELLOW}🌐 Acceso a través de INGRESS (Recomendado):${NC}"
echo "URL Base:     http://$PUBLIC_IP:30080/"
echo "API Rust:     http://$PUBLIC_IP:30080/"
echo "Go API:       http://$PUBLIC_IP:30080/api/go"
echo "Grafana:      http://$PUBLIC_IP:30080/grafana"
echo "Locust:       http://$PUBLIC_IP:30080/locust"
echo "API Rust Direct: http://$PUBLIC_IP:30080/api/rust"
echo ""
echo -e "${YELLOW}🔧 Acceso Directo (NodePort - Legacy):${NC}"
echo "Grafana:      http://$PUBLIC_IP:32000"
echo "Locust:       http://$PUBLIC_IP:30089"
echo ""
echo -e "${BLUE}ℹ️  Notas:${NC}"
echo "• El Ingress Controller funciona como punto de entrada único"
echo "• NGINX Proxy (capa interna) maneja el tráfico hacia API Rust"
echo "• Timeouts configurados: 60 segundos"
echo "• Keep-alive: 100 conexiones"
echo ""
echo -e "${GREEN}✅ Todos los servicios disponibles en: http://$PUBLIC_IP:30080${NC}
echo ""
success "========================================"
success "🚀 DESPLIEGUE EN EC2 FINALIZADO"
success "========================================"
echo -e "${YELLOW}Acceso Externo:${NC}"
echo "Grafana: http://$PUBLIC_IP:32000"
echo "Locust:  http://$PUBLIC_IP:30089"
echo "API Go:   http://$PUBLIC_IP:30080"
echo "Nginx:   http://$PUBLIC_IP:30081"
