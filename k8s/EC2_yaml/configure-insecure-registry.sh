#!/bin/bash

# Script para configurar registro inseguro en Docker
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ZOT_IP="3.129.65.122:30000"

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔧 Configurando Registro Inseguro${NC}"
echo -e "${BLUE}========================================${NC}"

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    warning "Docker no está instalado. Instalando..."
    sudo apt-get update
    sudo apt-get install -y docker.io
fi

# Crear o actualizar la configuración de Docker daemon
info "Configurando Docker daemon para permitir registro inseguro..."

DAEMON_JSON="/etc/docker/daemon.json"

# Backup del archivo existente si existe
if [ -f "$DAEMON_JSON" ]; then
    sudo cp "$DAEMON_JSON" "${DAEMON_JSON}.backup"
    info "Backup creado en ${DAEMON_JSON}.backup"
fi

# Crear nueva configuración
sudo tee "$DAEMON_JSON" > /dev/null <<EOF
{
  "insecure-registries": ["$ZOT_IP"],
  "registry-mirrors": [],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

success "Configuración de Docker actualizada"

# Reiniciar Docker
info "Reiniciando Docker daemon..."
sudo systemctl restart docker
sleep 5

# Verificar que Docker está funcionando
if sudo systemctl is-active --quiet docker; then
    success "Docker daemon reiniciado correctamente"
else
    error "Error al reiniciar Docker daemon"
    exit 1
fi

# Si estamos usando containerd (K3s o similar), también configurarlo
if command -v k3s &> /dev/null; then
    info "Detectado K3s, configurando containerd..."
    
    CONTAINERD_CONFIG="/etc/rancher/k3s/registries.yaml"
    sudo mkdir -p /etc/rancher/k3s
    
    sudo tee "$CONTAINERD_CONFIG" > /dev/null <<EOF
mirrors:
  "$ZOT_IP":
    endpoint:
      - "http://$ZOT_IP"
configs:
  "$ZOT_IP":
    tls:
      insecure_skip_verify: true
EOF
    
    success "Configuración de containerd actualizada"
    
    info "Reiniciando K3s (esto puede tardar ~30 segundos)..."
    sudo systemctl restart k3s
    
    # Esperar a que K3s esté listo
    info "Esperando a que K3s esté completamente listo..."
    sleep 15
    
    # Verificar que K3s está corriendo
    RETRY=0
    MAX_RETRY=10
    while [ $RETRY -lt $MAX_RETRY ]; do
        if sudo systemctl is-active --quiet k3s && k3s kubectl get nodes &>/dev/null; then
            success "✓ K3s está listo"
            break
        fi
        echo -ne "\r⏳ Esperando K3s... $((RETRY * 3))s"
        sleep 3
        RETRY=$((RETRY + 1))
    done
    echo ""
    
    if [ $RETRY -eq $MAX_RETRY ]; then
        error "K3s tardó demasiado en iniciarse"
        echo "Verifica los logs: sudo journalctl -xeu k3s -f"
    fi
fi

# Verificar conectividad con el registro
info "Verificando conectividad con el registro..."
if curl -s --connect-timeout 5 "http://$ZOT_IP/v2/" > /dev/null; then
    success "✓ Registro accesible en $ZOT_IP"
else
    warning "⚠️  No se puede conectar con el registro en $ZOT_IP"
    warning "Asegúrate de que el registro Zot esté funcionando"
fi

echo ""
success "========================================"
success "✅ Configuración completada"
success "========================================"
echo ""
info "Puedes verificar la configuración con:"
echo "  cat /etc/rancher/k3s/registries.yaml"
echo "  docker info | grep -A5 'Insecure Registries'"
echo ""
info "Para probar el registro con K3s:"
echo "  k3s crictl pull $ZOT_IP/nginx:alpine"
echo ""
info "Para probar el registro con Docker:"
echo "  docker pull $ZOT_IP/nginx:alpine"
echo ""
warning "IMPORTANTE: Los pods existentes no verán los cambios."
warning "Para aplicar la configuración a pods existentes:"
echo "  k3s kubectl delete pods --all -n blackfriday"
echo ""
