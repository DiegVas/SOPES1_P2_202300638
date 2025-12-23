#!/bin/bash
set -e

# Configuración
REMOTE_ZOT="18.222.2.22:5000"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Pusheando todas las imágenes a Zot remoto: ${REMOTE_ZOT}${NC}\n"

# Salir del entorno de Minikube
eval $(minikube docker-env --unset) 2>/dev/null || true

# Imágenes propias (construir localmente)
LOCAL_IMAGES=(
    "rust-api:latest"
    "go-api-rest:latest"
    "grpc-server:latest"
    "kafka-consumer:latest"
    "locust:latest"
)

# Imágenes públicas (pull y push)
PUBLIC_IMAGES=(
    "grafana/grafana:latest"
    "confluentinc/cp-kafka:7.5.0"
    "confluentinc/cp-zookeeper:latest"
    "valkey/valkey:latest"
    "nginx:alpine"
)

echo -e "${YELLOW}📦 Paso 1: Construyendo imágenes locales...${NC}\n"

# Construir rust-api
echo -e "${BLUE}Construyendo rust-api...${NC}"
docker build -f api/Dockerfile -t rust-api:latest .
docker tag rust-api:latest ${REMOTE_ZOT}/rust-api:latest

# Construir go-api-rest
echo -e "${BLUE}Construyendo go-api-rest...${NC}"
docker build -f go-api-rest/Dockerfile -t go-api-rest:latest .
docker tag go-api-rest:latest ${REMOTE_ZOT}/go-api-rest:latest

# Construir grpc-server
echo -e "${BLUE}Construyendo grpc-server...${NC}"
docker build -f grpc-server/Dockerfile -t grpc-server:latest .
docker tag grpc-server:latest ${REMOTE_ZOT}/grpc-server:latest

# Construir kafka-consumer
echo -e "${BLUE}Construyendo kafka-consumer...${NC}"
docker build -t kafka-consumer:latest kafka-consumer/
docker tag kafka-consumer:latest ${REMOTE_ZOT}/kafka-consumer:latest

# Construir locust
echo -e "${BLUE}Construyendo locust...${NC}"
docker build -t locust:latest locust/
docker tag locust:latest ${REMOTE_ZOT}/locust:latest

echo -e "\n${GREEN}✅ Imágenes locales construidas${NC}\n"

echo -e "${YELLOW}📥 Paso 2: Descargando y etiquetando imágenes públicas (AMD64)...${NC}\n"

# Grafana
echo -e "${BLUE}Procesando grafana/grafana:latest...${NC}"
docker pull --platform linux/amd64 grafana/grafana:latest
docker tag grafana/grafana:latest ${REMOTE_ZOT}/grafana:latest

# Kafka
echo -e "${BLUE}Procesando confluentinc/cp-kafka:7.5.0...${NC}"
docker pull --platform linux/amd64 confluentinc/cp-kafka:7.5.0
docker tag confluentinc/cp-kafka:7.5.0 ${REMOTE_ZOT}/cp-kafka:7.5.0

# Zookeeper
echo -e "${BLUE}Procesando confluentinc/cp-zookeeper:latest...${NC}"
docker pull --platform linux/amd64 confluentinc/cp-zookeeper:latest
docker tag confluentinc/cp-zookeeper:latest ${REMOTE_ZOT}/cp-zookeeper:latest

# Valkey
echo -e "${BLUE}Procesando valkey/valkey:latest...${NC}"
docker pull --platform linux/amd64 valkey/valkey:latest
docker tag valkey/valkey:latest ${REMOTE_ZOT}/valkey:latest

# Nginx
echo -e "${BLUE}Procesando nginx:alpine...${NC}"
docker pull --platform linux/amd64 nginx:alpine
docker tag nginx:alpine ${REMOTE_ZOT}/nginx:alpine

echo -e "\n${GREEN}✅ Imágenes públicas descargadas y etiquetadas${NC}\n"

echo -e "${YELLOW}📤 Paso 3: Pusheando todas las imágenes a Zot remoto...${NC}\n"

# Pushear todas las imágenes
IMAGES_TO_PUSH=(
    "${REMOTE_ZOT}/rust-api:latest"
    "${REMOTE_ZOT}/go-api-rest:latest"
    "${REMOTE_ZOT}/grpc-server:latest"
    "${REMOTE_ZOT}/kafka-consumer:latest"
    "${REMOTE_ZOT}/locust:latest"
    "${REMOTE_ZOT}/grafana:latest"
    "${REMOTE_ZOT}/cp-kafka:7.5.0"
    "${REMOTE_ZOT}/cp-zookeeper:latest"
    "${REMOTE_ZOT}/valkey:latest"
    "${REMOTE_ZOT}/nginx:alpine"
)

for IMAGE in "${IMAGES_TO_PUSH[@]}"; do
    echo -e "${BLUE}📤 Pusheando ${IMAGE}...${NC}"
    if docker push ${IMAGE}; then
        echo -e "${GREEN}   ✅ ${IMAGE} pusheada exitosamente${NC}"
    else
        echo -e "${RED}   ❌ Error pusheando ${IMAGE}${NC}"
    fi
    echo ""
done

echo -e "\n${GREEN}🎉 Proceso completado!${NC}\n"

echo -e "${BLUE}📋 Verificando catálogo en Zot remoto:${NC}"
curl -s http://${REMOTE_ZOT}/v2/_catalog | jq -r '.repositories[]' | sort

echo -e "\n${YELLOW}💡 Siguiente paso: Actualizar los deployments de Kubernetes para usar ${REMOTE_ZOT}${NC}"
