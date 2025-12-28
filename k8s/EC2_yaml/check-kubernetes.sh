#!/bin/bash

# Script de diagnóstico para Kubernetes
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Diagnóstico de Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detectar tipo de instalación
info "Detectando tipo de instalación de Kubernetes..."
KUBECTL_CMD=""
K8S_TYPE=""

if command -v kubectl &> /dev/null; then
    KUBECTL_CMD="kubectl"
    K8S_TYPE="kubectl/kubeadm"
    success "✓ kubectl encontrado"
elif command -v k3s &> /dev/null; then
    KUBECTL_CMD="k3s kubectl"
    K8S_TYPE="k3s"
    success "✓ K3s encontrado"
elif command -v microk8s &> /dev/null; then
    KUBECTL_CMD="microk8s kubectl"
    K8S_TYPE="microk8s"
    success "✓ MicroK8s encontrado"
else
    error "✗ No se encontró ninguna instalación de Kubernetes"
    echo ""
    echo -e "${YELLOW}Para instalar K3s (recomendado para EC2):${NC}"
    echo -e "${GREEN}  ./install-k3s.sh${NC}"
    echo ""
    echo "O manualmente:"
    echo "  curl -sfL https://get.k3s.io | sh -"
    echo ""
    echo "Para instalar kubectl/kubeadm (más complejo):"
    echo "  https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/"
    exit 1
fi

echo "  Tipo: $K8S_TYPE"
echo "  Comando: $KUBECTL_CMD"
echo ""

# Verificar servicio
info "Verificando estado del servicio..."
case $K8S_TYPE in
    "k3s")
        if sudo systemctl is-active --quiet k3s; then
            success "✓ Servicio k3s está corriendo"
        else
            error "✗ Servicio k3s NO está corriendo"
            echo ""
            echo "Para iniciar K3s:"
            echo "  sudo systemctl start k3s"
            echo "  sudo systemctl enable k3s"
            echo ""
            echo "Para ver logs:"
            echo "  sudo journalctl -xeu k3s -f"
            exit 1
        fi
        ;;
    "microk8s")
        if sudo systemctl is-active --quiet snap.microk8s.daemon-kubelite; then
            success "✓ Servicio microk8s está corriendo"
        else
            error "✗ Servicio microk8s NO está corriendo"
            echo ""
            echo "Para iniciar MicroK8s:"
            echo "  microk8s start"
            exit 1
        fi
        ;;
    *)
        if sudo systemctl is-active --quiet kubelet; then
            success "✓ Servicio kubelet está corriendo"
        else
            error "✗ Servicio kubelet NO está corriendo"
            echo ""
            echo "Para iniciar kubelet:"
            echo "  sudo systemctl start kubelet"
            echo "  sudo systemctl enable kubelet"
            echo ""
            echo "Para ver logs:"
            echo "  sudo journalctl -xeu kubelet -f"
            exit 1
        fi
        ;;
esac
echo ""

# Verificar cluster info
info "Verificando cluster info..."
if $KUBECTL_CMD cluster-info &> /dev/null; then
    success "✓ Cluster responde correctamente"
    $KUBECTL_CMD cluster-info
else
    error "✗ Cluster NO responde"
    echo ""
    echo "Posibles causas:"
    echo "  1. El API server no está corriendo"
    echo "  2. Problemas con el archivo kubeconfig"
    echo "  3. Problemas de red o firewall"
    echo ""
    echo "Para K3s, verifica el archivo de configuración:"
    echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    echo "  sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
    exit 1
fi
echo ""

# Verificar nodos
info "Verificando nodos..."
if $KUBECTL_CMD get nodes &> /dev/null; then
    $KUBECTL_CMD get nodes
    echo ""
    NODE_STATUS=$($KUBECTL_CMD get nodes --no-headers | awk '{print $2}')
    if [ "$NODE_STATUS" == "Ready" ]; then
        success "✓ Nodo está listo"
    else
        warning "⚠️  Nodo no está en estado Ready"
    fi
else
    error "✗ No se pueden obtener los nodos"
fi
echo ""

# Verificar namespaces
info "Verificando namespaces..."
if $KUBECTL_CMD get namespaces &> /dev/null; then
    success "✓ Namespaces accesibles"
    $KUBECTL_CMD get namespaces | grep -E "NAME|kube-system|blackfriday"
else
    error "✗ No se pueden obtener los namespaces"
fi
echo ""

# Verificar pods del sistema
info "Verificando pods del sistema..."
SYSTEM_PODS=$($KUBECTL_CMD get pods -n kube-system --no-headers 2>/dev/null | wc -l)
if [ "$SYSTEM_PODS" -gt 0 ]; then
    success "✓ $SYSTEM_PODS pods del sistema corriendo"
    $KUBECTL_CMD get pods -n kube-system
else
    warning "⚠️  No hay pods del sistema corriendo"
fi
echo ""

# Verificar permisos
info "Verificando permisos..."
if $KUBECTL_CMD auth can-i create deployments --all-namespaces &> /dev/null; then
    success "✓ Tienes permisos suficientes"
else
    warning "⚠️  Permisos limitados, puede que necesites usar sudo"
    if sudo $KUBECTL_CMD auth can-i create deployments --all-namespaces &> /dev/null; then
        success "✓ Con sudo tienes permisos suficientes"
    fi
fi
echo ""

# Verificar configuración de Docker/containerd
info "Verificando configuración de registro inseguro..."
if [ -f "/etc/docker/daemon.json" ]; then
    if grep -q "3.129.65.122:30000" /etc/docker/daemon.json; then
        success "✓ Registro inseguro configurado en Docker"
    else
        warning "⚠️  Registro inseguro NO configurado en Docker"
        echo "  Ejecuta: ./configure-insecure-registry.sh"
    fi
else
    warning "⚠️  /etc/docker/daemon.json no existe"
fi

if [ "$K8S_TYPE" == "k3s" ]; then
    if [ -f "/etc/rancher/k3s/registries.yaml" ]; then
        if grep -q "3.129.65.122:30000" /etc/rancher/k3s/registries.yaml; then
            success "✓ Registro inseguro configurado en K3s"
        else
            warning "⚠️  Registro inseguro NO configurado en K3s"
            echo "  Ejecuta: ./configure-insecure-registry.sh"
        fi
    else
        warning "⚠️  /etc/rancher/k3s/registries.yaml no existe"
        echo "  Ejecuta: ./configure-insecure-registry.sh"
    fi
fi
echo ""

# Resumen
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}📊 Resumen${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Tipo de Kubernetes: $K8S_TYPE"
echo "Comando kubectl: $KUBECTL_CMD"
echo ""

if $KUBECTL_CMD cluster-info &> /dev/null; then
    success "✅ Sistema listo para despliegue"
    echo ""
    echo "Siguiente paso:"
    echo "  ./deploy-ec2.sh"
else
    error "❌ Sistema NO listo para despliegue"
    echo ""
    echo "Revisa los errores anteriores y corrígelos primero"
fi
