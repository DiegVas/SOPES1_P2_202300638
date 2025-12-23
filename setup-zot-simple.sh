#!/bin/bash
set -e

echo "🚀 Setup Simplificado de Zot Registry"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar que Zot esté desplegado
echo -e "${YELLOW}1. Verificando Zot Registry...${NC}"
if ! kubectl get deployment zot-registry -n blackfriday > /dev/null 2>&1; then
    echo -e "${BLUE}Desplegando Zot Registry...${NC}"
    kubectl apply -f k8s/00-zot-registry.yaml
    sleep 10
    kubectl wait --for=condition=ready pod -l app=zot-registry -n blackfriday --timeout=120s
fi

echo -e "${GREEN}✅ Zot Registry está corriendo${NC}"

# Configurar Docker
echo -e "\n${YELLOW}2. Configurando Docker...${NC}"
eval $(minikube docker-env)

# Usar las imágenes ya construidas o construir nuevas
echo -e "\n${YELLOW}3. Las imágenes ya están construidas en el Docker de Minikube${NC}"
echo -e "${BLUE}Imágenes disponibles:${NC}"
docker images | grep -E "rust-api|go-api-rest|grpc-server|kafka-consumer|locust|nginx-proxy" | grep latest

echo -e "\n${YELLOW}4. Para pushear imágenes a Zot, las imágenes ya están disponibles${NC}"
echo -e "${YELLOW}   dentro del cluster de Kubernetes (mismo Docker daemon)${NC}"
echo -e "\n${GREEN}✅ Setup completado!${NC}"
echo -e "\n${BLUE}💡 Las imágenes ya están disponibles para los pods porque:${NC}"
echo -e "   - Minikube usa un Docker daemon compartido"
echo -e "   - Los pods pueden acceder a las imágenes locales directamente"
echo -e "   - No es necesario pushear a un registry externo"
echo -e "\n${BLUE}💡 Para usar Zot como registry real (opcional):${NC}"
echo -e "   - Requiere configurar insecure-registry en Minikube"
echo -e "   - O usar certificados TLS"
echo -e "\n${YELLOW}📝 Para deployments, usa imagePullPolicy: Never o IfNotPresent${NC}"

