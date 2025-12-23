#!/bin/bash
set -e

echo "🚀 Configurando Zot Registry en Minikube"

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

echo -e "${BLUE}📍 IP de Minikube: ${MINIKUBE_IP}${NC}"
echo -e "${BLUE}📦 Zot Registry: ${ZOT_REGISTRY}${NC}"

# Paso 1: Desplegar Zot Registry
echo -e "\n${YELLOW}📦 Desplegando Zot Registry...${NC}"
kubectl apply -f k8s/00-zot-registry.yaml

# Esperar a que Zot esté listo
echo -e "${YELLOW}⏳ Esperando a que Zot Registry esté listo...${NC}"
sleep 10
kubectl wait --for=condition=ready pod -l app=zot-registry -n blackfriday --timeout=120s

# Verificar que Zot está funcionando
echo -e "\n${YELLOW}✅ Verificando Zot Registry...${NC}"
sleep 5

# Probar conexión a Zot
if curl -s "http://${ZOT_REGISTRY}/v2/" > /dev/null; then
    echo -e "${GREEN}✅ Zot Registry está funcionando correctamente!${NC}"
else
    echo -e "${RED}❌ Error: Zot Registry no responde${NC}"
    exit 1
fi

# Paso 2: Configurar registry inseguro y Docker
echo -e "\n${YELLOW}🔧 Configurando registry inseguro en Minikube...${NC}"

# Reiniciar Minikube con registry inseguro
minikube stop
minikube start --insecure-registry="${MINIKUBE_IP}:30500"

# Obtener nueva IP (puede cambiar después del reinicio)
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

echo -e "${GREEN}✅ Registry inseguro configurado${NC}"
echo -e "${BLUE}📍 Nueva IP de Minikube: ${MINIKUBE_IP}${NC}"

# Paso 3: Configurar entorno Docker para usar minikube
echo -e "\n${YELLOW}🐳 Configurando entorno Docker...${NC}"
eval $(minikube docker-env)

# Verificar conexión a Docker
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: No se puede conectar al daemon de Docker de Minikube${NC}"
    echo -e "${YELLOW}💡 Intentando reconectar...${NC}"
    eval $(minikube docker-env --unset)
    sleep 2
    eval $(minikube docker-env)
    
    if ! docker ps > /dev/null 2>&1; then
        echo -e "${RED}❌ Error: Aún no se puede conectar. Reiniciando Minikube...${NC}"
        minikube stop
        minikube start
        eval $(minikube docker-env)
    fi
fi

echo -e "${GREEN}✅ Conectado al Docker daemon de Minikube${NC}"

# Paso 3: Construir y tagear imágenes para Zot
echo -e "\n${YELLOW}🏗️  Construyendo y etiquetando imágenes...${NC}"

# API Rust
echo -e "${BLUE}Construyendo rust-api...${NC}"
docker build -t rust-api:latest -f api/Dockerfile .
docker tag rust-api:latest ${ZOT_REGISTRY}/rust-api:latest

# Go API REST
echo -e "${BLUE}Construyendo go-api-rest...${NC}"
docker build -t go-api-rest:latest -f go-api-rest/Dockerfile.simple go-api-rest/
docker tag go-api-rest:latest ${ZOT_REGISTRY}/go-api-rest:latest

# gRPC Server
echo -e "${BLUE}Construyendo grpc-server...${NC}"
docker build -t grpc-server:latest -f grpc-server/Dockerfile.simple grpc-server/
docker tag grpc-server:latest ${ZOT_REGISTRY}/grpc-server:latest

# Kafka Consumer
echo -e "${BLUE}Construyendo kafka-consumer...${NC}"
docker build -t kafka-consumer:latest ./kafka-consumer/
docker tag kafka-consumer:latest ${ZOT_REGISTRY}/kafka-consumer:latest

# Locust
echo -e "${BLUE}Construyendo locust...${NC}"
docker build -t locust:latest ./locust/
docker tag locust:latest ${ZOT_REGISTRY}/locust:latest

# Nginx
echo -e "${BLUE}Construyendo nginx-proxy...${NC}"
docker build -t nginx-proxy:latest ./nginx/
docker tag nginx-proxy:latest ${ZOT_REGISTRY}/nginx-proxy:latest

# Paso 4: Pushear imágenes a Zot Registry
echo -e "\n${YELLOW}📤 Pusheando imágenes a Zot Registry...${NC}"

docker push ${ZOT_REGISTRY}/rust-api:latest
docker push ${ZOT_REGISTRY}/go-api-rest:latest
docker push ${ZOT_REGISTRY}/grpc-server:latest
docker push ${ZOT_REGISTRY}/kafka-consumer:latest
docker push ${ZOT_REGISTRY}/locust:latest
docker push ${ZOT_REGISTRY}/nginx-proxy:latest

# Verificar imágenes en Zot
echo -e "\n${YELLOW}📋 Listando imágenes en Zot Registry...${NC}"
curl -s "http://${ZOT_REGISTRY}/v2/_catalog" | jq '.'

# Mostrar información
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✅ Zot Registry configurado exitosamente!${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${BLUE}Registry URL: http://${ZOT_REGISTRY}${NC}"
echo -e "${BLUE}Catalog API:  http://${ZOT_REGISTRY}/v2/_catalog${NC}"
echo -e "${BLUE}Health API:   http://${ZOT_REGISTRY}/v2/${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}💡 Para actualizar los deployments y usar Zot Registry:${NC}"
echo -e "   ./update-deployments-zot.sh"
echo ""
echo -e "${YELLOW}💡 Para verificar una imagen específica:${NC}"
echo -e "   curl http://${ZOT_REGISTRY}/v2/rust-api/tags/list"
echo ""
