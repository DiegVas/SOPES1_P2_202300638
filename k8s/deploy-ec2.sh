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
ZOT_IP="18.221.7.87:30000"
PUBLIC_IP="13.58.12.224"

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Despliegue en EC2 - Stack Black Friday${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Verificar Namespace
info "Configurando Namespace: $NAMESPACE"
sudo kubectl create namespace $NAMESPACE --dry-run=client -o yaml | sudo kubectl apply -f -

# 2. Limpieza (Opcional: borrar pods previos para asegurar reinicio fresco)
info "Limpiando pods existentes en el namespace..."
sudo kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force || true

# 3. Despliegue de Base de Datos y Mensajería (Infraestructura)
info "Desplegando infraestructura básica..."

# Nota: Asegúrate que tus archivos .yaml en k8s/ usen la IP de Zot para las imágenes
# O usa este comando sed para parchearlos masivamente si no lo has hecho:
# sed -i "s|image: |image: $ZOT_IP/|g" k8s/*.yaml

sudo kubectl apply -f k8s/01-zookeeper.yaml -n $NAMESPACE
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

# 5. Despliegue de Herramientas y Proxy
info "Desplegando Nginx, Locust y Grafana..."
sudo kubectl apply -f k8s/07-nginx-proxy.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/13-locust.yaml -n $NAMESPACE
sudo kubectl apply -f k8s/14-grafana.yaml -n $NAMESPACE

echo ""
info "Verificando estado de los servicios..."
sudo kubectl get pods -n $NAMESPACE

echo ""
success "========================================"
success "🚀 DESPLIEGUE EN EC2 FINALIZADO"
success "========================================"
echo -e "${YELLOW}Acceso Externo:${NC}"
echo "Grafana: http://$PUBLIC_IP:32000"
echo "Locust:  http://$PUBLIC_IP:30089"
echo "API Go:   http://$PUBLIC_IP:30080"
echo "Nginx:   http://$PUBLIC_IP:30081"
