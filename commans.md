# Guía Completa de Despliegue - Black Friday System

## 📋 Requisitos Previos

- Docker instalado
- Minikube instalado
- kubectl instalado
- Go 1.24+ instalado
- Rust 1.83+ instalado

---

## 🚀 PASO 1: Iniciar Minikube

```bash
# Verificar estado de minikube
minikube status

# Si está detenido, iniciarlo
minikube start

# Verificar que kubectl funciona
kubectl get nodes

# Obtener IP de minikube (guardar para después)
minikube ip
```

---

## 📦 PASO 2: Crear Namespace

```bash
# Crear namespace blackfriday si no existe
kubectl create namespace blackfriday --dry-run=client -o yaml | kubectl apply -f -

# Verificar namespace
kubectl get namespaces | grep blackfriday
```

---

## 🔧 PASO 3: Generar Archivos Proto

```bash
# Ir al directorio grpc-server
cd grpc-server

# Generar archivos proto
./generate.sh

# Volver al directorio raíz
cd ..

# Copiar proto generados a go-api-rest (limpiar primero)
rm -rf go-api-rest/proto
cp -r grpc-server/proto go-api-rest/

# Verificar que los archivos proto existen
ls -la grpc-server/proto/
ls -la go-api-rest/proto/
```

---

## 🏗️ PASO 4: Construir Todas las Imágenes Docker

```bash
# Configurar Docker para usar el daemon de minikube
eval $(minikube docker-env)

# Verificar que estamos usando Docker de minikube
docker ps

# Construir API Rust
echo "=== Construyendo API Rust ==="
docker build -t rust-api:latest -f api/Dockerfile .

# Construir Go API REST
echo "=== Construyendo Go API REST ==="
docker build -t go-api-rest:latest -f go-api-rest/Dockerfile.simple go-api-rest

# Construir gRPC Server
echo "=== Construyendo gRPC Server ==="
docker build -t grpc-server:latest -f grpc-server/Dockerfile.simple grpc-server

# Construir Kafka Consumer
echo "=== Construyendo Kafka Consumer ==="
docker build -t kafka-consumer:latest ./kafka-consumer

# Construir Locust
echo "=== Construyendo Locust ==="
docker build -t locust:latest ./locust

# Verificar que todas las imágenes se construyeron
docker images | grep -E "rust-api|go-api-rest|grpc-server|kafka-consumer|locust"
```

---

## 📤 PASO 5: Desplegar Componentes en Orden

```bash
# 1. Desplegar Zookeeper (requerido por Kafka)
kubectl apply -f k8s/01-zookeeper.yaml

# Esperar a que Zookeeper esté listo
kubectl wait --for=condition=ready pod -l app=zookeeper -n blackfriday --timeout=120s

# 2. Desplegar Kafka
kubectl apply -f k8s/02-kafka.yaml

# Esperar a que Kafka esté listo
sleep 30
kubectl wait --for=condition=ready pod -l app=kafka -n blackfriday --timeout=120s

# 3. Desplegar Valkey (Redis)
kubectl apply -f k8s/08-valkey.yaml

# Esperar a que Valkey esté listo
sleep 20
kubectl wait --for=condition=ready pod -l app=valkey -n blackfriday --timeout=120s

# 4. Desplegar servidores gRPC
kubectl apply -f k8s/11-grpc-server-1.yaml
kubectl apply -f k8s/12-grpc-server-2.yaml

# Esperar a que servidores gRPC estén listos
sleep 15
kubectl wait --for=condition=ready pod -l app=grpc-server-1 -n blackfriday --timeout=90s
kubectl wait --for=condition=ready pod -l app=grpc-server-2 -n blackfriday --timeout=90s

# 5. Desplegar Go API REST (Deployment 1 - gRPC Client)
kubectl apply -f k8s/10-go-api-rest.yaml

# Esperar a que Go API REST esté listo
sleep 15
kubectl wait --for=condition=ready pod -l app=go-api-rest -n blackfriday --timeout=90s

# 6. Desplegar API Rust
kubectl apply -f k8s/06-api-rust.yaml

# Esperar a que API Rust esté lista
sleep 15
kubectl wait --for=condition=ready pod -l app=api-rust -n blackfriday --timeout=120s

# 7. Desplegar Nginx Proxy
kubectl apply -f k8s/07-nginx-proxy.yaml

# Esperar a que Nginx esté listo
sleep 10
kubectl wait --for=condition=ready pod -l app=nginx-proxy -n blackfriday --timeout=90s

# 8. Desplegar Kafka Consumer
kubectl apply -f k8s/09-kafka-consumer.yaml

# Esperar a que Consumer esté listo
sleep 10
kubectl wait --for=condition=ready pod -l app=kafka-consumer -n blackfriday --timeout=90s

# 9. Desplegar Locust
kubectl apply -f k8s/13-locust.yaml

# 10. Desplegar Grafana
kubectl apply -f k8s/14-grafana.yaml

# Esperar a que Grafana esté listo
sleep 20
kubectl wait --for=condition=ready pod -l app=grafana -n blackfriday --timeout=120s
```

---

## ✅ PASO 6: Verificar que Todo Esté Funcionando

```bash
# Ver todos los pods
kubectl get pods -n blackfriday

# Ver todos los servicios
kubectl get services -n blackfriday

# Verificar que todos los pods estén Running (1/1)
kubectl get pods -n blackfriday | grep -v "Running.*1/1"

# Ver logs de componentes principales
echo "=== Logs API Rust ==="
kubectl logs -n blackfriday -l app=api-rust --tail=10

echo "=== Logs Go API REST ==="
kubectl logs -n blackfriday -l app=go-api-rest --tail=10

echo "=== Logs gRPC Server 1 ==="
kubectl logs -n blackfriday -l app=grpc-server-1 --tail=10

echo "=== Logs Kafka Consumer ==="
kubectl logs -n blackfriday -l app=kafka-consumer --tail=10
```

---

## 🧪 PASO 7: Probar el Sistema

```bash
# Obtener IP de minikube
MINIKUBE_IP=$(minikube ip)
echo "IP de Minikube: $MINIKUBE_IP"

# Probar health check de la API
curl http://$MINIKUBE_IP:30300/health

# Listar productos
curl http://$MINIKUBE_IP:30300/productos

# Realizar una compra de prueba
curl -X POST http://$MINIKUBE_IP:30300/comprar \
  -H "Content-Type: application/json" \
  -d '{
    "producto_id": "prod001",
    "cantidad": 2,
    "usuario": "test-user"
  }'

# Esperar unos segundos y verificar en Valkey
sleep 5
kubectl exec -n blackfriday valkey-0 -- valkey-cli KEYS "*"

# Ver contador total de compras
kubectl exec -n blackfriday valkey-0 -- valkey-cli GET "total:compras"
```

---

## 🌐 PASO 8: Acceder a Servicios Web

```bash
# Obtener URLs de acceso
MINIKUBE_IP=$(minikube ip)

echo "================================"
echo "URLs de Acceso:"
echo "================================"
echo "API REST:    http://$MINIKUBE_IP:30300"
echo "Locust:      http://$MINIKUBE_IP:30089"
echo "Grafana:     http://$MINIKUBE_IP:30000"
echo "================================"
echo ""
echo "Credenciales Grafana:"
echo "  Usuario: admin"
echo "  Password: admin"
echo "================================"

# Abrir servicios en el navegador (Linux)
xdg-open http://$MINIKUBE_IP:30300 &
xdg-open http://$MINIKUBE_IP:30089 &
xdg-open http://$MINIKUBE_IP:30000 &
```

---

## 🔄 PASO 9: Reiniciar Componentes (Si es necesario)

```bash
# Reiniciar un deployment específico
kubectl rollout restart deployment api-rust -n blackfriday
kubectl rollout restart deployment go-api-rest -n blackfriday
kubectl rollout restart deployment kafka-consumer -n blackfriday

# Ver estado del rollout
kubectl rollout status deployment api-rust -n blackfriday
```

---

## 🧹 PASO 10: Limpiar Todo (Opcional)

```bash
# Eliminar todos los recursos del namespace
kubectl delete namespace blackfriday

# O eliminar componentes individuales
kubectl delete -f k8s/14-grafana.yaml
kubectl delete -f k8s/13-locust.yaml
kubectl delete -f k8s/09-kafka-consumer.yaml
kubectl delete -f k8s/07-nginx-proxy.yaml
kubectl delete -f k8s/06-api-rust.yaml
kubectl delete -f k8s/10-go-api-rest.yaml
kubectl delete -f k8s/11-grpc-server-1.yaml
kubectl delete -f k8s/12-grpc-server-2.yaml
kubectl delete -f k8s/08-valkey.yaml
kubectl delete -f k8s/02-kafka.yaml
kubectl delete -f k8s/01-zookeeper.yaml

# Detener minikube
minikube stop

# Eliminar cluster completo (CUIDADO: elimina todo)
# minikube delete
```

---

## 📊 Comandos Útiles de Monitoreo

```bash
# Ver uso de recursos
kubectl top pods -n blackfriday
kubectl top nodes

# Ver eventos del namespace
kubectl get events -n blackfriday --sort-by='.lastTimestamp'

# Ver logs en tiempo real
kubectl logs -f -n blackfriday -l app=api-rust
kubectl logs -f -n blackfriday -l app=kafka-consumer

# Describir un pod con problemas
kubectl describe pod <POD_NAME> -n blackfriday

# Ejecutar comando dentro de un pod
kubectl exec -it -n blackfriday <POD_NAME> -- sh

# Port-forward para acceso local directo
kubectl port-forward -n blackfriday svc/grafana-service 3000:3000
kubectl port-forward -n blackfriday svc/locust-service 8089:8089
```

---

## 🐛 Troubleshooting

```bash
# Si un pod no inicia, ver los logs
kubectl logs -n blackfriday <POD_NAME> --previous

# Si falla la construcción de imágenes
eval $(minikube docker-env)
docker images  # Verificar que las imágenes existen

# Si kubectl no conecta con minikube
kubectl config get-contexts
kubectl config use-context minikube

# Verificar configuración de Docker
docker context ls
eval $(minikube docker-env)

# Si Kafka no funciona
kubectl logs -n blackfriday -l app=kafka --tail=50
kubectl logs -n blackfriday -l app=zookeeper --tail=50

# Reiniciar minikube completamente
minikube stop
minikube start
```

---

## 📝 Arquitectura del Sistema

```
Usuario/Locust
    ↓
Nginx Proxy (NodePort 30300)
    ↓
API Rust (2 réplicas)
    ↓
Go API REST (Deployment 1 - gRPC Client, 2 réplicas)
    ↓
    ├─→ gRPC Server 1 (1 réplica)  ─┐
    └─→ gRPC Server 2 (2 réplicas) ─┤
                                     ↓
                                  Kafka
                                     ↓
                             Kafka Consumer (2 réplicas)
                                     ↓
                                  Valkey (StatefulSet, 2 réplicas)
                                     ↓
                              Grafana (NodePort 30000)
```

---

## 🎯 Pruebas de Carga con Locust

1. Abrir Locust: http://$(minikube ip):30089
2. Configurar:
   - Number of users: 50
   - Spawn rate: 5
   - Host: http://nginx-proxy-service
3. Click "Start Swarming"
4. Observar métricas en tiempo real
5. Ver resultados en Grafana

---

## 📈 Configurar Dashboard en Grafana

1. Login en Grafana: http://$(minikube ip):30000 (admin/admin)
2. Ir a Connections → Data Sources
3. Verificar que "Valkey" está configurado
4. Crear nuevo Dashboard
5. Agregar panel con query:
   - Data Source: Valkey
   - Command: GET total:compras
6. Guardar dashboard
