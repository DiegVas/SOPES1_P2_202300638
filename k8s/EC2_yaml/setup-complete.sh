#!/bin/bash

# Script maestro de despliegue completo
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
echo -e "${BLUE}🚀 Setup Completo - Black Friday${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Paso 1: Verificar Kubernetes
info "Paso 1/3: Verificando Kubernetes..."
echo ""

if command -v k3s &> /dev/null || command -v kubectl &> /dev/null || command -v microk8s &> /dev/null; then
    success "✓ Kubernetes encontrado"
    
    # Ejecutar diagnóstico
    if ./check-kubernetes.sh; then
        success "✓ Kubernetes funcionando correctamente"
    else
        error "✗ Kubernetes tiene problemas"
        echo ""
        read -p "¿Deseas intentar reinstalar K3s? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./install-k3s.sh
        else
            exit 1
        fi
    fi
else
    warning "Kubernetes no está instalado"
    echo ""
    read -p "¿Deseas instalar K3s ahora? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ./install-k3s.sh
    else
        error "No se puede continuar sin Kubernetes"
        exit 1
    fi
fi

echo ""
echo ""

# Paso 2: Configurar registro inseguro
info "Paso 2/3: Configurando registro inseguro..."
echo ""

# Verificar si ya está configurado
CONFIGURED=false

if [ -f "/etc/docker/daemon.json" ] && grep -q "3.129.65.122:30000" /etc/docker/daemon.json 2>/dev/null; then
    CONFIGURED=true
fi

if [ -f "/etc/rancher/k3s/registries.yaml" ] && grep -q "3.129.65.122:30000" /etc/rancher/k3s/registries.yaml 2>/dev/null; then
    CONFIGURED=true
fi

if [ "$CONFIGURED" = true ]; then
    success "✓ Registro inseguro ya está configurado"
    echo ""
    read -p "¿Deseas reconfigurar? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ./configure-insecure-registry.sh
    fi
else
    warning "Registro inseguro NO está configurado"
    echo ""
    echo "Esto es necesario para descargar imágenes del Zot registry"
    echo ""
    read -p "¿Configurar ahora? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo ./configure-insecure-registry.sh
    else
        error "No se puede continuar sin configurar el registro"
        exit 1
    fi
fi

echo ""
echo ""

# Paso 3: Desplegar aplicación
info "Paso 3/3: Desplegando aplicación..."
echo ""

read -p "¿Deseas desplegar la aplicación ahora? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    ./deploy-ec2.sh
else
    info "Puedes desplegar manualmente más tarde con:"
    echo "  ./deploy-ec2.sh"
fi

echo ""
success "========================================"
success "✅ Setup completado"
success "========================================"
