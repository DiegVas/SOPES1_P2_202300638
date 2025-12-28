#!/bin/bash

# Script de instalación de K3s para EC2
set -e

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
echo -e "${BLUE}🚀 Instalación de K3s en EC2${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar si ya está instalado
if command -v k3s &> /dev/null; then
    warning "K3s ya está instalado"
    k3s --version
    echo ""
    read -p "¿Deseas reinstalar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Saliendo sin cambios"
        exit 0
    fi
    
    info "Desinstalando K3s anterior..."
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        sudo /usr/local/bin/k3s-uninstall.sh
    fi
fi

# Verificar sistema operativo
info "Verificando sistema operativo..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    success "✓ Sistema: $NAME $VERSION"
else
    warning "No se pudo detectar el sistema operativo"
fi

# Verificar conectividad a internet
info "Verificando conectividad a internet..."
if curl -s --connect-timeout 5 https://get.k3s.io > /dev/null; then
    success "✓ Conectividad OK"
else
    error "✗ No hay conexión a internet"
    error "Necesitas conexión para descargar K3s"
    exit 1
fi

echo ""
info "Instalando K3s..."
info "Esto puede tardar unos minutos..."
echo ""

# Instalar K3s
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb

if [ $? -ne 0 ]; then
    error "Error al instalar K3s"
    exit 1
fi

success "✓ K3s instalado correctamente"
echo ""

# Esperar a que K3s esté listo
info "Esperando a que K3s esté listo..."
sleep 10

# Verificar que K3s está corriendo
if sudo systemctl is-active --quiet k3s; then
    success "✓ Servicio K3s está corriendo"
else
    warning "Iniciando servicio K3s..."
    sudo systemctl start k3s
    sleep 5
fi

# Habilitar K3s para que inicie con el sistema
sudo systemctl enable k3s
success "✓ K3s configurado para iniciar automáticamente"

# Configurar permisos del kubeconfig
info "Configurando permisos..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
success "✓ Permisos configurados"

# Verificar instalación
echo ""
info "Verificando instalación..."
echo ""

# Mostrar versión
info "Versión de K3s:"
k3s --version

echo ""

# Mostrar nodos
info "Nodos del cluster:"
k3s kubectl get nodes

echo ""

# Verificar pods del sistema
info "Pods del sistema:"
k3s kubectl get pods -n kube-system

echo ""
success "========================================"
success "✅ K3s instalado y funcionando"
success "========================================"
echo ""

echo -e "${YELLOW}📝 Información importante:${NC}"
echo ""
echo "1. Comando kubectl: k3s kubectl"
echo "   Ejemplo: k3s kubectl get pods"
echo ""
echo "2. Configuración: /etc/rancher/k3s/k3s.yaml"
echo ""
echo "3. Para usar kubectl directamente (opcional):"
echo "   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "   echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc"
echo ""
echo "4. Gestión del servicio:"
echo "   sudo systemctl status k3s"
echo "   sudo systemctl restart k3s"
echo "   sudo journalctl -u k3s -f"
echo ""

echo -e "${GREEN}🎯 Siguientes pasos:${NC}"
echo ""
echo "1. Configurar registro inseguro:"
echo "   sudo ./configure-insecure-registry.sh"
echo ""
echo "2. Desplegar la aplicación:"
echo "   ./deploy-ec2.sh"
echo ""
