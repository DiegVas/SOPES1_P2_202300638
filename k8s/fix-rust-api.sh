#!/bin/bash

echo "🔧 Solucionando problema de API Rust en Kubernetes..."
echo ""

# Eliminar deployment actual
echo "1️⃣  Eliminando deployment actual..."
kubectl delete deployment api-rust -n blackfriday

# Esperar un momento
sleep 3

# Reconstruir imagen
echo "2️⃣  Reconstruyendo imagen..."
eval $(minikube docker-env)
docker build -f ../api/Dockerfile -t rust-api:latest ..

# Redesplegar
echo "3️⃣  Redesplegando API de Rust..."
kubectl apply -f 06-api-rust.yaml

# Esperar y ver estado
sleep 10
echo ""
echo "📊 Estado de los pods:"
kubectl get pods -n blackfriday

echo ""
echo "💡 Ver logs con:"
echo "   kubectl logs -f -l app=api-rust -n blackfriday"
