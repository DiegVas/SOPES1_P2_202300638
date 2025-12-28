# Despliegue en EC2 - Stack Black Friday

## 🚀 Guía de Despliegue Rápida

### Información de las Instancias

- **Instancia Zot (Registro de Imágenes)**: `3.129.65.122:30000`
- **Instancia de Despliegue (EC2)**: `18.220.40.168`

## 📋 Pre-requisitos

1. Tener acceso SSH a la instancia EC2 de despliegue
2. Kubernetes instalado (kubectl, K3s, o MicroK8s)
3. El registro Zot debe estar funcionando en `3.129.65.122:30000`

## 🏥 Paso 0: Verificar el Sistema (NUEVO)

**Antes de comenzar, ejecuta el script de diagnóstico:**

```bash
# Conectar a la instancia EC2
ssh ubuntu@18.220.40.168

# Ir al directorio de despliegue
cd ~/EC2_yaml

# Ejecutar diagnóstico
./check-kubernetes.sh
```

Este script verificará:

- ✅ Si Kubernetes está instalado y funcionando
- ✅ Estado del servicio (kubelet/k3s/microk8s)
- ✅ Conectividad del cluster
- ✅ Permisos necesarios
- ✅ Configuración del registro inseguro

**Si el diagnóstico muestra errores, corrígelos antes de continuar.**

### Problemas Comunes y Soluciones

#### Error: "TLS handshake timeout" o cluster no responde

**Causa**: Kubernetes no está funcionando correctamente.

**Solución para K3s** (recomendado en EC2):

```bash
# Verificar estado
sudo systemctl status k3s

# Si no está instalado, instalar K3s
curl -sfL https://get.k3s.io | sh -

# Iniciar K3s
sudo systemctl start k3s
sudo systemctl enable k3s

# Configurar permisos
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Verificar que funciona
k3s kubectl get nodes
```

**Solución para kubectl/kubeadm**:

```bash
# Verificar estado
sudo systemctl status kubelet

# Reiniciar si es necesario
sudo systemctl restart kubelet

# Ver logs
sudo journalctl -xeu kubelet -f
```

## 🔧 Paso 1: Configurar Registro Inseguro

**IMPORTANTE**: Este paso debe ejecutarse PRIMERO en la instancia EC2 de despliegue.

```bash
# Conectar a la instancia EC2
ssh usuario@18.220.40.168

# Ejecutar el script de configuración
sudo ./configure-insecure-registry.sh
```

Este script:

- Configura Docker para permitir el registro inseguro (HTTP)
- Configura containerd si estás usando K3s
- Reinicia los servicios necesarios
- Verifica la conectividad con el registro Zot

### Verificar la Configuración

```bash
# Verificar que Docker reconoce el registro inseguro
docker info | grep -A5 'Insecure Registries'

# Probar conexión con Zot
curl http://3.129.65.122:30000/v2/

# Probar descarga de una imagen
docker pull 3.129.65.122:30000/nginx:alpine
```

## 🚀 Paso 2: Desplegar la Aplicación

```bash
# Ejecutar el script de despliegue (ya no requiere sudo en K3s)
./deploy-ec2.sh
```

El script realizará:

1. ✅ Detección automática del tipo de Kubernetes (kubectl/k3s/microk8s)
2. ✅ Verificación de que el cluster está funcionando
3. ✅ Verificación de conectividad con Zot
4. ✅ Creación del namespace `blackfriday`
5. ✅ Limpieza de recursos previos
6. ✅ Despliegue de infraestructura (Zookeeper, Kafka, Valkey)
7. ✅ Despliegue de microservicios (gRPC, APIs, Consumer)
8. ✅ Despliegue de herramientas (Nginx, Locust, Grafana)
9. ✅ Verificación del estado de todos los pods

## 📊 Acceso a Servicios

Una vez desplegado, puedes acceder a:

- **Grafana**: http://18.220.40.168:32000
- **Locust**: http://18.220.40.168:30089
- **API Go**: http://18.220.40.168:30080
- **Nginx**: http://18.220.40.168:30081

## 🔍 Diagnóstico de Problemas

### Problema: ImagePullBackOff o ErrImagePull

**Causa**: Los nodos de Kubernetes no pueden descargar imágenes del registro Zot.

**Solución**:

```bash
# 1. Verificar que el script de configuración se ejecutó
sudo cat /etc/docker/daemon.json

# 2. Verificar conectividad con Zot
curl http://3.129.65.122:30000/v2/

# 3. Si falla, re-ejecutar la configuración
sudo ./configure-insecure-registry.sh

# 4. Verificar que las imágenes existen en Zot
curl http://3.129.65.122:30000/v2/_catalog
```

### Problema: Pods en estado Pending

**Causa**: Falta de recursos o problemas de scheduling.

**Solución**:

```bash
# Ver eventos del pod
kubectl describe pod <pod-name> -n blackfriday

# Ver recursos disponibles
kubectl top nodes
kubectl top pods -n blackfriday
```

### Problema: Pods en ContainerCreating por mucho tiempo

**Causa**: Puede ser problema de red o descarga lenta.

**Solución**:

```bash
# Ver eventos detallados
kubectl get events -n blackfriday --sort-by='.lastTimestamp'

# Ver logs del pod
kubectl logs <pod-name> -n blackfriday
```

## 🛠️ Comandos Útiles

```bash
# Ver estado de todos los pods
kubectl get pods -n blackfriday -o wide

# Ver logs de un pod específico
kubectl logs -f <pod-name> -n blackfriday

# Describir un pod (ver eventos y configuración)
kubectl describe pod <pod-name> -n blackfriday

# Reiniciar un deployment
kubectl rollout restart deployment <deployment-name> -n blackfriday

# Ver servicios
kubectl get svc -n blackfriday

# Eliminar todos los pods (se recrearán automáticamente)
kubectl delete pods --all -n blackfriday

# Ver uso de recursos
kubectl top pods -n blackfriday
kubectl top nodes
```

## 🔄 Re-desplegar Después de Cambios

Si hiciste cambios en las imágenes en Zot:

```bash
# Opción 1: Re-desplegar todo
sudo ./deploy-ec2.sh

# Opción 2: Reiniciar deployments específicos
kubectl rollout restart deployment api-rust -n blackfriday
kubectl rollout restart deployment go-api-rest -n blackfriday
kubectl rollout restart deployment nginx-proxy -n blackfriday
```

## 📦 Imágenes Requeridas en Zot

Asegúrate de que estas imágenes estén disponibles en `3.129.65.122:30000`:

- `rust-api:latest`
- `go-api-rest:latest`
- `grpc-server:latest`
- `kafka-consumer:latest`
- `locust:latest`
- `nginx:alpine`

Para verificar:

```bash
curl http://3.129.65.122:30000/v2/_catalog
```

## 🆘 Solución de Problemas Comunes

### Error: "x509: certificate signed by unknown authority"

Esto significa que el registro inseguro no está configurado correctamente.

**Solución**: Re-ejecutar `configure-insecure-registry.sh`

### Error: "connection refused" al acceder a Zot

Verifica:

1. Que el servidor Zot está funcionando: `ssh a 3.129.65.122` y verificar
2. Que el firewall permite el puerto 30000
3. Que la IP es accesible desde la instancia EC2

```bash
# Desde la instancia EC2 de despliegue
telnet 3.129.65.122 30000
```

## 📝 Notas Importantes

1. **Registro HTTP (no HTTPS)**: El registro Zot está configurado como inseguro (HTTP). En producción, considera usar HTTPS con certificados.

2. **Reinicio de Docker**: Configurar el registro inseguro requiere reiniciar Docker, lo que puede afectar otros contenedores en ejecución.

3. **Persistencia**: La configuración del registro inseguro persiste después de reinicios del sistema.

4. **Imágenes de Terceros**: Las imágenes como Kafka, Zookeeper, Valkey y Grafana se descargan directamente de DockerHub ya que son imágenes públicas oficiales.

## 🔐 Seguridad

Para un entorno de producción, considera:

1. Usar HTTPS en el registro Zot
2. Implementar autenticación para el registro
3. Usar ImagePullSecrets en Kubernetes
4. Limitar el acceso al registro con firewall
