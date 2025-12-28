# 🚀 Despliegue en EC2 con Ingress Controller

## 📋 Descripción

Este script implementa una arquitectura de dos capas con NGINX Ingress Controller como punto de entrada único para todos los servicios en EC2.

## 🏗️ Arquitectura

```
Internet (Puerto 30080)
         ↓
[NGINX Ingress Controller] ← Punto de entrada único
         ↓
         ├─ /          → [NGINX Proxy] → [API Rust] (2 capas)
         ├─ /api/go    → [Go API REST] (directo)
         ├─ /grafana   → [Grafana] (directo)
         ├─ /locust    → [Locust] (directo)
         └─ /api/rust  → [API Rust] (directo, sin proxy)
```

## ⚙️ Configuración

### Variables en deploy-ec2.sh

```bash
NAMESPACE="blackfriday"
ZOT_IP="18.219.92.152:30000"    # Zot Registry remoto
PUBLIC_IP="13.58.12.224"         # IP pública de tu EC2
```

## 🚀 Instalación

### Paso 1: Dar permisos de ejecución

```bash
chmod +x deploy-ec2.sh
chmod +x EC2_yaml/install-ingress-controller.sh
chmod +x EC2_yaml/verify-ingress.sh
```

### Paso 2: Ejecutar el despliegue

```bash
./deploy-ec2.sh
```

Este script realizará:

1. ✅ Instalación de NGINX Ingress Controller
2. ✅ Creación del namespace `blackfriday`
3. ✅ Actualización automática de referencias de imágenes al Zot remoto
4. ✅ Despliegue de infraestructura (Zookeeper, Kafka, Valkey)
5. ✅ Despliegue de microservicios (gRPC servers, Go API, Rust API)
6. ✅ Despliegue de NGINX Proxy (capa interna)
7. ✅ Despliegue de herramientas (Locust, Grafana)
8. ✅ Configuración de Ingress resources

### Paso 3: Verificar el despliegue

```bash
cd EC2_yaml
./verify-ingress.sh
```

## 🌐 Acceso a los Servicios

### A través del Ingress (Recomendado) - Puerto 30080

Todas las aplicaciones están disponibles en `http://<PUBLIC_IP>:30080`

| Servicio    | URL                                 | Descripción                     |
| ----------- | ----------------------------------- | ------------------------------- |
| API Rust    | `http://<PUBLIC_IP>:30080/`         | API principal (vía NGINX Proxy) |
| Go API      | `http://<PUBLIC_IP>:30080/api/go`   | API Go (acceso directo)         |
| Grafana     | `http://<PUBLIC_IP>:30080/grafana`  | Dashboard de monitoreo          |
| Locust      | `http://<PUBLIC_IP>:30080/locust`   | Herramienta de testing          |
| Rust Direct | `http://<PUBLIC_IP>:30080/api/rust` | API Rust sin proxy              |

### Ejemplo de uso:

```bash
# Obtener productos desde la API Rust
curl http://13.58.12.224:30080/productos

# Crear una compra
curl -X POST http://13.58.12.224:30080/compra \
  -H "Content-Type: application/json" \
  -d '{
    "cliente": "Juan Pérez",
    "productos": ["prod1", "prod2"]
  }'

# Acceder a Go API
curl http://13.58.12.224:30080/api/go/health
```

## 🔍 Verificación

### Ver estado del Ingress Controller

```bash
sudo kubectl get pods -n ingress-nginx
sudo kubectl get svc -n ingress-nginx
```

### Ver recursos de Ingress

```bash
sudo kubectl get ingress -n blackfriday
sudo kubectl describe ingress blackfriday-ingress -n blackfriday
```

### Ver logs del Ingress Controller

```bash
sudo kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f
```

### Ver logs del NGINX Proxy (capa interna)

```bash
sudo kubectl logs -n blackfriday deployment/nginx-proxy -f
```

### Ver estado de todos los pods

```bash
sudo kubectl get pods -n blackfriday
```

## 🔧 Troubleshooting

### El Ingress Controller no arranca

```bash
# Ver logs
sudo kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Reinstalar
sudo kubectl delete namespace ingress-nginx
./EC2_yaml/install-ingress-controller.sh
```

### Error 503 Service Temporarily Unavailable

```bash
# Verificar que los backends estén running
sudo kubectl get pods -n blackfriday

# Verificar el servicio del nginx-proxy
sudo kubectl get svc nginx-proxy-service -n blackfriday

# Verificar que el tipo sea ClusterIP
sudo kubectl get svc nginx-proxy-service -n blackfriday -o jsonpath='{.spec.type}'
```

### Las imágenes no se descargan del Zot remoto

```bash
# Verificar conectividad al Zot
curl http://18.219.92.152:30000/v2/_catalog

# Verificar referencias en los YAMLs
grep -r "image:" k8s/*.yaml

# Verificar ImagePullSecrets si es necesario
sudo kubectl get pods -n blackfriday -o jsonpath='{.items[*].spec.imagePullSecrets}'
```

### Puerto 30080 bloqueado

Asegúrate de que el Security Group de tu EC2 tenga abierto el puerto 30080:

```
Tipo: Custom TCP
Puerto: 30080
Origen: 0.0.0.0/0 (o tu IP específica)
```

## 📊 Características del Ingress

### Configuración aplicada:

- **Timeouts**: 60 segundos (connect, send, read)
- **Body size máximo**: 10MB
- **Keep-alive**: 100 conexiones, timeout 60s
- **Buffering**: Activado (8k buffer size, 8 buffers)
- **SSL Redirect**: Desactivado
- **Regex**: Activado para path matching

### Headers personalizados:

- `X-Forwarded-Host`: Host original
- `X-Ingress-Controller`: "nginx"
- `X-Layer`: "ingress-controller"

## 🔄 Actualizar el Despliegue

### Actualizar un servicio específico

```bash
sudo kubectl apply -f k8s/06-api-rust.yaml -n blackfriday
sudo kubectl rollout restart deployment/api-rust -n blackfriday
```

### Actualizar Ingress

```bash
sudo kubectl apply -f k8s/15-ingress.yaml -n blackfriday
```

### Reiniciar Ingress Controller

```bash
sudo kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
```

## 🛡️ Seguridad

### Recomendaciones:

1. **Usar HTTPS**: Configurar certificados SSL/TLS
2. **Rate Limiting**: Limitar peticiones por IP
3. **Whitelist**: Restringir acceso por IP si es posible
4. **Headers de seguridad**: Agregar X-Frame-Options, CSP, etc.

### Agregar HTTPS (Futuro):

```bash
# Instalar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configurar Let's Encrypt
# Actualizar Ingress con TLS
```

## 📈 Monitoreo

### Métricas del Ingress Controller

```bash
sudo kubectl get --raw /metrics -n ingress-nginx | grep nginx_ingress
```

### Conexiones activas

```bash
sudo kubectl exec -it -n ingress-nginx deployment/ingress-nginx-controller -- curl localhost:10254/nginx_status
```

## 🗑️ Limpieza

### Eliminar el despliegue completo

```bash
sudo kubectl delete namespace blackfriday
sudo kubectl delete namespace ingress-nginx
```

### Solo eliminar Ingress resources

```bash
sudo kubectl delete ingress --all -n blackfriday
```

## 📝 Notas Importantes

1. **Zot Registry Remoto**: Las imágenes se descargan automáticamente desde `18.219.92.152:30000`
2. **Puerto del Ingress**: 30080 (HTTP) y 30443 (HTTPS)
3. **Arquitectura de 2 capas**: El tráfico a `/` pasa por NGINX Proxy antes de llegar a Rust API
4. **Acceso directo disponible**: Usa `/api/rust` para acceder a la API Rust sin el proxy intermedio

## 🔗 Enlaces Útiles

- [NGINX Ingress Controller Docs](https://kubernetes.github.io/ingress-nginx/)
- [Arquitectura de Dos Capas](../ARQUITECTURA-NGINX-DOS-CAPAS.md)
- [Documentación de Ingress](../INGRESS-README.md)

---

**Última actualización**: 27 de diciembre de 2025  
**Configuración**: EC2 con K3s + NGINX Ingress Controller
