# Nginx como Proxy Reverso para la API de Rust

Este proyecto implementa nginx como intermediario (proxy reverso) para la API de Rust.

## 📋 Estructura

```
nginx/
├── Dockerfile          # Imagen de nginx con configuración personalizada
└── nginx.conf         # Configuración de nginx
```

## 🚀 Características

- **Proxy Reverso**: nginx actúa como intermediario entre los clientes y la API de Rust
- **Balanceo de Carga**: Preparado para múltiples instancias de la API
- **Health Check**: Endpoint `/health` para verificar el estado del proxy
- **Headers**: Mantiene información del cliente original (IP real, forwarded headers)
- **Timeouts**: Configurados para manejar solicitudes de larga duración
- **Buffering**: Optimizado para mejorar el rendimiento

## 🐳 Docker Compose

La configuración está lista en `docker-compose.yml`:

```yaml
nginx:
  build:
    context: ./nginx
  ports:
    - "3000:80" # Puerto externo 3000 → nginx:80 → api-rust:3000
```

### Iniciar servicios

```bash
# Construir e iniciar todos los servicios
docker-compose up -d

# Ver logs de nginx
docker-compose logs -f nginx

# Ver logs de la API de Rust
docker-compose logs -f api-rust
```

## ☸️ Kubernetes

Para Kubernetes, se incluye la configuración en `k8s/06-nginx-proxy.yaml`:

```bash
# Aplicar configuración
kubectl apply -f k8s/06-nginx-proxy.yaml

# Ver estado
kubectl get pods -n sopes1 -l app=nginx-proxy
kubectl get svc -n sopes1 nginx-proxy-service

# Ver logs
kubectl logs -n sopes1 -l app=nginx-proxy
```

## 🧪 Pruebas

### Health Check

```bash
curl http://localhost:3000/health
```

### Probar endpoints de la API a través de nginx

```bash
# Obtener productos
curl http://localhost:3000/productos

# Realizar compra
curl -X POST http://localhost:3000/comprar \
  -H "Content-Type: application/json" \
  -d '{
    "producto_id": "prod001",
    "cantidad": 2
  }'
```

## 📊 Monitoreo

### Logs de nginx

```bash
# Docker Compose
docker-compose exec nginx tail -f /var/log/nginx/access.log
docker-compose exec nginx tail -f /var/log/nginx/error.log

# Kubernetes
kubectl logs -n sopes1 -l app=nginx-proxy -f
```

## ⚙️ Configuración

La configuración principal está en `nginx/nginx.conf`:

- **Upstream**: Define el backend (api-rust:3000)
- **Proxy Settings**: Headers, timeouts, buffering
- **Health Check**: Endpoint dedicado para verificar estado
- **Logging**: Access log y error log configurados

### Personalización

Para modificar la configuración:

1. Edita `nginx/nginx.conf`
2. Reconstruye la imagen:
   ```bash
   docker-compose up -d --build nginx
   ```

## 🔒 Ventajas de usar nginx

1. **Seguridad**: Oculta la implementación interna de la API
2. **Rendimiento**: Caching y buffering optimizados
3. **Escalabilidad**: Facilita el balanceo de carga
4. **Flexibilidad**: Fácil agregar SSL/TLS, rate limiting, etc.
5. **Monitoreo**: Logs centralizados del tráfico

## 📝 Notas

- El puerto 3000 de la API de Rust ya no está expuesto directamente
- Todo el tráfico pasa ahora a través de nginx en el puerto 3000
- La API sigue funcionando internamente en el puerto 3000
- nginx escucha en el puerto 80 y reenvía a api-rust:3000
