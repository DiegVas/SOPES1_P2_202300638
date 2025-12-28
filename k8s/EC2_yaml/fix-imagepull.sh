#!/bin/bash

# Script de troubleshooting para ImagePullBackOff
set +e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

ZOT_IP="3.129.65.122:30000"
NAMESPACE="blackfriday"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Diagnóstico ImagePullBackOff${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detectar kubectl
if command -v k3s &> /dev/null; then
    KUBECTL="k3s kubectl"
elif command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
else
    error "kubectl no encontrado"
    exit 1
fi

# 1. Verificar pods con problemas
info "Buscando pods con ImagePullBackOff..."
FAILED_PODS=$($KUBECTL get pods -n $NAMESPACE -o json | grep -i "ImagePullBackOff\|ErrImagePull" || true)

if [ -n "$FAILED_PODS" ]; then
    error "Pods con problemas encontrados:"
    $KUBECTL get pods -n $NAMESPACE | grep -E "ImagePullBackOff|ErrImagePull|NAME"
    echo ""
else
    success "No hay pods con ImagePullBackOff"
    exit 0
fi

# Obtener el primer pod con error
POD_NAME=$($KUBECTL get pods -n $NAMESPACE -o json | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "ImagePullBackOff" or .status.containerStatuses[]?.state.waiting.reason == "ErrImagePull") | .metadata.name' | head -1)

if [ -z "$POD_NAME" ]; then
    warning "No se pudo obtener el nombre del pod con error"
else
    info "Analizando pod: $POD_NAME"
    echo ""
    
    # Ver eventos del pod
    info "Eventos del pod:"
    $KUBECTL describe pod $POD_NAME -n $NAMESPACE | grep -A 10 "Events:"
    echo ""
    
    # Ver la imagen que intenta descargar
    IMAGE=$($KUBECTL get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
    info "Imagen que intenta descargar: $IMAGE"
    echo ""
fi

# 2. Verificar conectividad con Zot
info "Verificando conectividad con Zot registry ($ZOT_IP)..."
if curl -s --connect-timeout 5 "http://$ZOT_IP/v2/" > /dev/null; then
    success "✓ Zot registry es accesible"
else
    error "✗ No se puede conectar con Zot registry"
    echo ""
    echo "Posibles causas:"
    echo "  1. El servidor Zot no está corriendo"
    echo "  2. Firewall bloqueando el puerto 30000"
    echo "  3. IP incorrecta"
    echo ""
    echo "Verifica en el servidor Zot:"
    echo "  ssh user@3.129.65.122"
    echo "  k3s kubectl get pods -A | grep zot"
    exit 1
fi
echo ""

# 3. Listar imágenes disponibles en Zot
info "Verificando imágenes disponibles en Zot..."
CATALOG=$(curl -s "http://$ZOT_IP/v2/_catalog" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$CATALOG" | jq '.' 2>/dev/null || echo "$CATALOG"
    echo ""
    
    # Verificar si nginx:alpine existe
    if echo "$CATALOG" | grep -q "nginx"; then
        success "✓ Imagen 'nginx' encontrada en Zot"
    else
        warning "⚠️  Imagen 'nginx' NO encontrada en Zot"
        echo "  Necesitas subir la imagen nginx al registro"
    fi
else
    error "✗ No se pudo obtener el catálogo de imágenes"
fi
echo ""

# 4. Verificar configuración de registro inseguro en K3s
info "Verificando configuración de registro inseguro en K3s..."
if [ -f "/etc/rancher/k3s/registries.yaml" ]; then
    if grep -q "$ZOT_IP" /etc/rancher/k3s/registries.yaml; then
        success "✓ Registro configurado en K3s"
        echo ""
        info "Contenido de /etc/rancher/k3s/registries.yaml:"
        sudo cat /etc/rancher/k3s/registries.yaml
    else
        error "✗ Registro NO configurado correctamente en K3s"
        echo ""
        echo "SOLUCIÓN: Ejecuta:"
        echo "  sudo ./configure-insecure-registry.sh"
    fi
else
    error "✗ Archivo /etc/rancher/k3s/registries.yaml NO existe"
    echo ""
    echo "SOLUCIÓN: Ejecuta:"
    echo "  sudo ./configure-insecure-registry.sh"
fi
echo ""

# 5. Verificar configuración de Docker (si existe)
if command -v docker &> /dev/null; then
    info "Verificando configuración de Docker..."
    if [ -f "/etc/docker/daemon.json" ]; then
        if grep -q "$ZOT_IP" /etc/docker/daemon.json; then
            success "✓ Registro configurado en Docker"
        else
            warning "⚠️  Registro NO configurado en Docker"
        fi
    else
        warning "⚠️  /etc/docker/daemon.json no existe"
    fi
    echo ""
fi

# 6. Probar descarga manual
info "Intentando descargar una imagen manualmente..."
if sudo k3s crictl pull "$ZOT_IP/nginx:alpine" 2>&1 | tee /tmp/crictl-pull.log; then
    success "✓ Descarga manual exitosa"
else
    error "✗ Error al descargar imagen"
    echo ""
    cat /tmp/crictl-pull.log
fi
echo ""

# 7. Verificar estado del servicio K3s
info "Verificando estado de K3s..."
if sudo systemctl is-active --quiet k3s; then
    success "✓ Servicio K3s está corriendo"
    
    # Verificar cuándo se reinició por última vez
    LAST_RESTART=$(sudo systemctl show k3s -p ActiveEnterTimestamp --value)
    info "Último reinicio: $LAST_RESTART"
else
    error "✗ Servicio K3s NO está corriendo"
    echo "  sudo systemctl start k3s"
fi
echo ""

# Resumen y soluciones
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}📋 Resumen y Soluciones${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

echo "Causas comunes de ImagePullBackOff:"
echo ""
echo "1. ❌ Registro inseguro NO configurado"
echo "   SOLUCIÓN:"
echo "     sudo ./configure-insecure-registry.sh"
echo "     sudo systemctl restart k3s"
echo ""
echo "2. ❌ La imagen NO existe en Zot"
echo "   SOLUCIÓN:"
echo "     Verificar en el servidor Zot que las imágenes están subidas"
echo "     curl http://$ZOT_IP/v2/_catalog"
echo ""
echo "3. ❌ K3s no se reinició después de configurar"
echo "   SOLUCIÓN:"
echo "     sudo systemctl restart k3s"
echo "     sleep 30"
echo "     ./deploy-ec2.sh"
echo ""
echo "4. ❌ Problemas de red/firewall"
echo "   SOLUCIÓN:"
echo "     Verificar conectividad: curl http://$ZOT_IP/v2/"
echo "     Verificar firewall en ambas instancias"
echo ""

echo -e "${GREEN}🔧 Comando de Solución Rápida:${NC}"
echo ""
echo "sudo ./configure-insecure-registry.sh && sudo systemctl restart k3s && sleep 30 && kubectl delete pods --all -n $NAMESPACE"
echo ""
