#!/bin/bash

# Script para mostrar IPs y URLs de todos los componentes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📍 IPs y URLs de Componentes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip 2>/dev/null)
if [ -z "$MINIKUBE_IP" ]; then
    echo -e "${RED}❌ Minikube no está corriendo${NC}"
    exit 1
fi

success "IP de Minikube: $MINIKUBE_IP"
echo ""

# Obtener servicios del namespace blackfriday
echo -e "${YELLOW}Servicios con NodePort (acceso externo):${NC}"
echo "=========================================="

kubectl get svc -n blackfriday -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORT:.spec.ports[*].port,NODEPORT:.spec.ports[*].nodePort 2>/dev/null

echo ""
echo -e "${YELLOW}URLs de Acceso (desde tu navegador):${NC}"
echo "=========================================="

# Nginx Proxy (API REST)
NGINX_PORT=$(kubectl get svc nginx-proxy-service -n blackfriday -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$NGINX_PORT" ]; then
    success "🌐 API REST (Nginx):  http://$MINIKUBE_IP:$NGINX_PORT"
    echo "   - Health:   curl http://$MINIKUBE_IP:$NGINX_PORT/health"
    echo "   - Productos: curl http://$MINIKUBE_IP:$NGINX_PORT/productos"
    echo "   - Comprar:  curl -X POST http://$MINIKUBE_IP:$NGINX_PORT/comprar"
fi

# Locust
LOCUST_PORT=$(kubectl get svc locust-service -n blackfriday -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$LOCUST_PORT" ]; then
    success "🦗 Locust:           http://$MINIKUBE_IP:$LOCUST_PORT"
fi

# Grafana
GRAFANA_PORT=$(kubectl get svc grafana-service -n blackfriday -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$GRAFANA_PORT" ]; then
    success "📊 Grafana:          http://$MINIKUBE_IP:$GRAFANA_PORT"
    echo "   - Usuario: admin"
    echo "   - Password: admin"
fi

echo ""
echo -e "${YELLOW}IPs Internas (ClusterIP - solo dentro de k8s):${NC}"
echo "=========================================="

# API Rust
API_RUST_IP=$(kubectl get svc api-rust-service -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$API_RUST_IP" ]; then
    info "API Rust:        $API_RUST_IP:3000"
fi

# Go API REST
GO_API_IP=$(kubectl get svc go-api-rest-service -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$GO_API_IP" ]; then
    info "Go API REST:     $GO_API_IP:8080"
fi

# gRPC Server 1
GRPC1_IP=$(kubectl get svc grpc-server-1 -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$GRPC1_IP" ]; then
    info "gRPC Server 1:   $GRPC1_IP:50051"
fi

# gRPC Server 2
GRPC2_IP=$(kubectl get svc grpc-server-2 -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$GRPC2_IP" ]; then
    info "gRPC Server 2:   $GRPC2_IP:50052"
fi

# Kafka
KAFKA_IP=$(kubectl get svc kafka-service -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$KAFKA_IP" ]; then
    info "Kafka:           $KAFKA_IP:9092"
fi

# Zookeeper
ZK_IP=$(kubectl get svc zookeeper-service -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$ZK_IP" ]; then
    info "Zookeeper:       $ZK_IP:2181"
fi

# Valkey
VALKEY_IP=$(kubectl get svc valkey-service -n blackfriday -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$VALKEY_IP" ]; then
    info "Valkey (Redis):  $VALKEY_IP:6379"
fi

echo ""
echo -e "${YELLOW}Pods y sus IPs:${NC}"
echo "=========================================="
kubectl get pods -n blackfriday -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName 2>/dev/null

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Tip: Guarda estas URLs para acceso rápido${NC}"
echo -e "${BLUE}========================================${NC}"
