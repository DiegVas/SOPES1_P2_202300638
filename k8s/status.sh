#!/bin/bash

echo "📊 Estado del Sistema Black Friday"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar namespace
echo "🔍 Namespace:"
kubectl get namespace blackfriday 2>/dev/null
echo ""

# Pods
echo "🐳 Pods:"
kubectl get pods -n blackfriday -o wide
echo ""

# Deployments
echo "📦 Deployments:"
kubectl get deployments -n blackfriday
echo ""

# Services
echo "🌐 Services:"
kubectl get services -n blackfriday
echo ""

# ConfigMaps
echo "⚙️  ConfigMaps:"
kubectl get configmaps -n blackfriday
echo ""

# Réplicas por deployment
echo "📊 Réplicas:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get deployments -n blackfriday -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas
echo ""

# Recursos
echo "💾 Uso de Recursos:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl top pods -n blackfriday 2>/dev/null || echo "Metrics server no disponible"
echo ""

# Endpoints
echo "🌐 Endpoints Externos:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Rust API:    http://localhost:30000"
echo "Go API REST: http://localhost:30080"
echo ""

# Verificar conectividad
echo "🔌 Verificando Conectividad:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -s http://localhost:30000/productos > /dev/null 2>&1; then
    echo "✅ Rust API: OK"
else
    echo "❌ Rust API: No disponible"
fi

if curl -s http://localhost:30080/health > /dev/null 2>&1; then
    echo "✅ Go API: OK"
else
    echo "❌ Go API: No disponible"
fi
echo ""

# Últimos eventos
echo "📋 Últimos Eventos:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get events -n blackfriday --sort-by='.lastTimestamp' | tail -10
echo ""

# Comandos útiles
echo "💡 Comandos Útiles:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ver logs:          kubectl logs -f <pod-name> -n blackfriday"
echo "Escalar:           kubectl scale deployment <name> --replicas=N -n blackfriday"
echo "Describir pod:     kubectl describe pod <pod-name> -n blackfriday"
echo "Shell en pod:      kubectl exec -it <pod-name> -n blackfriday -- /bin/sh"
echo "Monitorear Kafka:  cd k8s && ./monitor-kafka.sh"
echo "Tests:             ./test_k8s.sh"
