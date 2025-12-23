#!/bin/bash
set -e

echo "🔄 Actualizando Deployments para usar Zot Registry"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

echo -e "${BLUE}📦 Zot Registry: ${ZOT_REGISTRY}${NC}"

# Crear backup de deployments originales
echo -e "\n${YELLOW}💾 Creando backup de deployments...${NC}"
mkdir -p k8s/backup
cp k8s/06-api-rust.yaml k8s/backup/06-api-rust.yaml.bak
cp k8s/10-go-api-rest.yaml k8s/backup/10-go-api-rest.yaml.bak
cp k8s/11-grpc-server-1.yaml k8s/backup/11-grpc-server-1.yaml.bak
cp k8s/12-grpc-server-2.yaml k8s/backup/12-grpc-server-2.yaml.bak
cp k8s/09-kafka-consumer.yaml k8s/backup/09-kafka-consumer.yaml.bak
cp k8s/13-locust.yaml k8s/backup/13-locust.yaml.bak
cp k8s/07-nginx-proxy.yaml k8s/backup/07-nginx-proxy.yaml.bak

# Actualizar referencias de imágenes usando sed
echo -e "\n${YELLOW}🔧 Actualizando referencias de imágenes...${NC}"

# Rust API
sed -i "s|image: rust-api:latest|image: ${ZOT_REGISTRY}/rust-api:latest|g" k8s/06-api-rust.yaml

# Go API REST
sed -i "s|image: go-api-rest:latest|image: ${ZOT_REGISTRY}/go-api-rest:latest|g" k8s/10-go-api-rest.yaml

# gRPC Server 1
sed -i "s|image: grpc-server:latest|image: ${ZOT_REGISTRY}/grpc-server:latest|g" k8s/11-grpc-server-1.yaml

# gRPC Server 2
sed -i "s|image: grpc-server:latest|image: ${ZOT_REGISTRY}/grpc-server:latest|g" k8s/12-grpc-server-2.yaml

# Kafka Consumer
sed -i "s|image: kafka-consumer:latest|image: ${ZOT_REGISTRY}/kafka-consumer:latest|g" k8s/09-kafka-consumer.yaml

# Locust
sed -i "s|image: locust:latest|image: ${ZOT_REGISTRY}/locust:latest|g" k8s/13-locust.yaml

# Nginx
sed -i "s|image: nginx-proxy:latest|image: ${ZOT_REGISTRY}/nginx-proxy:latest|g" k8s/07-nginx-proxy.yaml

# Agregar imagePullPolicy: Always si no existe
for file in k8s/06-api-rust.yaml k8s/10-go-api-rest.yaml k8s/11-grpc-server-1.yaml k8s/12-grpc-server-2.yaml k8s/09-kafka-consumer.yaml k8s/13-locust.yaml k8s/07-nginx-proxy.yaml; do
    if ! grep -q "imagePullPolicy" "$file"; then
        # Agregar imagePullPolicy después de la línea de image
        sed -i "/image: ${ZOT_REGISTRY}/a\        imagePullPolicy: Always" "$file"
    fi
done

echo -e "${GREEN}✅ Deployments actualizados${NC}"

# Mostrar diferencias
echo -e "\n${YELLOW}📋 Cambios realizados:${NC}"
echo -e "${BLUE}rust-api:latest → ${ZOT_REGISTRY}/rust-api:latest${NC}"
echo -e "${BLUE}go-api-rest:latest → ${ZOT_REGISTRY}/go-api-rest:latest${NC}"
echo -e "${BLUE}grpc-server:latest → ${ZOT_REGISTRY}/grpc-server:latest${NC}"
echo -e "${BLUE}kafka-consumer:latest → ${ZOT_REGISTRY}/kafka-consumer:latest${NC}"
echo -e "${BLUE}locust:latest → ${ZOT_REGISTRY}/locust:latest${NC}"
echo -e "${BLUE}nginx-proxy:latest → ${ZOT_REGISTRY}/nginx-proxy:latest${NC}"

# Aplicar cambios
echo -e "\n${YELLOW}🚀 Aplicando cambios a Kubernetes...${NC}"

kubectl apply -f k8s/06-api-rust.yaml
kubectl apply -f k8s/10-go-api-rest.yaml
kubectl apply -f k8s/11-grpc-server-1.yaml
kubectl apply -f k8s/12-grpc-server-2.yaml
kubectl apply -f k8s/09-kafka-consumer.yaml
kubectl apply -f k8s/13-locust.yaml
kubectl apply -f k8s/07-nginx-proxy.yaml

# Reiniciar deployments para forzar pull de nuevas imágenes
echo -e "\n${YELLOW}🔄 Reiniciando deployments...${NC}"

kubectl rollout restart deployment api-rust -n blackfriday
kubectl rollout restart deployment go-api-rest -n blackfriday
kubectl rollout restart deployment grpc-server-1 -n blackfriday
kubectl rollout restart deployment grpc-server-2 -n blackfriday
kubectl rollout restart deployment kafka-consumer -n blackfriday
kubectl rollout restart deployment locust -n blackfriday
kubectl rollout restart deployment nginx-proxy -n blackfriday

# Esperar a que los rollouts completen
echo -e "\n${YELLOW}⏳ Esperando a que los rollouts completen...${NC}"

kubectl rollout status deployment api-rust -n blackfriday
kubectl rollout status deployment go-api-rest -n blackfriday
kubectl rollout status deployment grpc-server-1 -n blackfriday
kubectl rollout status deployment grpc-server-2 -n blackfriday
kubectl rollout status deployment kafka-consumer -n blackfriday
kubectl rollout status deployment locust -n blackfriday
kubectl rollout status deployment nginx-proxy -n blackfriday

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✅ Todos los deployments actualizados y usando Zot Registry!${NC}"
echo -e "${GREEN}================================${NC}"

# Verificar que los pods están corriendo
echo -e "\n${YELLOW}📊 Estado de los pods:${NC}"
kubectl get pods -n blackfriday

echo -e "\n${YELLOW}💡 Para restaurar los deployments originales:${NC}"
echo -e "   cp k8s/backup/*.bak k8s/"
echo ""
