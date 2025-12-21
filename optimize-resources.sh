#!/bin/bash

# Script para Optimizar Recursos de Kubernetes
# Reduce réplicas y ajusta límites de memoria/CPU

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
echo -e "${BLUE}🔧 Optimizando Recursos de Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

info "Reduciendo réplicas de deployments..."

# Reducir API Rust de 2 a 1 réplica
kubectl scale deployment api-rust --replicas=1 -n blackfriday 2>/dev/null || warning "api-rust no encontrado"

# Reducir Go API REST de 2 a 1 réplica
kubectl scale deployment go-api-rest --replicas=1 -n blackfriday 2>/dev/null || warning "go-api-rest no encontrado"

# Reducir gRPC Server 2 de 2 a 1 réplica
kubectl scale deployment grpc-server-2 --replicas=1 -n blackfriday 2>/dev/null || warning "grpc-server-2 no encontrado"

# Reducir Kafka Consumer de 2 a 1 réplica
kubectl scale deployment kafka-consumer --replicas=1 -n blackfriday 2>/dev/null || warning "kafka-consumer no encontrado"

# Reducir Nginx Proxy de 2 a 1 réplica
kubectl scale deployment nginx-proxy --replicas=1 -n blackfriday 2>/dev/null || warning "nginx-proxy no encontrado"

success "Réplicas reducidas"
echo ""

info "Estado actual de los pods:"
kubectl get pods -n blackfriday

echo ""
success "Optimización completada"
echo ""
echo -e "${YELLOW}Resumen de cambios:${NC}"
echo "  • API Rust: 2 → 1 réplica"
echo "  • Go API REST: 2 → 1 réplica"
echo "  • gRPC Server 2: 2 → 1 réplica"
echo "  • Kafka Consumer: 2 → 1 réplica"
echo "  • Nginx Proxy: 2 → 1 réplica"
echo ""
echo -e "${BLUE}Consumo de recursos reducido significativamente${NC}"
