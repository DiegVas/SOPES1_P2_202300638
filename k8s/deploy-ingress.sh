#!/bin/bash

echo "======================================"
echo "Desplegando Ingress Resources"
echo "======================================"

# Verificar si el Ingress Controller está instalado
echo "Verificando Ingress Controller..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "⚠️  Ingress Controller no encontrado."
    echo "Ejecutando instalación..."
    ./install-ingress-controller.sh
else
    echo "✅ Ingress Controller ya está instalado"
fi

echo ""
echo "Aplicando configuración de Ingress..."
kubectl apply -f 15-ingress.yaml

echo ""
echo "======================================"
echo "Estado de los Ingress:"
echo "======================================"
kubectl get ingress -n blackfriday

echo ""
echo "======================================"
echo "Endpoints del Ingress Controller:"
echo "======================================"
kubectl get svc -n ingress-nginx

echo ""
echo "======================================"
echo "Configuración de acceso:"
echo "======================================"
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo "Tipo: NodePort"
    echo "IP del Nodo: $NODE_IP"
    echo "Puerto HTTP: $INGRESS_PORT"
    echo ""
    echo "Para acceder a los servicios:"
    echo "  - API Principal: http://$NODE_IP:$INGRESS_PORT/"
    echo "  - Go API: http://$NODE_IP:$INGRESS_PORT/api/go"
    echo "  - Grafana: http://$NODE_IP:$INGRESS_PORT/grafana"
    echo "  - Locust: http://$NODE_IP:$INGRESS_PORT/locust"
    echo ""
    echo "Agregar a /etc/hosts (opcional):"
    echo "  $NODE_IP blackfriday.local"
    echo "  $NODE_IP api.blackfriday.local"
    echo "  $NODE_IP grafana.blackfriday.local"
    echo "  $NODE_IP locust.blackfriday.local"
else
    echo "Tipo: LoadBalancer"
    echo "IP Externa: $INGRESS_IP"
    echo ""
    echo "Para acceder a los servicios:"
    echo "  - API Principal: http://blackfriday.local/"
    echo "  - Go API: http://blackfriday.local/api/go"
    echo "  - Grafana: http://blackfriday.local/grafana"
    echo "  - Locust: http://blackfriday.local/locust"
    echo ""
    echo "Agregar a /etc/hosts:"
    echo "  $INGRESS_IP blackfriday.local"
    echo "  $INGRESS_IP api.blackfriday.local"
    echo "  $INGRESS_IP grafana.blackfriday.local"
    echo "  $INGRESS_IP locust.blackfriday.local"
fi

echo ""
echo "======================================"
echo "✅ Ingress desplegado correctamente"
echo "======================================"
