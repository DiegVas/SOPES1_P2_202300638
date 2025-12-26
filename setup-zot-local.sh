#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Configurando Zot Registry Local en Minikube${NC}\n"

# Paso 1: Detener Minikube
echo -e "${YELLOW}1. Deteniendo Minikube...${NC}"
minikube stop

# Paso 2: Iniciar Minikube con opciones correctas
echo -e "${YELLOW}2. Iniciando Minikube con registry inseguro...${NC}"
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
minikube start \
    --insecure-registry="10.0.0.0/8" \
    --insecure-registry="192.168.0.0/16" \
    --insecure-registry="localhost:5000"

# Obtener nueva IP
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

echo -e "${GREEN}✅ Minikube iniciado${NC}"
echo -e "${BLUE}   IP: ${MINIKUBE_IP}${NC}"
echo -e "${BLUE}   Zot Registry: ${ZOT_REGISTRY}${NC}\n"

# Paso 3: Esperar a que Zot esté listo
echo -e "${YELLOW}3. Esperando a que Zot Registry esté listo...${NC}"
kubectl wait --for=condition=ready pod -l app=zot-registry -n blackfriday --timeout=120s 2>/dev/null || {
    echo -e "${YELLOW}   Zot no está desplegado. Desplegando...${NC}"
    kubectl apply -f k8s/00-zot-registry.yaml
    sleep 10
    kubectl wait --for=condition=ready pod -l app=zot-registry -n blackfriday --timeout=120s
}

echo -e "${GREEN}✅ Zot está corriendo${NC}\n"

# Paso 4: Verificar conectividad
echo -e "${YELLOW}4. Verificando conectividad...${NC}"
sleep 3
if curl -s "http://${ZOT_REGISTRY}/v2/" > /dev/null; then
    echo -e "${GREEN}✅ Zot accesible desde el host${NC}\n"
else
    echo -e "${RED}❌ No se puede conectar a Zot desde el host${NC}\n"
    exit 1
fi

# Paso 5: Configurar entorno Docker
echo -e "${YELLOW}5. Configurando entorno Docker de Minikube...${NC}"
eval $(minikube docker-env)
echo -e "${GREEN}✅ Entorno configurado${NC}\n"

# Paso 6: Verificar imágenes disponibles
echo -e "${YELLOW}6. Verificando imágenes disponibles...${NC}"
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "rust-api|go-api-rest|grpc-server|kafka-consumer|locust|nginx-proxy" | grep -v "<none>" || echo "")

if [ -z "$IMAGES" ]; then
    echo -e "${YELLOW}   No hay imágenes construidas. Construyendo...${NC}\n"
    cd k8s
    ./build-images.sh
    cd ..
    echo ""
fi

echo -e "${BLUE}Imágenes disponibles:${NC}"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|rust-api|go-api-rest|grpc-server|kafka-consumer|locust|nginx-proxy"
echo ""

# Paso 7: Tagear imágenes para Zot
echo -e "${YELLOW}7. Etiquetando imágenes para Zot...${NC}"

docker tag rust-api:latest ${ZOT_REGISTRY}/rust-api:latest 2>/dev/null || echo "  ⚠️  rust-api no encontrada"
docker tag go-api-rest:latest ${ZOT_REGISTRY}/go-api-rest:latest 2>/dev/null || echo "  ⚠️  go-api-rest no encontrada"
docker tag grpc-server:latest ${ZOT_REGISTRY}/grpc-server:latest 2>/dev/null || echo "  ⚠️  grpc-server no encontrada"
docker tag kafka-consumer:latest ${ZOT_REGISTRY}/kafka-consumer:latest 2>/dev/null || echo "  ⚠️  kafka-consumer no encontrada"
docker tag locust:latest ${ZOT_REGISTRY}/locust:latest 2>/dev/null || echo "  ⚠️  locust no encontrada"
docker tag nginx-proxy:latest ${ZOT_REGISTRY}/nginx-proxy:latest 2>/dev/null || echo "  ⚠️  nginx-proxy no encontrada"

echo -e "${GREEN}✅ Imágenes etiquetadas${NC}\n"

# Paso 8: Intentar push con puerto local
echo -e "${YELLOW}8. Creando port-forward temporal...${NC}"
kubectl port-forward -n blackfriday svc/zot-service 5555:5000 > /tmp/zot-pf.log 2>&1 &
PF_PID=$!
echo $PF_PID > /tmp/zot-pf.pid
sleep 3

if curl -s http://localhost:5555/v2/ > /dev/null; then
    echo -e "${GREEN}✅ Port-forward funcionando en localhost:5555${NC}\n"
    
    echo -e "${YELLOW}9. Pusheando imágenes a Zot (via port-forward)...${NC}"
    
    # Re-tagear para localhost
    docker tag rust-api:latest localhost:5555/rust-api:latest
    docker tag go-api-rest:latest localhost:5555/go-api-rest:latest
    docker tag grpc-server:latest localhost:5555/grpc-server:latest
    docker tag kafka-consumer:latest localhost:5555/kafka-consumer:latest
    docker tag locust:latest localhost:5555/locust:latest
    docker tag nginx-proxy:latest localhost:5555/nginx-proxy:latest
    
    # Pushear
    docker push localhost:5555/rust-api:latest && echo -e "${GREEN}  ✅ rust-api${NC}" || echo -e "${RED}  ❌ rust-api${NC}"
    docker push localhost:5555/go-api-rest:latest && echo -e "${GREEN}  ✅ go-api-rest${NC}" || echo -e "${RED}  ❌ go-api-rest${NC}"
    docker push localhost:5555/grpc-server:latest && echo -e "${GREEN}  ✅ grpc-server${NC}" || echo -e "${RED}  ❌ grpc-server${NC}"
    docker push localhost:5555/kafka-consumer:latest && echo -e "${GREEN}  ✅ kafka-consumer${NC}" || echo -e "${RED}  ❌ kafka-consumer${NC}"
    docker push localhost:5555/locust:latest && echo -e "${GREEN}  ✅ locust${NC}" || echo -e "${RED}  ❌ locust${NC}"
    docker push localhost:5555/nginx-proxy:latest && echo -e "${GREEN}  ✅ nginx-proxy${NC}" || echo -e "${RED}  ❌ nginx-proxy${NC}"
    
    # Matar port-forward
    kill $PF_PID 2>/dev/null || true
    
    echo -e "\n${GREEN}🎉 Proceso completado!${NC}\n"
else
    echo -e "${RED}❌ Port-forward falló${NC}\n"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# Paso 10: Verificar
echo -e "${YELLOW}10. Verificando imágenes en Zot...${NC}"
sleep 2
./zot-cli.sh list

echo -e "\n${BLUE}💡 Próximo paso: Actualizar deployments para usar Zot local${NC}"
echo -e "   Edita los archivos YAML en k8s/ para usar: ${ZOT_REGISTRY}/<imagen>:latest"
