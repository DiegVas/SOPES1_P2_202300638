# 🏗️ Arquitectura de Dos Capas de NGINX

## 📊 Diagrama de Flujo

```
Internet/Cliente
      ↓
[NGINX Ingress Controller] ← Capa 1: Punto de entrada del cluster
      ↓
      ├─→ /              → [NGINX Proxy] → [API Rust Service] ← Capa 2: Proxy interno
      ├─→ /api/go        → [Go API REST Service] (directo)
      ├─→ /grafana       → [Grafana Service] (directo)
      └─→ /locust        → [Locust Service] (directo)
```

## 🎯 Responsabilidades de Cada Capa

### Capa 1: NGINX Ingress Controller

**Ubicación**: Namespace `ingress-nginx`  
**Función**: Punto de entrada del cluster

**Responsabilidades:**

- ✅ Enrutamiento basado en host/path
- ✅ Terminación SSL/TLS (cuando se configure)
- ✅ Balanceo de carga entre réplicas
- ✅ Rate limiting global
- ✅ Gestión de certificados
- ✅ Logging centralizado de entrada
- ✅ Headers de forwarding (X-Forwarded-For, etc.)

**Configuración:**

- Keep-alive connections: 100 conexiones
- Timeouts: 60 segundos
- Buffer size: 8k
- Proxy buffering: activado

### Capa 2: NGINX Proxy (Interno)

**Ubicación**: Namespace `blackfriday` (Deployment: `nginx-proxy`)  
**Función**: Proxy específico para API Rust

**Responsabilidades:**

- ✅ Upstream específico a `api-rust-service`
- ✅ Health checks del backend
- ✅ Fail-over entre réplicas de Rust API (max_fails=3)
- ✅ Buffering optimizado para respuestas Rust
- ✅ Headers específicos de la aplicación
- ✅ Endpoint `/health` propio

**Configuración:**

- Worker connections: 1024
- Max fails: 3
- Fail timeout: 30s
- Timeouts: 60 segundos (alineado con Ingress)
- 2 réplicas con recursos limitados

## 💡 Ventajas de Esta Arquitectura

### 1. **Separación de Responsabilidades**

- **Ingress Controller**: Maneja la entrada al cluster (infraestructura)
- **NGINX Proxy**: Maneja lógica específica de la aplicación Rust

### 2. **Flexibilidad**

- Puedes agregar caching en el NGINX Proxy sin afectar otros servicios
- Configuración independiente por servicio
- Rate limiting específico por aplicación

### 3. **Resiliencia**

- Doble capa de health checks
- Fail-over configurado específicamente para API Rust
- Aislamiento de fallos

### 4. **Observabilidad**

- Logs en dos niveles
- Métricas separadas por capa
- Identificación clara de problemas (¿es el Ingress o el proxy?)

### 5. **Escalabilidad**

- NGINX Proxy puede escalar independientemente
- Optimización específica para el tráfico Rust
- No impacta otros servicios

## 🔄 Flujo de una Petición

### Ejemplo: `GET http://blackfriday.local/productos`

```
1. Cliente → Ingress Controller (puerto 80 o HTTPS)
   Headers añadidos:
   - X-Forwarded-For: <client-ip>
   - X-Forwarded-Host: blackfriday.local
   - X-Ingress-Controller: nginx
   - X-Layer: ingress-controller

2. Ingress Controller → nginx-proxy-service:80
   - Selecciona una de las 2 réplicas
   - Mantiene keep-alive connection
   - Buffers activados

3. NGINX Proxy → api-rust-service:3000
   - Upstream: api_rust_backend
   - Health check previo
   - Selecciona pod healthy
   - Headers adicionales:
     - X-Real-IP
     - X-Forwarded-For (preservado)
     - X-Forwarded-Proto

4. API Rust procesa la petición
   - Lee headers de contexto
   - Genera respuesta

5. Respuesta: API Rust → NGINX Proxy → Ingress → Cliente
   - Buffering en ambas capas
   - Compresión (si está habilitada)
   - Headers de respuesta
```

## 🔧 Configuración de Timeouts

Ambas capas están **sincronizadas** en 60 segundos:

| Timeout | Ingress Controller | NGINX Proxy |
| ------- | ------------------ | ----------- |
| Connect | 60s                | 60s         |
| Send    | 60s                | 60s         |
| Read    | 60s                | 60s         |

**Importante**: Si necesitas ajustar timeouts, hazlo en ambas capas para evitar desincronización.

## 🚀 Servicios con Acceso Directo

Algunos servicios **no pasan** por el NGINX Proxy:

```
/api/go   → go-api-rest-service:8080 (directo)
/grafana  → grafana-service:3000 (directo)
/locust   → locust-service:8089 (directo)
```

**Razón**: Estos servicios no necesitan la lógica adicional del proxy interno.

## 📝 Archivos de Configuración

### Ingress Controller

- **Instalación**: `install-ingress-controller.sh`
- **Configuración**: `15-ingress.yaml`
- **Namespace**: `ingress-nginx`

### NGINX Proxy

- **Configuración**: `07-nginx-proxy.yaml`
- **ConfigMap**: `nginx-config` (ConfigMap)
- **Namespace**: `blackfriday`

## 🔍 Monitoreo y Debugging

### Ver logs del Ingress Controller

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f
```

### Ver logs del NGINX Proxy

```bash
kubectl logs -n blackfriday deployment/nginx-proxy -f
```

### Ver métricas del Ingress

```bash
kubectl get --raw /metrics -n ingress-nginx
```

### Verificar conectividad entre capas

```bash
# Desde un pod, probar el nginx-proxy
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n blackfriday -- \
  curl http://nginx-proxy-service/health

# Probar la API Rust directa
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n blackfriday -- \
  curl http://api-rust-service:3000/productos
```

## 🎛️ Optimizaciones Configuradas

### Keep-Alive Connections

```yaml
nginx.ingress.kubernetes.io/upstream-keepalive-connections: "100"
nginx.ingress.kubernetes.io/upstream-keepalive-timeout: "60"
```

**Beneficio**: Reduce latencia al reutilizar conexiones TCP

### Buffering Optimizado

```yaml
nginx.ingress.kubernetes.io/proxy-buffering: "on"
nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
nginx.ingress.kubernetes.io/proxy-buffers-number: "8"
```

**Beneficio**: Mejor manejo de respuestas grandes

### Health Checks

- **Ingress**: Verifica disponibilidad de nginx-proxy
- **NGINX Proxy**: Verifica disponibilidad de api-rust (fail_timeout=30s)

## 📈 Cuándo Considerar Simplificar

Considera **eliminar** el NGINX Proxy si:

- ❌ No necesitas lógica específica de aplicación
- ❌ No requieres caching customizado
- ❌ No necesitas transformaciones de request/response
- ❌ Quieres reducir latencia al mínimo

En ese caso, el Ingress Controller puede apuntar directamente a `api-rust-service`.

## ✅ Cuándo Mantener Dos Capas

Mantén esta arquitectura si:

- ✅ Necesitas rate limiting específico por API
- ✅ Quieres caching en el proxy interno
- ✅ Requieres transformaciones de headers/body
- ✅ Necesitas fail-over específico con lógica custom
- ✅ Quieres aislar la configuración de infraestructura vs aplicación
- ✅ Planeas agregar WAF o seguridad adicional en el proxy

## 🔐 Futuras Mejoras

1. **SSL/TLS en Ingress Controller**

   - Instalar cert-manager
   - Configurar Let's Encrypt
   - Agregar redirección HTTPS

2. **Caching en NGINX Proxy**

   - Agregar proxy_cache_path
   - Configurar cache keys
   - Headers de cache

3. **Rate Limiting Granular**

   - Por IP en Ingress
   - Por endpoint en NGINX Proxy

4. **Métricas y Dashboards**

   - Exportar métricas de ambos NGINX
   - Dashboard en Grafana
   - Alertas de latencia

5. **WAF (Web Application Firewall)**
   - ModSecurity en NGINX Proxy
   - Reglas OWASP

---

**Última actualización**: 27 de diciembre de 2025  
**Mantenedor**: Sistema de despliegue Black Friday
