#!/bin/bash

# Script para actualizar los deployments de Kubernetes
# Usa Zot solo para imágenes custom, imágenes públicas las deja como están

REMOTE_ZOT="18.222.2.22:5000"

cat << 'EOF'
Estrategia de imágenes:

✅ Desde Zot (imágenes custom):
   - rust-api
   - go-api-rest  
   - grpc-server
   - kafka-consumer
   - locust
   - nginx

⚠️  Imágenes públicas (directo de Docker Hub):
   - grafana/grafana:latest
   - confluentinc/cp-kafka:7.5.0
   - confluentinc/cp-zookeeper:latest
   - valkey/valkey:latest

Esto evita el problema de "manifest invalid" en Zot.
EOF

echo ""
echo "Para actualizar tus deployments, modifica las imágenes así:"
echo ""
echo "# Imágenes custom (desde Zot):"
echo "  image: ${REMOTE_ZOT}/rust-api:latest"
echo "  image: ${REMOTE_ZOT}/go-api-rest:latest"
echo "  image: ${REMOTE_ZOT}/grpc-server:latest"
echo "  image: ${REMOTE_ZOT}/kafka-consumer:latest"
echo "  image: ${REMOTE_ZOT}/locust:latest"
echo "  image: ${REMOTE_ZOT}/nginx:alpine"
echo ""
echo "# Imágenes públicas (directo):"
echo "  image: grafana/grafana:latest"
echo "  image: confluentinc/cp-kafka:7.5.0"
echo "  image: confluentinc/cp-zookeeper:latest"
echo "  image: valkey/valkey:latest"
echo ""
echo "¿Quieres que actualice automáticamente los YAMLs? (y/n)"
