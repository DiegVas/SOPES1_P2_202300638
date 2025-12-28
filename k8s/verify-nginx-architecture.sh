#!/bin/bash

echo "=========================================="
echo "🔍 Verificación de Arquitectura Dos Capas"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

# 1. Verificar Ingress Controller
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  CAPA 1: NGINX Ingress Controller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

kubectl get namespace ingress-nginx &>/dev/null
check_status "Namespace ingress-nginx existe"

INGRESS_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | wc -l)
if [ "$INGRESS_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Ingress Controller: $INGRESS_PODS pod(s)"
    kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
else
    echo -e "${RED}✗${NC} Ingress Controller no encontrado"
fi

echo ""
echo "Estado del servicio:"
kubectl get svc -n ingress-nginx ingress-nginx-controller 2>/dev/null || echo -e "${RED}✗${NC} Servicio no encontrado"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  CAPA 2: NGINX Proxy (Interno)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

kubectl get deployment nginx-proxy -n blackfriday &>/dev/null
check_status "Deployment nginx-proxy existe"

PROXY_PODS=$(kubectl get pods -n blackfriday -l app=nginx-proxy --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$PROXY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} NGINX Proxy: $PROXY_PODS réplica(s) running"
    kubectl get pods -n blackfriday -l app=nginx-proxy
else
    echo -e "${RED}✗${NC} NGINX Proxy no está running"
fi

echo ""
echo "Estado del servicio:"
kubectl get svc nginx-proxy-service -n blackfriday 2>/dev/null || echo -e "${RED}✗${NC} Servicio no encontrado"

SERVICE_TYPE=$(kubectl get svc nginx-proxy-service -n blackfriday -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$SERVICE_TYPE" = "ClusterIP" ]; then
    echo -e "${GREEN}✓${NC} Service tipo: ClusterIP (correcto para arquitectura de dos capas)"
else
    echo -e "${YELLOW}⚠${NC}  Service tipo: $SERVICE_TYPE (debería ser ClusterIP)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Recursos de Ingress"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

kubectl get ingress -n blackfriday &>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Ingress resources encontrados:"
    kubectl get ingress -n blackfriday
else
    echo -e "${RED}✗${NC} No hay recursos de Ingress"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Backend Services (API Rust, Go API)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# API Rust
RUST_PODS=$(kubectl get pods -n blackfriday -l app=api-rust --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$RUST_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} API Rust: $RUST_PODS réplica(s)"
else
    echo -e "${RED}✗${NC} API Rust no está running"
fi

# Go API
GO_PODS=$(kubectl get pods -n blackfriday -l app=go-api-rest --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$GO_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Go API REST: $GO_PODS réplica(s)"
else
    echo -e "${RED}✗${NC} Go API REST no está running"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Test de Conectividad"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test NGINX Proxy health endpoint
echo "Probando health check del NGINX Proxy..."
kubectl run test-connectivity --rm -i --restart=Never --image=curlimages/curl -n blackfriday -- \
    curl -s -o /dev/null -w "%{http_code}" http://nginx-proxy-service/health 2>/dev/null | grep -q 200
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} NGINX Proxy /health responde correctamente"
else
    echo -e "${YELLOW}⚠${NC}  No se pudo verificar /health del NGINX Proxy"
fi

# Test API Rust directa
echo "Probando API Rust directa..."
kubectl run test-rust --rm -i --restart=Never --image=curlimages/curl -n blackfriday -- \
    curl -s -o /dev/null -w "%{http_code}" http://api-rust-service:3000/productos 2>/dev/null | grep -q 200
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} API Rust responde en /productos"
else
    echo -e "${YELLOW}⚠${NC}  No se pudo verificar API Rust"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Información de Acceso"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Obtener IP y puerto del Ingress
INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$EXTERNAL_IP" ]; then
    echo "🌐 Tipo: LoadBalancer"
    echo "   IP Externa: $EXTERNAL_IP"
    echo ""
    echo "   Acceso:"
    echo "   • http://blackfriday.local/"
    echo "   • http://blackfriday.local/api/go"
else
    echo "🌐 Tipo: NodePort"
    echo "   IP del Nodo: $NODE_IP"
    echo "   Puerto HTTP: $INGRESS_PORT"
    echo ""
    echo "   Acceso:"
    echo "   • http://$NODE_IP:$INGRESS_PORT/"
    echo "   • http://$NODE_IP:$INGRESS_PORT/api/go"
    echo ""
    echo "   Agregar a /etc/hosts:"
    echo "   $NODE_IP blackfriday.local"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  Flujo de Tráfico"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Cliente → Ingress Controller → NGINX Proxy → API Rust"
echo ""
echo "Rutas configuradas:"
echo "  /          → nginx-proxy-service → api-rust-service"
echo "  /api/go    → go-api-rest-service (directo)"
echo "  /grafana   → grafana-service (directo)"
echo "  /locust    → locust-service (directo)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen de Configuración"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Timeouts (ambas capas): 60s"
echo "Keep-alive connections: 100"
echo "Buffer size: 8k"
echo "Proxy buffering: activado"
echo "Body size máximo: 10MB"
echo ""
echo "Documentación completa: ARQUITECTURA-NGINX-DOS-CAPAS.md"

echo ""
echo "=========================================="
echo "✅ Verificación completada"
echo "=========================================="
