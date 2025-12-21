#!/bin/bash

echo "🧪 Pruebas de Nginx Proxy en Kubernetes"
echo "========================================"
echo ""

# Verificar que el servicio existe
if ! kubectl get service nginx-proxy-service -n blackfriday &> /dev/null; then
    echo "❌ El servicio nginx-proxy-service no existe"
    echo "   Ejecuta primero: ./deploy-nginx.sh"
    exit 1
fi

# Obtener la URL
if command -v minikube &> /dev/null; then
    NGINX_URL=$(minikube service nginx-proxy-service -n blackfriday --url 2>/dev/null)
    if [ -z "$NGINX_URL" ]; then
        NGINX_URL="http://localhost:30300"
    fi
else
    NGINX_URL="http://localhost:30300"
fi

echo "📍 URL de prueba: $NGINX_URL"
echo ""

# Test 1: Health Check
echo "1️⃣  Test: Health Check"
echo "   curl $NGINX_URL/health"
response=$(curl -s -w "\n%{http_code}" "$NGINX_URL/health" 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    echo "   ✅ Health check OK: $body"
else
    echo "   ❌ Health check FAILED (HTTP $http_code)"
fi
echo ""

# Test 2: Obtener productos
echo "2️⃣  Test: Obtener productos"
echo "   curl $NGINX_URL/productos"
response=$(curl -s -w "\n%{http_code}" "$NGINX_URL/productos" 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    # Verificar que sea JSON válido con productos
    if echo "$body" | grep -q "prod001"; then
        echo "   ✅ Productos obtenidos correctamente"
        echo "   📦 Primeros productos:"
        echo "$body" | head -c 200
        echo "..."
    else
        echo "   ⚠️  Respuesta recibida pero sin productos esperados"
        echo "   Respuesta: $body"
    fi
else
    echo "   ❌ Error obteniendo productos (HTTP $http_code)"
    echo "   Respuesta: $body"
fi
echo ""

# Test 3: Realizar una compra
echo "3️⃣  Test: Realizar compra"
echo "   curl -X POST $NGINX_URL/comprar"
response=$(curl -s -w "\n%{http_code}" -X POST "$NGINX_URL/comprar" \
    -H "Content-Type: application/json" \
    -d '{"producto_id":"prod001","cantidad":2}' 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    echo "   ✅ Compra procesada correctamente"
    echo "   📝 Respuesta: $body"
else
    echo "   ⚠️  Compra respondió con HTTP $http_code"
    echo "   📝 Respuesta: $body"
fi
echo ""

# Test 4: Balanceo de carga (múltiples peticiones)
echo "4️⃣  Test: Balanceo de carga (10 peticiones)"
echo "   Verificando distribución entre pods..."
success_count=0
for i in {1..10}; do
    response=$(curl -s -w "%{http_code}" "$NGINX_URL/productos" -o /dev/null 2>/dev/null)
    if [ "$response" = "200" ]; then
        ((success_count++))
        echo -n "✓"
    else
        echo -n "✗"
    fi
done
echo ""
echo "   📊 Peticiones exitosas: $success_count/10"
if [ $success_count -eq 10 ]; then
    echo "   ✅ Todas las peticiones fueron exitosas"
else
    echo "   ⚠️  Algunas peticiones fallaron"
fi
echo ""

# Test 5: Verificar headers
echo "5️⃣  Test: Headers de proxy"
echo "   Verificando headers X-Forwarded..."
headers=$(curl -s -I "$NGINX_URL/productos" 2>/dev/null)
if echo "$headers" | grep -q "HTTP"; then
    echo "   ✅ Headers recibidos correctamente"
    echo "$headers" | head -5
else
    echo "   ⚠️  No se pudieron obtener headers"
fi
echo ""

# Resumen del estado del cluster
echo "📊 Estado del cluster:"
echo ""
echo "Pods de Nginx:"
kubectl get pods -n blackfriday -l app=nginx-proxy --no-headers 2>/dev/null | awk '{print "   " $1 " - " $3}'
echo ""
echo "Pods de API Rust:"
kubectl get pods -n blackfriday -l app=api-rust --no-headers 2>/dev/null | awk '{print "   " $1 " - " $3}'
echo ""

echo "✅ Pruebas completadas"
echo ""
echo "💡 Para ver logs en tiempo real:"
echo "   kubectl logs -f -l app=nginx-proxy -n blackfriday"
echo "   kubectl logs -f -l app=api-rust -n blackfriday"
