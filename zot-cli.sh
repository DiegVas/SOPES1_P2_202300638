#!/bin/bash

# Script para gestionar imágenes en Zot Registry local

MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function show_help() {
    echo -e "${BLUE}=== Gestión de Zot Registry Local ===${NC}"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  list          - Listar todas las imágenes en el registry"
    echo "  tags <image>  - Mostrar tags de una imagen específica"
    echo "  health        - Verificar salud del registry"
    echo "  catalog       - Ver catálogo completo (JSON)"
    echo "  help          - Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 list"
    echo "  $0 tags rust-api"
    echo "  $0 health"
    echo ""
}

function check_zot() {
    if ! curl -s "http://${ZOT_REGISTRY}/v2/" > /dev/null; then
        echo -e "${RED}❌ Error: Zot Registry no está disponible${NC}"
        echo -e "${YELLOW}Verifica que Zot esté desplegado: kubectl get pods -n blackfriday -l app=zot-registry${NC}"
        exit 1
    fi
}

function list_images() {
    echo -e "${BLUE}📋 Imágenes en Zot Registry (${ZOT_REGISTRY}):${NC}"
    echo ""
    
    catalog=$(curl -s "http://${ZOT_REGISTRY}/v2/_catalog")
    
    if [ -z "$catalog" ]; then
        echo -e "${YELLOW}No hay imágenes en el registry${NC}"
        return
    fi
    
    images=$(echo "$catalog" | jq -r '.repositories[]?' 2>/dev/null)
    
    if [ -z "$images" ]; then
        echo -e "${YELLOW}No hay imágenes en el registry${NC}"
        return
    fi
    
    while IFS= read -r image; do
        tags=$(curl -s "http://${ZOT_REGISTRY}/v2/${image}/tags/list" | jq -r '.tags[]?' 2>/dev/null)
        echo -e "${GREEN}📦 ${image}${NC}"
        if [ -z "$tags" ]; then
            echo -e "   ${YELLOW}(sin tags)${NC}"
        else
            while IFS= read -r tag; do
                echo -e "   └─ ${tag}"
            done <<< "$tags"
        fi
        echo ""
    done <<< "$images"
}

function show_tags() {
    local image=$1
    
    if [ -z "$image" ]; then
        echo -e "${RED}❌ Error: Debes especificar el nombre de la imagen${NC}"
        echo "Uso: $0 tags <image>"
        exit 1
    fi
    
    echo -e "${BLUE}Tags para ${image}:${NC}"
    echo ""
    
    result=$(curl -s "http://${ZOT_REGISTRY}/v2/${image}/tags/list")
    
    if echo "$result" | jq -e '.errors' > /dev/null 2>&1; then
        echo -e "${RED}❌ Imagen '${image}' no encontrada${NC}"
        exit 1
    fi
    
    tags=$(echo "$result" | jq -r '.tags[]?' 2>/dev/null)
    
    if [ -z "$tags" ]; then
        echo -e "${YELLOW}No hay tags para esta imagen${NC}"
    else
        while IFS= read -r tag; do
            echo -e "${GREEN}  • ${tag}${NC}"
        done <<< "$tags"
    fi
}

function check_health() {
    echo -e "${BLUE}🏥 Verificando salud de Zot Registry...${NC}"
    echo ""
    
    echo -e "${YELLOW}Registry URL: ${ZOT_REGISTRY}${NC}"
    
    # Verificar pod
    echo -e "\n${BLUE}Pod Status:${NC}"
    kubectl get pods -n blackfriday -l app=zot-registry
    
    # Verificar servicio
    echo -e "\n${BLUE}Service Status:${NC}"
    kubectl get svc -n blackfriday zot-service
    
    # Verificar conectividad
    echo -e "\n${BLUE}Conectividad:${NC}"
    if curl -s "http://${ZOT_REGISTRY}/v2/" > /dev/null; then
        echo -e "${GREEN}✅ Zot Registry está accesible${NC}"
    else
        echo -e "${RED}❌ No se puede conectar a Zot Registry${NC}"
    fi
}

function show_catalog() {
    echo -e "${BLUE}📋 Catálogo completo:${NC}"
    echo ""
    curl -s "http://${ZOT_REGISTRY}/v2/_catalog" | jq '.'
}

# Main
case "${1:-list}" in
    list)
        check_zot
        list_images
        ;;
    tags)
        check_zot
        show_tags "$2"
        ;;
    health)
        check_health
        ;;
    catalog)
        check_zot
        show_catalog
        ;;
    help)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando desconocido: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
