#!/bin/bash

# Script para verificar tags de imágenes en Zot y corregir YAMLs
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

ZOT_IP="3.129.65.122:30000"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Verificador de Tags de Imágenes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Obtener catálogo de imágenes
info "Obteniendo catálogo de imágenes desde Zot..."
CATALOG=$(curl -s "http://$ZOT_IP/v2/_catalog")

if [ $? -ne 0 ]; then
    error "No se pudo conectar con Zot"
    exit 1
fi

echo "$CATALOG" | jq '.'
echo ""

# Función para obtener tags de una imagen
get_tags() {
    local image=$1
    curl -s "http://$ZOT_IP/v2/$image/tags/list" | jq -r '.tags[]?' 2>/dev/null || echo "latest"
}

# Verificar cada imagen en los YAMLs
info "Verificando imágenes en los YAMLs..."
echo ""

declare -A IMAGE_MAP

# Extraer imágenes únicas de los YAMLs
IMAGES=$(grep "image: $ZOT_IP" *.yaml | grep -v "^#" | awk '{print $2}' | sort -u)

for FULL_IMAGE in $IMAGES; do
    # Extraer nombre e imagen
    IMAGE_WITH_TAG="${FULL_IMAGE#$ZOT_IP/}"
    IMAGE_NAME="${IMAGE_WITH_TAG%%:*}"
    REQUESTED_TAG="${IMAGE_WITH_TAG##*:}"
    
    info "Verificando: $IMAGE_NAME:$REQUESTED_TAG"
    
    # Obtener tags disponibles
    AVAILABLE_TAGS=$(get_tags "$IMAGE_NAME")
    
    if [ -z "$AVAILABLE_TAGS" ]; then
        warning "  No se encontraron tags para $IMAGE_NAME"
        continue
    fi
    
    echo "  Tags disponibles: $AVAILABLE_TAGS"
    
    # Verificar si el tag solicitado existe
    if echo "$AVAILABLE_TAGS" | grep -q "^${REQUESTED_TAG}$"; then
        success "  ✓ Tag '$REQUESTED_TAG' existe"
    else
        warning "  ✗ Tag '$REQUESTED_TAG' NO existe"
        
        # Sugerir tag alternativo
        if echo "$AVAILABLE_TAGS" | grep -q "^latest$"; then
            warning "  Sugerencia: usar 'latest'"
            IMAGE_MAP["$IMAGE_WITH_TAG"]="$IMAGE_NAME:latest"
        else
            FIRST_TAG=$(echo "$AVAILABLE_TAGS" | head -1)
            warning "  Sugerencia: usar '$FIRST_TAG'"
            IMAGE_MAP["$IMAGE_WITH_TAG"]="$IMAGE_NAME:$FIRST_TAG"
        fi
    fi
    echo ""
done

# Si hay correcciones sugeridas
if [ ${#IMAGE_MAP[@]} -gt 0 ]; then
    echo ""
    warning "========================================="
    warning "Correcciones Sugeridas"
    warning "========================================="
    echo ""
    
    for old_tag in "${!IMAGE_MAP[@]}"; do
        new_tag="${IMAGE_MAP[$old_tag]}"
        echo "  $old_tag → $new_tag"
    done
    
    echo ""
    read -p "¿Deseas aplicar estas correcciones automáticamente? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Aplicando correcciones..."
        
        for old_tag in "${!IMAGE_MAP[@]}"; do
            new_tag="${IMAGE_MAP[$old_tag]}"
            OLD_FULL="$ZOT_IP/$old_tag"
            NEW_FULL="$ZOT_IP/$new_tag"
            
            # Buscar archivos que contengan la imagen vieja
            FILES=$(grep -l "$OLD_FULL" *.yaml)
            
            for file in $FILES; do
                info "  Actualizando $file"
                sed -i "s|$OLD_FULL|$NEW_FULL|g" "$file"
            done
        done
        
        success "✓ Correcciones aplicadas"
        echo ""
        warning "IMPORTANTE: Ahora debes eliminar los pods con error:"
        echo "  k3s kubectl delete pods -l app=nginx-proxy -n blackfriday"
    fi
else
    success "========================================="
    success "✅ Todos los tags son correctos"
    success "========================================="
fi

echo ""
info "Para ver los tags de una imagen específica:"
echo "  curl http://$ZOT_IP/v2/<image-name>/tags/list"
