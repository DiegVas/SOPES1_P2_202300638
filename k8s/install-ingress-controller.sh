#!/bin/bash

echo "======================================"
echo "Instalando NGINX Ingress Controller"
echo "======================================"

# Aplicar el NGINX Ingress Controller
echo "Aplicando NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

echo ""
echo "Esperando a que el Ingress Controller esté listo..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo ""
echo "======================================"
echo "Estado del Ingress Controller:"
echo "======================================"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

echo ""
echo "======================================"
echo "✅ NGINX Ingress Controller instalado"
echo "======================================"
