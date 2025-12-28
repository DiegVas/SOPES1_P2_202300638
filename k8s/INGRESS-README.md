# Ingress Controller - Guía de Uso

Este documento explica cómo usar el Ingress Controller implementado en el proyecto.

## 📋 Componentes

- **NGINX Ingress Controller**: Controlador principal que gestiona el tráfico de entrada
- **Ingress Resources**: Configuración de rutas y reglas de enrutamiento
- **Scripts de despliegue**: Automatización de la instalación y configuración

## 🚀 Instalación Rápida

### Opción 1: Instalación completa (recomendado)

```bash
cd k8s
./deploy-ingress.sh
```

Este script automáticamente:

- Verifica si el Ingress Controller está instalado
- Instala el controlador si es necesario
- Aplica las reglas de Ingress
- Muestra la información de acceso

### Opción 2: Instalación manual

1. **Instalar el Ingress Controller:**

   ```bash
   ./install-ingress-controller.sh
   ```

2. **Aplicar las reglas de Ingress:**
   ```bash
   kubectl apply -f 15-ingress.yaml
   ```

## 🌐 Rutas Disponibles

### Usando el dominio principal (blackfriday.local)

| Ruta       | Servicio            | Puerto | Descripción                  |
| ---------- | ------------------- | ------ | ---------------------------- |
| `/`        | nginx-proxy-service | 80     | API Rust (a través de NGINX) |
| `/api/go`  | go-api-rest-service | 8080   | Go API REST                  |
| `/grafana` | grafana-service     | 3000   | Panel de Grafana             |
| `/locust`  | locust-service      | 8089   | Interfaz de Locust           |

### Usando subdominios (opcional)

| Dominio                     | Servicio         | Descripción                |
| --------------------------- | ---------------- | -------------------------- |
| `api.blackfriday.local`     | api-rust-service | API Rust directa           |
| `grafana.blackfriday.local` | grafana-service  | Grafana con dominio propio |
| `locust.blackfriday.local`  | locust-service   | Locust con dominio propio  |

## ⚙️ Configuración

### Configurar /etc/hosts

Para acceder usando nombres de dominio, agrega las siguientes entradas a tu archivo `/etc/hosts`:

```bash
# Obtener la IP del nodo
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Agregar al /etc/hosts
echo "$NODE_IP blackfriday.local" | sudo tee -a /etc/hosts
echo "$NODE_IP api.blackfriday.local" | sudo tee -a /etc/hosts
echo "$NODE_IP grafana.blackfriday.local" | sudo tee -a /etc/hosts
echo "$NODE_IP locust.blackfriday.local" | sudo tee -a /etc/hosts
```

O manualmente edita `/etc/hosts`:

```
<NODE_IP> blackfriday.local api.blackfriday.local grafana.blackfriday.local locust.blackfriday.local
```

### Obtener la IP y puerto de acceso

```bash
# Para NodePort
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Ver el puerto HTTP (normalmente 80 o 30000+)
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'
```

## 🔍 Verificación

### Verificar el estado del Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Verificar las reglas de Ingress

```bash
kubectl get ingress -n blackfriday
kubectl describe ingress blackfriday-ingress -n blackfriday
```

### Probar los endpoints

```bash
# Obtener el puerto del Ingress
INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Probar la API principal
curl http://$NODE_IP:$INGRESS_PORT/

# Probar la Go API
curl http://$NODE_IP:$INGRESS_PORT/api/go

# O usando el dominio (si está configurado en /etc/hosts)
curl http://blackfriday.local:$INGRESS_PORT/
```

## 📊 Características del Ingress

### Anotaciones configuradas

- **rewrite-target**: Reescritura de rutas para compatibilidad
- **ssl-redirect**: Deshabilitado (configurable para HTTPS)
- **use-regex**: Soporte para expresiones regulares en rutas
- **proxy-body-size**: Límite de 10MB para el cuerpo de las peticiones
- **timeouts**: 60 segundos para conexión, envío y lectura

### Balanceo de carga

El Ingress Controller automáticamente balancea la carga entre las réplicas de cada servicio:

- nginx-proxy: 2 réplicas
- api-rust: 2 réplicas
- go-api-rest: 2 réplicas

## 🔧 Troubleshooting

### El Ingress Controller no arranca

```bash
# Ver los logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Reinstalar
kubectl delete namespace ingress-nginx
./install-ingress-controller.sh
```

### No puedo acceder a los servicios

```bash
# Verificar que los servicios estén corriendo
kubectl get svc -n blackfriday

# Verificar el Ingress
kubectl get ingress -n blackfriday

# Verificar los endpoints
kubectl get endpoints -n blackfriday

# Ver logs del Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Error 404 o 503

```bash
# Verificar que los backends estén saludables
kubectl get pods -n blackfriday

# Verificar el Ingress
kubectl describe ingress blackfriday-ingress -n blackfriday

# Verificar las reglas
kubectl get ingress blackfriday-ingress -n blackfriday -o yaml
```

## 🔄 Actualización

Para actualizar la configuración del Ingress:

```bash
# Editar el archivo
nano 15-ingress.yaml

# Aplicar los cambios
kubectl apply -f 15-ingress.yaml

# Verificar
kubectl describe ingress blackfriday-ingress -n blackfriday
```

## 🛡️ Seguridad (Próximos pasos)

Para habilitar HTTPS:

1. Instalar cert-manager
2. Configurar certificados (Let's Encrypt o self-signed)
3. Actualizar las anotaciones del Ingress
4. Habilitar ssl-redirect

## 📝 Notas

- El Ingress Controller usa NodePort por defecto (compatible con Minikube y la mayoría de entornos)
- En entornos cloud con LoadBalancer, se asignará automáticamente una IP externa
- Los timeouts están configurados para 60 segundos, ajustables según necesidades
- El proxy-body-size está limitado a 10MB, ajustable para cargas mayores
