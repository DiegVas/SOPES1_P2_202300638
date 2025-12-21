# 📁 Directorio Kubernetes (k8s/)

Este directorio contiene todos los manifiestos y scripts necesarios para desplegar la aplicación en Kubernetes.

## 📋 Estructura de Archivos

### Manifiestos de Kubernetes (orden de aplicación)

| Archivo                    | Descripción                     |
| -------------------------- | ------------------------------- |
| `00-namespace-config.yaml` | Namespace y ConfigMaps globales |
| `01-zookeeper.yaml`        | Zookeeper para Kafka            |
| `02-kafka.yaml`            | Apache Kafka broker             |
| `03-grpc-server-1.yaml`    | Primer servidor gRPC            |
| `04-grpc-server-2.yaml`    | Segundo servidor gRPC           |
| `05-go-api-rest.yaml`      | API REST en Go (cliente gRPC)   |
| `06-api-rust.yaml`         | API REST en Rust                |
| `07-nginx-proxy.yaml`      | Nginx como proxy reverso        |

### Scripts de Automatización

| Script             | Propósito                                 |
| ------------------ | ----------------------------------------- |
| `build-images.sh`  | Construir todas las imágenes Docker       |
| `deploy.sh`        | Despliegue completo de la aplicación      |
| `deploy-nginx.sh`  | Despliegue específico de nginx + API Rust |
| `test-nginx.sh`    | Suite de pruebas para nginx               |
| `status.sh`        | Ver estado de todos los recursos          |
| `monitor-kafka.sh` | Monitorear mensajes de Kafka              |
| `cleanup.sh`       | Limpiar todos los recursos                |

## 🚀 Despliegue Rápido

### Opción 1: Despliegue completo

```bash
# Desplegar toda la aplicación
./deploy.sh
```

### Opción 2: Solo Nginx + API Rust

```bash
# Desplegar solo nginx como proxy para la API de Rust
./deploy-nginx.sh
```

## 🏗️ Arquitectura Desplegada

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                         │
│                                                               │
│  ┌──────────┐                                                │
│  │ Zookeeper│                                                │
│  └────┬─────┘                                                │
│       │                                                       │
│  ┌────▼─────┐         ┌────────────┐   ┌────────────┐       │
│  │  Kafka   │◄────────┤ gRPC       │   │ gRPC       │       │
│  │  Broker  │         │ Server 1   │   │ Server 2   │       │
│  └──────────┘         └─────▲──────┘   └─────▲──────┘       │
│                             │                 │              │
│                        ┌────┴─────────────────┘              │
│                        │                                     │
│                   ┌────▼────────┐                           │
│                   │   Go API    │                           │
│                   │   REST      │                           │
│                   └─────────────┘                           │
│                                                               │
│  ┌─────────────┐      ┌──────────────┐                     │
│  │   Cliente   │─────▶│ Nginx Proxy  │                     │
│  │   Externo   │      │ (NodePort)   │                     │
│  └─────────────┘      └──────┬───────┘                     │
│                              │                              │
│                    ┌─────────┼─────────┐                   │
│                    │         │         │                   │
│             ┌──────▼───┐ ┌───▼────┐ ┌──▼──────┐           │
│             │ Rust API │ │Rust API│ │Rust API │           │
│             │  Pod 1   │ │ Pod 2  │ │ Pod 3   │           │
│             └──────────┘ └────────┘ └─────────┘           │
└──────────────────────────────────────────────────────────────┘
```

## 📝 Requisitos Previos

1. **kubectl** instalado

   ```bash
   sudo snap install kubectl --classic
   ```

2. **Minikube** (para desarrollo local)

   ```bash
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   minikube start --driver=docker
   ```

3. **Docker** configurado con Minikube
   ```bash
   eval $(minikube -p minikube docker-env)
   ```

## 🔧 Configuración de Servicios

### NodePorts Expuestos

| Servicio    | Puerto Interno | NodePort | URL                    |
| ----------- | -------------- | -------- | ---------------------- |
| Nginx Proxy | 80             | 30300    | http://localhost:30300 |
| Go API REST | 8080           | 30080    | http://localhost:30080 |
| Kafka       | 9092           | 30092    | localhost:30092        |

### ClusterIP (Servicios Internos)

| Servicio              | Puerto | Uso                   |
| --------------------- | ------ | --------------------- |
| api-rust-service      | 3000   | Backend para nginx    |
| kafka-service         | 9092   | Broker de mensajes    |
| zookeeper-service     | 2181   | Coordinación de Kafka |
| grpc-server-1-service | 50051  | Servidor gRPC 1       |
| grpc-server-2-service | 50051  | Servidor gRPC 2       |

## 🧪 Pruebas

### Pruebas Automatizadas

```bash
./test-nginx.sh
```

### Pruebas Manuales

```bash
# Health check de nginx
curl http://localhost:30300/health

# Obtener productos (a través de nginx)
curl http://localhost:30300/productos

# Realizar compra
curl -X POST http://localhost:30300/comprar \
  -H "Content-Type: application/json" \
  -d '{"producto_id":"prod001","cantidad":2}'

# API de Go directamente
curl http://localhost:30080/api/health
```

## 📊 Monitoreo

### Ver estado general

```bash
./status.sh
```

### Ver pods en tiempo real

```bash
watch -n 2 'kubectl get pods -n blackfriday'
```

### Ver logs

```bash
# Nginx
kubectl logs -f -l app=nginx-proxy -n blackfriday

# API Rust
kubectl logs -f -l app=api-rust -n blackfriday

# gRPC Servers
kubectl logs -f -l app=grpc-server -n blackfriday

# Kafka
./monitor-kafka.sh
```

## 🔄 Actualización de Componentes

### Reconstruir y redesplegar una imagen

```bash
# 1. Configurar entorno Docker de Minikube
eval $(minikube -p minikube docker-env)

# 2. Reconstruir imagen (ejemplo: Rust API)
docker build -f api/Dockerfile -t rust-api:latest .

# 3. Reiniciar deployment
kubectl rollout restart deployment api-rust -n blackfriday
```

### Actualizar configuración

```bash
# Editar el manifiesto
vim 07-nginx-proxy.yaml

# Aplicar cambios
kubectl apply -f 07-nginx-proxy.yaml

# Reiniciar si es necesario (para ConfigMaps)
kubectl rollout restart deployment nginx-proxy -n blackfriday
```

## 📈 Escalado

### Escalar manualmente

```bash
# Escalar nginx a 5 réplicas
kubectl scale deployment nginx-proxy --replicas=5 -n blackfriday

# Escalar API Rust a 10 réplicas
kubectl scale deployment api-rust --replicas=10 -n blackfriday

# Ver estado
kubectl get deployment -n blackfriday
```

### Auto-escalado (HPA)

```bash
# Habilitar metrics-server en minikube
minikube addons enable metrics-server

# Crear HPA para API Rust (escalar entre 2 y 10 pods)
kubectl autoscale deployment api-rust \
  --cpu-percent=70 \
  --min=2 --max=10 \
  -n blackfriday

# Ver HPAs
kubectl get hpa -n blackfriday
```

## 🐛 Troubleshooting

### Pods no inician

```bash
# Ver detalles del pod
kubectl describe pod <pod-name> -n blackfriday

# Ver eventos recientes
kubectl get events -n blackfriday --sort-by='.lastTimestamp' | tail -20

# Ver logs del pod
kubectl logs <pod-name> -n blackfriday
```

### Imagen no encontrada

```bash
# Verificar que estás usando el Docker de Minikube
eval $(minikube -p minikube docker-env)

# Listar imágenes disponibles
docker images | grep -E 'rust-api|go-api|grpc'

# Reconstruir imagen
docker build -f api/Dockerfile -t rust-api:latest .
```

### Servicio no responde

```bash
# Verificar que el servicio existe
kubectl get service -n blackfriday

# Ver endpoints (pods detrás del servicio)
kubectl get endpoints -n blackfriday

# Probar conexión interna
kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -n blackfriday -- \
  curl http://api-rust-service:3000/productos
```

### ConfigMap no aplicado

```bash
# Verificar ConfigMap
kubectl get configmap nginx-config -n blackfriday -o yaml

# Reiniciar pods para cargar nueva configuración
kubectl rollout restart deployment nginx-proxy -n blackfriday
```

## 🧹 Limpieza

### Eliminar recursos específicos

```bash
kubectl delete -f 07-nginx-proxy.yaml
kubectl delete -f 06-api-rust.yaml
```

### Limpieza completa

```bash
./cleanup.sh
```

### Reiniciar Minikube

```bash
minikube stop
minikube delete
minikube start --driver=docker
```

## 📚 Recursos Adicionales

- [Guía Completa de Nginx en K8s](../NGINX_K8S_GUIDE.md)
- [Quick Start de Nginx](../NGINX_K8S_QUICKSTART.md)
- [Setup de Kubernetes](../KUBERNETES_SETUP.md)
- [Documentación de Arquitectura](../ARCHITECTURE.md)

## 💡 Tips de Desarrollo

1. **Usar contexto de namespace:**

   ```bash
   kubectl config set-context --current --namespace=blackfriday
   # Ahora no necesitas -n blackfriday en cada comando
   ```

2. **Aliases útiles:**

   ```bash
   alias k='kubectl'
   alias kgp='kubectl get pods'
   alias kgs='kubectl get svc'
   alias kga='kubectl get all'
   ```

3. **Ver todos los recursos de un tipo:**

   ```bash
   kubectl api-resources  # Lista todos los tipos de recursos
   ```

4. **Debugging interactivo:**

   ```bash
   # Iniciar un pod temporal para debugging
   kubectl run debug --image=nicolaka/netshoot -i --rm --restart=Never -n blackfriday -- bash
   ```

5. **Exportar manifiestos actuales:**
   ```bash
   kubectl get deployment nginx-proxy -n blackfriday -o yaml > nginx-current.yaml
   ```

## 🎯 Checklist de Verificación Post-Despliegue

- [ ] Todos los pods están en estado `Running`
- [ ] Todos los servicios tienen endpoints
- [ ] Nginx responde en http://localhost:30300/health
- [ ] API Rust responde a través de nginx
- [ ] Kafka está recibiendo mensajes
- [ ] gRPC servers están procesando peticiones
- [ ] No hay errores en los logs
- [ ] Métricas de recursos están dentro de límites

## 📞 Soporte

Para problemas o preguntas:

1. Revisa los logs: `kubectl logs -f <pod-name> -n blackfriday`
2. Verifica eventos: `kubectl get events -n blackfriday`
3. Consulta la documentación en el directorio raíz
4. Ejecuta `./status.sh` para ver el estado completo
