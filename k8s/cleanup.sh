#!/bin/bash

echo "🧹 Eliminando despliegue de Black Friday..."

kubectl delete -f k8s/06-rust-api.yaml
kubectl delete -f k8s/05-go-api-rest.yaml
kubectl delete -f k8s/04-grpc-server-2.yaml
kubectl delete -f k8s/03-grpc-server-1.yaml
kubectl delete -f k8s/02-kafka.yaml
kubectl delete -f k8s/01-zookeeper.yaml
kubectl delete -f k8s/00-namespace-config.yaml

echo "✅ Despliegue eliminado"
