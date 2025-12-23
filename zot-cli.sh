#!/bin/bash

# Script para gestionar imágenes en Zot Registry

MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function show_help() {
    echo -e "${BLUE}=== Gestión de Zot Registry ===${NC}"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  list          - Listar todas las imágenes en el registry"
    echo "  tags <image>  - Mostrar tags de una imagen específica"
    echo "  push <image>  - Pushear una imagen al registry"
    echo "  pull <image>  - Pullear una imagen del registry"
    echo "  delete <img>  - Eliminar una imagen (requiere configuración adicional)"
    echo "  health        - Verificar salud del registry"
    echo "  catalog       - Ver catálogo completo (JSON)"
    echo "  help          - Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 list"
    echo "  $0 tags rust-api"
    echo "  $0 push rust-api:latest"
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
    
    if [ $? -eq 0 ]; then
        echo "$catalog" | jq -r '.repositories[]' | while read repo; do
            echo -e "${GREEN}📦 $repo${NC}"
            tags=$(curl -s "http://${ZOT_REGISTRY}/v2/${repo}/tags/list" | jq -r '.tags[]' 2>/dev/null)
            if [ ! -z "$tags" ]; then
                echo "$tags" | while read tag; do
                    echo -e "   ${YELLOW}→ $tag${NC}"
                done
            fi
            echo ""
        done
    else
        echo -e "${RED}Error obteniendo catálogo${NC}"
    fi
}

function show_tags() {
    local image=$1
    if [ -z "$image" ]; then
        echo -e "${RED}Error: Debe especificar una imagen${NC}"
        echo "Uso: $0 tags <nombre-imagen>"
        exit 1
    fi
    
    echo -e "${BLUE}🏷️  Tags para $image:${NC}"
    curl -s "http://${ZOT_REGISTRY}/v2/${image}/tags/list" | jq '.'
}

function push_image() {
    local image=$1
    if [ -z "$image" ]; then
        echo -e "${RED}Error: Debe especificar una imagen${NC}"
        echo "Uso: $0 push <imagen:tag>"
        exit 1
    fi
    
    echo -e "${YELLOW}📤 Pusheando $image a Zot Registry...${NC}"
    
    # Tagear imagen
    docker tag "$image" "${ZOT_REGISTRY}/$image"
    
    # Pushear
    docker push "${ZOT_REGISTRY}/$image"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Imagen pusheada exitosamente${NC}"
    else
        echo -e "${RED}❌ Error pusheando imagen${NC}"
        exit 1
    fi
}

function pull_image() {
    local image=$1
    if [ -z "$image" ]; then
        echo -e "${RED}Error: Debe especificar una imagen${NC}"
        echo "Uso: $0 pull <imagen:tag>"
        exit 1
    fi
    
    echo -e "${YELLOW}📥 Pulleando $image desde Zot Registry...${NC}"
    docker pull "${ZOT_REGISTRY}/$image"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Imagen pulleada exitosamente${NC}"
    else
        echo -e "${RED}❌ Error pulleando imagen${NC}"
        exit 1
    fi
}

function health_check() {
    echo -e "${BLUE}🏥 Verificando salud de Zot Registry...${NC}"
    echo ""
    
    response=$(curl -s -w "\n%{http_code}" "http://${ZOT_REGISTRY}/v2/")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    echo -e "URL: ${YELLOW}http://${ZOT_REGISTRY}/v2/${NC}"
    echo -e "HTTP Code: ${YELLOW}$http_code${NC}"
    
    if [ "$http_code" == "200" ]; then
        echo -e "Estado: ${GREEN}✅ Operacional${NC}"
    else
        echo -e "Estado: ${RED}❌ No disponible${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Pod Status:${NC}"
    kubectl get pods -n blackfriday -l app=zot-registry
    
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    kubectl get svc -n blackfriday zot-service
}

function show_catalog() {
    echo -e "${BLUE}📚 Catálogo completo:${NC}"
    curl -s "http://${ZOT_REGISTRY}/v2/_catalog" | jq '.'
}

# Main
case "${1:-help}" in
    list)
        check_zot
        list_images
        ;;
    tags)
        check_zot
        show_tags "$2"
        ;;
    push)
        check_zot
        push_image "$2"
        ;;
    pull)
        check_zot
        pull_image "$2"
        ;;
    health)
        health_check
        ;;
    catalog)
        check_zot
        show_catalog
        ;;
    help|*)
        show_help
        ;;
esac
