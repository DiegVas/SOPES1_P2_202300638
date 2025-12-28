#!/bin/bash

# Script de verificación rápida de Ingress en EC2

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Verificación de Ingress - EC2${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar Ingress Controller
echo -e "${YELLOW}1. NGINX Ingress Controller${NC}"
if sudo kubectl get namespace ingress-nginx &>/dev/null; then
    echo -e "${GREEN}✓${NC} Namespace ingress-nginx existe"
    
    CONTROLLER_PODS=$(sudo kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | wc -l)
    if [ "$CONTROLLER_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Ingress Controller running ($CONTROLLER_PODS pod)"
        sudo kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
    else
        echo -e "${RED}✗${NC} Ingress Controller NO encontrado"
    fi
    
    echo ""
    echo "Servicio del Ingress Controller:"
    sudo kubectl get svc -n ingress-nginx ingress-nginx-controller
else
    echo -e "${RED}✗${NC} Ingress Controller NO instalado"
fi

echo ""
echo -e "${YELLOW}2. Recursos de Ingress${NC}"
if sudo kubectl get ingress -n blackfriday &>/dev/null; then
    echo -e "${GREEN}✓${NC} Recursos de Ingress encontrados:"
    sudo kubectl get ingress -n blackfriday
else
    echo -e "${RED}✗${NC} No hay recursos de Ingress"
fi

echo ""
echo -e "${YELLOW}3. NGINX Proxy (Capa interna)${NC}"
PROXY_PODS=$(sudo kubectl get pods -n blackfriday -l app=nginx-proxy --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$PROXY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} NGINX Proxy running ($PROXY_PODS réplicas)"
else
    echo -e "${RED}✗${NC} NGINX Proxy NO está running"
fi

echo ""
echo -e "${YELLOW}4. API Rust${NC}"
RUST_PODS=$(sudo kubectl get pods -n blackfriday -l app=api-rust --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$RUST_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} API Rust running ($RUST_PODS réplicas)"
else
    echo -e "${RED}✗${NC} API Rust NO está running"
fi

echo ""
echo -e "${YELLOW}5. Información de Acceso${NC}"
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
echo -e "IP Pública: ${GREEN}$PUBLIC_IP${NC}"
echo ""
echo "Acceso a través de Ingress:"
echo "  • URL Base:    http://$PUBLIC_IP:30080/"
echo "  • API Rust:    http://$PUBLIC_IP:30080/"
echo "  • Go API:      http://$PUBLIC_IP:30080/api/go"
echo "  • Grafana:     http://$PUBLIC_IP:30080/grafana"
echo "  • Locust:      http://$PUBLIC_IP:30080/locust"

echo ""
echo -e "${YELLOW}6. Test de Conectividad${NC}"
echo "Probando Ingress Controller..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:30080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓${NC} Ingress responde (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗${NC} Ingress no responde"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Verificación completada${NC}"
echo -e "${BLUE}========================================${NC}"
