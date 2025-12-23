#!/bin/bash
set -e

REMOTE_ZOT="18.222.2.22:5000"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔄 Actualizando deployments para usar Zot Registry${NC}\n"

# Crear directorio de backup
BACKUP_DIR="k8s/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}📦 Haciendo backup de archivos YAML...${NC}"
cp k8s/*.yaml "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✅ Backup en: $BACKUP_DIR${NC}\n"

# Actualizar rust-api
echo -e "${BLUE}Actualizando rust-api...${NC}"
sed -i "s|image: rust-api:latest|image: ${REMOTE_ZOT}/rust-api:latest|g" k8s/06-api-rust.yaml
sed -i "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/06-api-rust.yaml

# Actualizar go-api-rest
echo -e "${BLUE}Actualizando go-api-rest...${NC}"
sed -i "s|image: go-api-rest:latest|image: ${REMOTE_ZOT}/go-api-rest:latest|g" k8s/05-go-api-rest.yaml k8s/10-go-api-rest.yaml
sed -i "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/05-go-api-rest.yaml k8s/10-go-api-rest.yaml

# Actualizar grpc-server
echo -e "${BLUE}Actualizando grpc-server...${NC}"
sed -i "s|image: grpc-server:latest|image: ${REMOTE_ZOT}/grpc-server:latest|g" k8s/03-grpc-server-1.yaml k8s/04-grpc-server-2.yaml k8s/11-grpc-server-1.yaml k8s/12-grpc-server-2.yaml
sed -i "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/03-grpc-server-1.yaml k8s/04-grpc-server-2.yaml k8s/11-grpc-server-1.yaml k8s/12-grpc-server-2.yaml

# Actualizar kafka-consumer
echo -e "${BLUE}Actualizando kafka-consumer...${NC}"
sed -i "s|image: kafka-consumer:latest|image: ${REMOTE_ZOT}/kafka-consumer:latest|g" k8s/09-kafka-consumer.yaml
sed -i "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/09-kafka-consumer.yaml

# Actualizar locust
echo -e "${BLUE}Actualizando locust...${NC}"
sed -i "s|image: locust:latest|image: ${REMOTE_ZOT}/locust:latest|g" k8s/13-locust.yaml
sed -i "s|imagePullPolicy: Never|imagePullPolicy: Always|g" k8s/13-locust.yaml

# Actualizar nginx (si no usa imagen pública)
echo -e "${BLUE}Actualizando nginx...${NC}"
if grep -q "image: nginx:alpine" k8s/07-nginx-proxy.yaml 2>/dev/null; then
    sed -i "s|image: nginx:alpine|image: ${REMOTE_ZOT}/nginx:alpine|g" k8s/07-nginx-proxy.yaml
    sed -i "s|imagePullPolicy: IfNotPresent|imagePullPolicy: Always|g" k8s/07-nginx-proxy.yaml
fi

echo -e "\n${GREEN}✅ Deployments actualizados!${NC}\n"

echo -e "${BLUE}📋 Resumen de cambios:${NC}"
echo -e "  • rust-api        → ${REMOTE_ZOT}/rust-api:latest"
echo -e "  • go-api-rest     → ${REMOTE_ZOT}/go-api-rest:latest"
echo -e "  • grpc-server     → ${REMOTE_ZOT}/grpc-server:latest"
echo -e "  • kafka-consumer  → ${REMOTE_ZOT}/kafka-consumer:latest"
echo -e "  • locust          → ${REMOTE_ZOT}/locust:latest"
echo -e "  • nginx           → ${REMOTE_ZOT}/nginx:alpine"
echo -e "\n  • grafana, kafka, zookeeper, valkey → mantienen imágenes públicas"

echo -e "\n${YELLOW}💡 Para aplicar los cambios en tu cluster:${NC}"
echo -e "   kubectl apply -f k8s/"
echo -e "\n${YELLOW}💡 Para restaurar el backup:${NC}"
echo -e "   cp $BACKUP_DIR/* k8s/"
