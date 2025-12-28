#!/bin/bash

# Script para instalar NGINX Ingress Controller en EC2/K3s

set -e

# Colores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "======================================"
echo "Instalando NGINX Ingress Controller"
echo "======================================"

# Aplicar el NGINX Ingress Controller - versión para bare-metal/k3s
info "Aplicando NGINX Ingress Controller..."
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml

echo ""
info "Esperando a que el Ingress Controller esté listo..."
sudo kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s || warning "Timeout esperando pods, continuando..."

echo ""
info "Configurando servicio como NodePort..."
# Asegurar que el servicio sea NodePort con puerto específico
sudo kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080,"name":"http"},{"port":443,"nodePort":30443,"name":"https"}]}}'

echo ""
echo "======================================"
echo "Estado del Ingress Controller:"
echo "======================================"
sudo kubectl get pods -n ingress-nginx
sudo kubectl get svc -n ingress-nginx

echo ""
success "======================================"
success "✅ NGINX Ingress Controller instalado"
success "======================================"
echo ""
info "El Ingress Controller está disponible en el puerto 30080 (HTTP) y 30443 (HTTPS)"
