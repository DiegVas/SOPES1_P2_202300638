# 🗄️ Zot Registry - Container Registry OCI

## ¿Qué es Zot?

**Zot** es un registry de contenedores OCI (Open Container Initiative) de código abierto, compatible con Docker Registry API v2. Proporciona una solución ligera y eficiente para almacenar y distribuir imágenes de contenedores.

### Características

- ✅ **100% Compatible con OCI**: Funciona con Docker, Podman, y otras herramientas OCI
- ✅ **API REST Completa**: Compatible con Docker Registry HTTP API V2
- ✅ **Lightweight**: Bajo consumo de recursos
- ✅ **Almacenamiento Persistente**: Usa PersistentVolume en Kubernetes
- ✅ **Sin Autenticación** (configurado para desarrollo): Acceso directo y simple

## 📦 Arquitectura en el Proyecto

```
┌─────────────────────────────────────────────────┐
│           Kubernetes Cluster (Minikube)         │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  Zot Registry Pod                       │    │
│  │  ┌─────────────────────────────────┐   │    │
│  │  │  Container: zot                  │   │    │
│  │  │  Port: 5000                      │   │    │
│  │  │  Image: ghcr.io/project-zot/... │   │    │
│  │  └─────────────────────────────────┘   │    │
│  │                                          │    │
│  │  Volumes:                                │    │
│  │  - ConfigMap: zot-config                │    │
│  │  - PVC: zot-storage (10Gi)              │    │
│  └────────────────────────────────────────┘    │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  Service: zot-service                   │    │
│  │  Type: NodePort                         │    │
│  │  Port: 5000 → NodePort: 30500          │    │
│  └────────────────────────────────────────┘    │
│                                                  │
│  Acceso Externo: http://<minikube-ip>:30500    │
└─────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Desplegar Zot Registry

```bash
# Despliegue completo (Zot + construcción + push de imágenes)
./setup-zot.sh
```

Este script:

1. Despliega Zot en Kubernetes
2. Configura Docker para usar el registry inseguro
3. Construye todas las imágenes del proyecto
4. Tagea las imágenes con el prefijo de Zot
5. Pushea todas las imágenes a Zot

### 2. Verificar Instalación

```bash
# Estado del pod
kubectl get pods -n blackfriday -l app=zot-registry

# Estado del servicio
kubectl get svc -n blackfriday zot-service

# Probar conectividad
MINIKUBE_IP=$(minikube ip)
curl http://${MINIKUBE_IP}:30500/v2/

# Ver catálogo de imágenes
curl http://${MINIKUBE_IP}:30500/v2/_catalog | jq '.'
```

### 3. Actualizar Deployments

```bash
# Actualizar todos los deployments para usar Zot Registry
./update-deployments-zot.sh
```

## 📋 Gestión de Imágenes

### CLI de Zot (`zot-cli.sh`)

```bash
# Ver ayuda
./zot-cli.sh help

# Listar todas las imágenes
./zot-cli.sh list

# Ver tags de una imagen
./zot-cli.sh tags rust-api

# Verificar salud del registry
./zot-cli.sh health

# Ver catálogo completo (JSON)
./zot-cli.sh catalog
```

### Operaciones Manuales con Docker

```bash
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

# Configurar entorno Docker
eval $(minikube docker-env)

# Construir una imagen
docker build -t mi-app:latest .

# Tagear para Zot
docker tag mi-app:latest ${ZOT_REGISTRY}/mi-app:latest

# Pushear a Zot
docker push ${ZOT_REGISTRY}/mi-app:latest

# Pullear desde Zot
docker pull ${ZOT_REGISTRY}/mi-app:latest

# Listar imágenes locales
docker images | grep ${MINIKUBE_IP}
```

## 🔄 Workflow de Desarrollo

### Actualizar una Imagen Individual

```bash
# Ejemplo: Actualizar kafka-consumer con Zap logger

# 1. Configurar Docker
eval $(minikube docker-env)
MINIKUBE_IP=$(minikube ip)
ZOT_REGISTRY="${MINIKUBE_IP}:30500"

# 2. Construir nueva versión
cd kafka-consumer
docker build -t kafka-consumer:latest .

# 3. Tagear y pushear a Zot
docker tag kafka-consumer:latest ${ZOT_REGISTRY}/kafka-consumer:latest
docker push ${ZOT_REGISTRY}/kafka-consumer:latest

# 4. Reiniciar deployment
kubectl rollout restart deployment kafka-consumer -n blackfriday

# 5. Verificar actualización
kubectl rollout status deployment kafka-consumer -n blackfriday
kubectl logs -f -n blackfriday -l app=kafka-consumer
```

### Rebuild Completo

```bash
# Reconstruir todas las imágenes y actualizar
./setup-zot.sh
./update-deployments-zot.sh
```

## 🔍 API de Zot Registry

### Endpoints Principales

```bash
MINIKUBE_IP=$(minikube ip)
BASE_URL="http://${MINIKUBE_IP}:30500"

# Health check (debe devolver {})
curl ${BASE_URL}/v2/

# Listar repositorios
curl ${BASE_URL}/v2/_catalog

# Listar tags de una imagen
curl ${BASE_URL}/v2/<image-name>/tags/list

# Obtener manifest de una imagen
curl ${BASE_URL}/v2/<image-name>/manifests/<tag>

# Ejemplos con imágenes del proyecto
curl ${BASE_URL}/v2/rust-api/tags/list | jq '.'
curl ${BASE_URL}/v2/kafka-consumer/tags/list | jq '.'
curl ${BASE_URL}/v2/grpc-server/tags/list | jq '.'
```

### Formato de Respuestas

**Catálogo:**

```json
{
  "repositories": [
    "rust-api",
    "go-api-rest",
    "grpc-server",
    "kafka-consumer",
    "locust",
    "nginx-proxy"
  ]
}
```

**Tags:**

```json
{
  "name": "rust-api",
  "tags": ["latest"]
}
```

## 🛠️ Configuración

### ConfigMap (zot-config)

```yaml
{
  "distSpecVersion": "1.1.0",
  "storage": { "rootDirectory": "/var/lib/registry" },
  "http": { "address": "0.0.0.0", "port": "5000" },
  "log": { "level": "info", "output": "/tmp/zot.log" },
}
```

### Almacenamiento Persistente

- **PVC**: `zot-storage`
- **Tamaño**: 10Gi
- **Access Mode**: ReadWriteOnce
- **Path**: `/var/lib/registry` dentro del contenedor

## 🐛 Troubleshooting

### Zot no responde

```bash
# Verificar estado del pod
kubectl get pods -n blackfriday -l app=zot-registry

# Ver logs
kubectl logs -n blackfriday -l app=zot-registry

# Ver eventos
kubectl get events -n blackfriday | grep zot

# Reiniciar deployment
kubectl rollout restart deployment zot-registry -n blackfriday
```

### Error al pushear imágenes

```bash
# Verificar que Docker está configurado para registry inseguro
minikube ssh "cat /etc/docker/daemon.json"

# Debe contener:
# {"insecure-registries": ["<minikube-ip>:30500"]}

# Si no, ejecutar:
minikube ssh "sudo mkdir -p /etc/docker"
minikube ssh "echo '{\"insecure-registries\": [\"$(minikube ip):30500\"]}' | sudo tee /etc/docker/daemon.json"
minikube ssh "sudo systemctl restart docker"
```

### Imágenes no aparecen en catálogo

```bash
# Verificar que las imágenes se pushearon correctamente
docker images | grep $(minikube ip)

# Verificar logs de Zot durante el push
kubectl logs -n blackfriday -l app=zot-registry --tail=50

# Listar contenido del PV directamente
kubectl exec -n blackfriday $(kubectl get pod -n blackfriday -l app=zot-registry -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/lib/registry
```

### Deployment no puede pullear imágenes

```bash
# Verificar que el deployment tiene la imagen correcta
kubectl get deployment <deployment-name> -n blackfriday -o yaml | grep image:

# Debe ser: image: <minikube-ip>:30500/<image-name>:latest

# Verificar que imagePullPolicy está configurado
kubectl get deployment <deployment-name> -n blackfriday -o yaml | grep imagePullPolicy

# Debe ser: imagePullPolicy: Always

# Ver eventos del pod
kubectl describe pod <pod-name> -n blackfriday
```

## 📊 Monitoreo

### Verificar uso de almacenamiento

```bash
# Ver tamaño del PVC
kubectl get pvc zot-storage -n blackfriday

# Ver uso dentro del pod
kubectl exec -n blackfriday $(kubectl get pod -n blackfriday -l app=zot-registry -o jsonpath='{.items[0].metadata.name}') -- df -h /var/lib/registry

# Listar imágenes almacenadas
kubectl exec -n blackfriday $(kubectl get pod -n blackfriday -l app=zot-registry -o jsonpath='{.items[0].metadata.name}') -- du -sh /var/lib/registry/*
```

### Logs en tiempo real

```bash
# Ver logs de Zot
kubectl logs -f -n blackfriday -l app=zot-registry

# Ver logs del archivo interno
kubectl exec -n blackfriday $(kubectl get pod -n blackfriday -l app=zot-registry -o jsonpath='{.items[0].metadata.name}') -- tail -f /tmp/zot.log
```

## 🔐 Seguridad (Producción)

Para entornos de producción, considera:

1. **Autenticación**: Agregar autenticación básica o LDAP
2. **TLS/HTTPS**: Configurar certificados SSL
3. **RBAC**: Implementar control de acceso basado en roles
4. **Scanning de vulnerabilidades**: Integrar escaneo de imágenes
5. **Backup**: Configurar respaldo del PVC

## 📚 Referencias

- [Proyecto Zot en GitHub](https://github.com/project-zot/zot)
- [OCI Distribution Spec](https://github.com/opencontainers/distribution-spec)
- [Docker Registry HTTP API V2](https://docs.docker.com/registry/spec/api/)

## 🎯 Ventajas en este Proyecto

1. **Desarrollo Local**: No depende de registries externos (Docker Hub, etc.)
2. **Velocidad**: Pull/push de imágenes es instantáneo (local network)
3. **Versionamiento**: Control completo de versiones de imágenes
4. **Testing**: Fácil probar cambios antes de pushear a producción
5. **Reproducibilidad**: Ambiente consistente y aislado
6. **Aprendizaje**: Experiencia con registries OCI reales

---

**Nota**: Esta configuración está optimizada para desarrollo local con Minikube. Para producción, se recomienda agregar autenticación, TLS, y otras medidas de seguridad.
