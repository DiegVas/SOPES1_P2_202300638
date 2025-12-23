#!/bin/bash
set -e

REMOTE_ZOT="18.222.2.22:5000"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Reparando imágenes multi-plataforma en Zot${NC}\n"

# Limpiar imágenes locales problemáticas
echo -e "${YELLOW}🧹 Limpiando imágenes locales...${NC}"
docker rmi grafana/grafana:latest 2>/dev/null || true
docker rmi confluentinc/cp-kafka:7.5.0 2>/dev/null || true
docker rmi confluentinc/cp-zookeeper:latest 2>/dev/null || true
docker rmi valkey/valkey:latest 2>/dev/null || true
docker rmi ${REMOTE_ZOT}/grafana:latest 2>/dev/null || true
docker rmi ${REMOTE_ZOT}/cp-kafka:7.5.0 2>/dev/null || true
docker rmi ${REMOTE_ZOT}/cp-zookeeper:latest 2>/dev/null || true
docker rmi ${REMOTE_ZOT}/valkey:latest 2>/dev/null || true

echo -e "${GREEN}✅ Imágenes limpiadas${NC}\n"

# Re-descargar solo plataforma específica
echo -e "${YELLOW}📥 Re-descargando imágenes (solo AMD64)...${NC}\n"

# Grafana
echo -e "${BLUE}Grafana...${NC}"
docker pull --platform linux/amd64 grafana/grafana:latest
docker tag grafana/grafana:latest ${REMOTE_ZOT}/grafana:latest
docker push ${REMOTE_ZOT}/grafana:latest && echo -e "${GREEN}✅ Grafana OK${NC}\n" || echo -e "${RED}❌ Grafana falló${NC}\n"

# Kafka
echo -e "${BLUE}Kafka...${NC}"
docker pull --platform linux/amd64 confluentinc/cp-kafka:7.5.0
docker tag confluentinc/cp-kafka:7.5.0 ${REMOTE_ZOT}/cp-kafka:7.5.0
docker push ${REMOTE_ZOT}/cp-kafka:7.5.0 && echo -e "${GREEN}✅ Kafka OK${NC}\n" || echo -e "${RED}❌ Kafka falló${NC}\n"

# Zookeeper
echo -e "${BLUE}Zookeeper...${NC}"
docker pull --platform linux/amd64 confluentinc/cp-zookeeper:latest
docker tag confluentinc/cp-zookeeper:latest ${REMOTE_ZOT}/cp-zookeeper:latest
docker push ${REMOTE_ZOT}/cp-zookeeper:latest && echo -e "${GREEN}✅ Zookeeper OK${NC}\n" || echo -e "${RED}❌ Zookeeper falló${NC}\n"

# Valkey
echo -e "${BLUE}Valkey...${NC}"
docker pull --platform linux/amd64 valkey/valkey:latest
docker tag valkey/valkey:latest ${REMOTE_ZOT}/valkey:latest
docker push ${REMOTE_ZOT}/valkey:latest && echo -e "${GREEN}✅ Valkey OK${NC}\n" || echo -e "${RED}❌ Valkey falló${NC}\n"

echo -e "\n${BLUE}📋 Catálogo final:${NC}"
curl -s http://${REMOTE_ZOT}/v2/_catalog | jq -r '.repositories[]' | sort

echo -e "\n${YELLOW}💡 Si persiste el error 'manifest invalid', las imágenes pueden estar${NC}"
echo -e "${YELLOW}   corruptas en el registry. Considera usar un registry diferente.${NC}"
