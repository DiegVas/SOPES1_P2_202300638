# 🚀 Guía de Despliegue Rápido - EC2

## ⚡ Instalación en 1 Comando

Si es tu primera vez o no tienes Kubernetes instalado:

```bash
./setup-complete.sh
```

Este script hará **TODO** automáticamente:

1. ✅ Instalar K3s si no existe
2. ✅ Configurar el registro inseguro para Zot
3. ✅ Desplegar toda la aplicación

---

## 📋 Instalación Manual (Paso a Paso)

Si prefieres hacerlo manualmente:

### Paso 1: Instalar K3s

```bash
./install-k3s.sh
```

**¿Qué hace?**

- Instala K3s (Kubernetes ligero)
- Configura permisos
- Verifica la instalación

**Tiempo estimado:** 2-3 minutos

### Paso 2: Configurar Registro Inseguro

```bash
sudo ./configure-insecure-registry.sh
```

**¿Qué hace?**

- Configura Docker/containerd para permitir HTTP
- Permite descargar imágenes desde `3.129.65.122:30000`
- Reinicia los servicios necesarios

**Tiempo estimado:** 1 minuto

### Paso 3: Desplegar la Aplicación

```bash
./deploy-ec2.sh
```

**¿Qué hace?**

- Verifica que todo está OK
- Despliega todos los servicios
- Muestra URLs de acceso

**Tiempo estimado:** 5-10 minutos

---

## 🔍 Verificación y Diagnóstico

Para verificar que todo está funcionando:

```bash
./check-kubernetes.sh
```

---

## 📊 Acceso a Servicios

Después del despliegue:

- **Grafana**: http://18.220.40.168:32000
- **Locust**: http://18.220.40.168:30089
- **API Go**: http://18.220.40.168:30080
- **Nginx**: http://18.220.40.168:30081

---

## 🆘 Solución de Problemas

### Error: "kubelet.service not found"

**Causa:** No tienes Kubernetes instalado.

**Solución:**

```bash
./install-k3s.sh
```

### Error: "ImagePullBackOff"

**Causa:** El registro inseguro no está configurado.

**Solución:**

```bash
sudo ./configure-insecure-registry.sh
```

### Error: "TLS handshake timeout"

**Causa:** K3s no está corriendo.

**Solución:**

```bash
sudo systemctl start k3s
sudo systemctl status k3s
```

### Ver logs de un pod

```bash
k3s kubectl logs -f <pod-name> -n blackfriday
```

### Ver todos los pods

```bash
k3s kubectl get pods -n blackfriday
```

### Reiniciar un deployment

```bash
k3s kubectl rollout restart deployment <deployment-name> -n blackfriday
```

---

## 🔄 Redeployar Después de Cambios

Si actualizaste las imágenes en Zot:

```bash
# Opción 1: Re-ejecutar deploy (recomendado)
./deploy-ec2.sh

# Opción 2: Reiniciar deployments específicos
k3s kubectl rollout restart deployment api-rust -n blackfriday
k3s kubectl rollout restart deployment go-api-rest -n blackfriday
```

---

## 📝 Comandos Útiles

```bash
# Ver estado del cluster
k3s kubectl get nodes

# Ver todos los pods
k3s kubectl get pods -A

# Ver pods de blackfriday
k3s kubectl get pods -n blackfriday -o wide

# Ver servicios
k3s kubectl get svc -n blackfriday

# Describir un pod (ver eventos)
k3s kubectl describe pod <pod-name> -n blackfriday

# Ver logs en tiempo real
k3s kubectl logs -f <pod-name> -n blackfriday

# Ejecutar comando dentro de un pod
k3s kubectl exec -it <pod-name> -n blackfriday -- /bin/sh

# Ver uso de recursos
k3s kubectl top pods -n blackfriday
k3s kubectl top nodes

# Eliminar todos los pods (se recrearán)
k3s kubectl delete pods --all -n blackfriday
```

---

## 🗑️ Limpieza Completa

Para eliminar todo y empezar de cero:

```bash
# Eliminar namespace completo
k3s kubectl delete namespace blackfriday

# O desinstalar K3s completamente
sudo /usr/local/bin/k3s-uninstall.sh
```

---

## 📦 Scripts Disponibles

| Script                           | Descripción               | Uso                                     |
| -------------------------------- | ------------------------- | --------------------------------------- |
| `setup-complete.sh`              | Setup automático completo | `./setup-complete.sh`                   |
| `install-k3s.sh`                 | Instalar K3s              | `./install-k3s.sh`                      |
| `configure-insecure-registry.sh` | Configurar registro HTTP  | `sudo ./configure-insecure-registry.sh` |
| `check-kubernetes.sh`            | Diagnóstico del sistema   | `./check-kubernetes.sh`                 |
| `deploy-ec2.sh`                  | Desplegar aplicación      | `./deploy-ec2.sh`                       |

---

## 🎯 Arquitectura

```
┌─────────────────────────────────────────┐
│   Instancia EC2: 18.220.40.168          │
│   ┌─────────────────────────────────┐   │
│   │  K3s Cluster (Kubernetes)       │   │
│   │  ┌─────────────────────────┐    │   │
│   │  │  Namespace: blackfriday │    │   │
│   │  │  - Zookeeper            │    │   │
│   │  │  - Kafka                │    │   │
│   │  │  - Valkey               │    │   │
│   │  │  - gRPC Servers         │    │   │
│   │  │  - Go API REST          │    │   │
│   │  │  - Rust API             │    │   │
│   │  │  - Kafka Consumer       │    │   │
│   │  │  - Nginx Proxy          │    │   │
│   │  │  - Locust               │    │   │
│   │  │  - Grafana              │    │   │
│   │  └─────────────────────────┘    │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
                  ↓ Pull images
┌─────────────────────────────────────────┐
│   Instancia Zot: 3.129.65.122:30000     │
│   (Registro de imágenes Docker)         │
└─────────────────────────────────────────┘
```

---

## ✅ Checklist de Despliegue

- [ ] Conexión SSH a EC2 establecida
- [ ] K3s instalado (`k3s --version`)
- [ ] Registro inseguro configurado
- [ ] Conectividad con Zot verificada (`curl http://3.129.65.122:30000/v2/`)
- [ ] Aplicación desplegada
- [ ] Todos los pods en estado Running
- [ ] Servicios accesibles desde navegador

---

Para más detalles, ver [README-DESPLIEGUE.md](README-DESPLIEGUE.md)
