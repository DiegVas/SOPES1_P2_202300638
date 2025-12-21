# Sistema de Ventas Black Friday - Microservicios con Kubernetes

Sistema distribuido de ventas Black Friday con arquitectura de microservicios usando Rust, Go, gRPC, Kafka y Kubernetes.

## 🏗️ Arquitectura

### Con Nginx (Recomendado para Kubernetes)

```
┌─────────────┐
│   Cliente   │
│ (Externo)   │
└──────┬──────┘
       │ HTTP :30300
       ▼
┌──────────────────────────────────┐
│   Nginx Proxy (Load Balancer)   │  ← Proxy Reverso
│   - Health checks                │
│   - Balanceo de carga            │
│   - Headers personalizados       │
└──────────┬───────────────────────┘
           │ HTTP interno
           ├──────────┬──────────┐
           ▼          ▼          ▼
     ┌─────────┐ ┌─────────┐ ┌─────────┐
     │ Rust    │ │ Rust    │ │ Rust    │
     │ API     │ │ API     │ │ API     │
     │ Pod 1   │ │ Pod 2   │ │ Pod 3   │
     └────┬────┘ └────┬────┘ └────┬────┘
          │           │           │
          │ HTTP      │           │
          └───────────┼───────────┘
                      ▼
           ┌──────────────────────┐
           │   Go API REST        │  ← gRPC Client
           │   (Puerto 8080)      │
           └──────────┬───────────┘
                      │ gRPC
            ┌─────────┼─────────┐
            ▼         ▼         ▼
     ┌──────────┐ ┌──────────┐
     │ gRPC     │ │ gRPC     │
     │ Server 1 │ │ Server 2 │
     └────┬─────┘ └────┬─────┘
          │            │
          └─────┬──────┘
                ▼
          ┌──────────┐
          │  Kafka   │
          │  Broker  │
          └──────────┘
```

### Sin Nginx (Docker Compose tradicional)

```
┌─────────────┐
│   Cliente   │
│  (curl, UI) │
└──────┬──────┘
       │ HTTP :3000
       ▼
┌─────────────────────────────────┐
│   API REST Rust (Puerto 3000)  │  ← Endpoint principal
│   GET /productos                │
│   POST /comprar                 │
└──────────┬──────────────────────┘
           │ HTTP
           ▼
┌───────────────────────────────────────┐
│ Deployment 1: Go API REST (8080)     │  ← gRPC Client + Load Balancer
│  - Recibe peticiones HTTP de Rust    │
│  - Actúa como cliente gRPC            │
│  - Distribuye carga entre servidores  │
└──────────┬────────────────────────────┘
           │ gRPC (Load Balanced)
           ├──────────────┬────────────┐
           ▼              ▼            ▼
┌──────────────────┐  ┌──────────────────┐
│ Deployment 2:    │  │ Deployment 3:    │
│ gRPC Server 1    │  │ gRPC Server 2    │
│ (1 réplica)      │  │ (2 réplicas)     │
│ - Puerto: 50051  │  │ - Puerto: 50051  │
└────────┬─────────┘  └────────┬─────────┘
         │                     │
         │ Kafka Writer        │ Kafka Writer
         └──────────┬──────────┘
                    ▼
              ┌──────────┐
              │  Kafka   │  ← Topic: ventas
              │  Broker  │
              └──────────┘
```

## 📦 Deployments de Go

### Deployment 1: API REST + gRPC Client

- **Puerto**: 8080
- **Función**: Recibe peticiones HTTP de Rust y actúa como cliente gRPC
- **Load Balancing**: Distribuye peticiones entre grpc-server-1 y grpc-server-2
- **Réplicas**: 2

### Deployment 2: gRPC Server 1 (Writer)

- **Puerto**: 50051
- **Función**: Procesa ventas y publica en Kafka
- **Réplicas**: 1 (configurable)
- **Kafka Topic**: ventas

### Deployment 3: gRPC Server 2 (Writer)

- **Puerto**: 50051
- **Función**: Procesa ventas y publica en Kafka
- **Réplicas**: 2 (configurable)
- **Kafka Topic**: ventas

## 🌐 Nginx como Proxy Reverso

Nginx actúa como intermediario entre los clientes externos y la API de Rust:

### Ventajas

- ✅ **Balanceo de carga** entre múltiples pods de Rust API
- ✅ **Health checks** automáticos
- ✅ **Aislamiento** - API de Rust no expuesta directamente
- ✅ **Escalabilidad** - Fácil agregar más réplicas
- ✅ **Flexibilidad** - Permite agregar SSL/TLS, rate limiting, caching

### Configuración

- **Puerto externo**: 30300 (NodePort en Kubernetes)
- **Backend**: api-rust-service:3000 (ClusterIP interno)
- **Réplicas**: 2 (configurables)
- **Health check**: `/health` endpoint

Ver más detalles en:

- [Guía Completa de Nginx](NGINX_K8S_GUIDE.md)
- [Quick Start de Nginx](NGINX_K8S_QUICKSTART.md)

## 📋 Estructura del Proyecto

```
.
├── api/                    # API REST en Rust
│   ├── src/main.rs
│   ├── Cargo.toml
│   └── Dockerfile
├── go-api-rest/           # Deployment 1: Go API REST + gRPC Client
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── grpc-server/           # Deployments 2 y 3: gRPC Servers + Kafka Writers
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── nginx/                 # Nginx Proxy Reverso
│   ├── nginx.conf
│   ├── Dockerfile
│   └── README.md
├── proto/                 # Protocol Buffers
│   └── struct_saales.proto
├── k8s/                   # Manifiestos Kubernetes
│   ├── 00-namespace-config.yaml
│   ├── 01-zookeeper.yaml
│   ├── 02-kafka.yaml
│   ├── 03-grpc-server-1.yaml
│   ├── 04-grpc-server-2.yaml
│   ├── 05-go-api-rest.yaml
│   ├── 06-api-rust.yaml
│   ├── 07-nginx-proxy.yaml
│   ├── deploy.sh
│   ├── deploy-nginx.sh
│   ├── test-nginx.sh
│   ├── cleanup.sh
│   └── monitor-kafka.sh
├── docker-compose.yml
├── NGINX_K8S_GUIDE.md     # Guía completa de nginx
├── NGINX_K8S_QUICKSTART.md # Comandos rápidos
└── README.md
```

## 🚀 Despliegue

### Opción 1: Kubernetes con Nginx (Recomendado)

```bash
# 1. Desplegar todo el sistema (incluye nginx)
cd k8s
./deploy.sh

# O solo desplegar nginx + API Rust
./deploy-nginx.sh

# 2. Verificar estado
kubectl get pods -n blackfriday
kubectl get services -n blackfriday

# 3. Acceder a los servicios
# Nginx Proxy (acceso a Rust API): http://localhost:30300
# Go API REST: http://localhost:30080

# 4. Probar nginx
curl http://localhost:30300/health
curl http://localhost:30300/productos
```

### Opción 2: Docker Compose

```bash
# Levantar todos los servicios (incluye nginx)
docker-compose up --build

# Acceder a los servicios
# Nginx Proxy: http://localhost:3000 (reenvía a Rust API)
# Go API REST: http://localhost:8080

# Ver logs
docker-compose logs -f

# Detener
docker-compose down
```

## 📡 Endpoints

### Nginx Proxy (Puerto 3000 Docker / NodePort 30300 Kubernetes)

**Acceso recomendado en Kubernetes** - Pasa por nginx antes de llegar a Rust API:

```bash
# Health check de nginx
curl http://localhost:30300/health

# Listar productos (a través de nginx → Rust API)
curl http://localhost:30300/productos

# Comprar producto (a través de nginx → Rust API → Go API → gRPC)
curl -X POST http://localhost:30300/comprar \
  -H "Content-Type: application/json" \
  -d '{
    "producto_id": "prod001",
    "cantidad": 2
  }'
```

### API REST Rust (Puerto 3000 interno)

**Nota**: En Kubernetes con nginx, este servicio NO está expuesto directamente.
En Docker Compose tradicional (sin nginx):

```bash
# Listar productos
curl http://localhost:3000/productos

# Comprar producto
curl -X POST http://localhost:3000/comprar \
  -H "Content-Type: application/json" \
  -d '{
    "producto_id": "prod001",
    "cantidad": 2
  }'
```

### Go API REST (Puerto 8080 / NodePort 30080)

```bash
# Listar productos
curl http://localhost:30080/productos

# Comprar producto (llama a gRPC internamente)
curl -X POST http://localhost:30080/comprar \
  -H "Content-Type: application/json" \
  -d '{
    "producto_id": "prod002",
    "cantidad": 1
  }'

# Health check
curl http://localhost:30080/health
```

## 📊 Monitoreo

### Ver mensajes en Kafka

```bash
# Usando el script
cd k8s
./monitor-kafka.sh

# O manualmente
kubectl exec -it <kafka-pod> -n blackfriday -- \
  kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic ventas \
  --from-beginning
```

### Ver logs de pods

```bash
# Ver todos los pods
kubectl get pods -n blackfriday

# Logs de un pod específico
kubectl logs -f <pod-name> -n blackfriday

# Logs de todos los gRPC servers
kubectl logs -f -l app=grpc-server -n blackfriday
```

## ⚙️ Escalar Réplicas

```bash
# Escalar Deployment 2 (gRPC Server 1) a 2 réplicas
kubectl scale deployment grpc-server-1 --replicas=2 -n blackfriday

# Escalar Deployment 3 (gRPC Server 2) a 3 réplicas
kubectl scale deployment grpc-server-2 --replicas=3 -n blackfriday

# Escalar Go API REST
kubectl scale deployment go-api-rest --replicas=3 -n blackfriday

# Ver estado
kubectl get deployments -n blackfriday
```

## 📦 Productos Disponibles

| ID      | Nombre            | Categoría   | Precio    | Stock |
| ------- | ----------------- | ----------- | --------- | ----- |
| prod001 | Laptop Gaming     | Electrónica | $1,200.50 | 15    |
| prod002 | Smartphone        | Electrónica | $799.99   | 30    |
| prod003 | Camiseta Premium  | Ropa        | $29.99    | 100   |
| prod004 | Sofá Moderno      | Hogar       | $599.00   | 8     |
| prod005 | Set de Maquillaje | Belleza     | $89.90    | 50    |

## 🧪 Pruebas de Carga

### Usando el script de pruebas

```bash
./test_api.sh
```

### Prueba manual con múltiples peticiones

```bash
# Enviar 100 peticiones concurrentes
for i in {1..100}; do
  curl -X POST http://localhost:30000/comprar \
    -H "Content-Type: application/json" \
    -d '{"producto_id": "prod001", "cantidad": 1}' &
done
wait
```

## 🔧 Variables de Entorno

### Rust API

- `PORT`: Puerto del servidor (default: 3000)
- `GO_API_URL`: URL del Go API REST (default: http://localhost:8080)

### Go API REST (Deployment 1)

- `PORT`: Puerto del servidor (default: 8080)
- `GRPC_SERVERS`: Lista de servidores gRPC separados por comas

### gRPC Servers (Deployments 2 y 3)

- `GRPC_PORT`: Puerto gRPC (default: 50051)
- `SERVER_ID`: Identificador del servidor
- `KAFKA_BROKER`: Dirección del broker Kafka
- `KAFKA_TOPIC`: Topic de Kafka (default: ventas)

## 🗑️ Limpieza

```bash
# Kubernetes
cd k8s
./cleanup.sh

# Docker Compose
docker-compose down -v

# Limpiar imágenes
docker rmi rust-api go-api-rest grpc-server
```

## 📝 Formato de Mensajes Kafka

```json
{
  "server_id": "grpc-server-1-xxxxx",
  "producto_id": "prod001",
  "categoria": "Electronica",
  "precio": 1200.5,
  "cantidad_vendida": 2,
  "total": 2401.0,
  "timestamp": "2025-12-17T10:30:45Z"
}
```

## 🔍 Troubleshooting

### Pods no inician

```bash
# Ver eventos
kubectl describe pod <pod-name> -n blackfriday

# Ver logs
kubectl logs <pod-name> -n blackfriday
```

### Kafka no conecta

```bash
# Verificar que Kafka esté running
kubectl get pods -n blackfriday | grep kafka

# Verificar logs de Kafka
kubectl logs -f <kafka-pod> -n blackfriday
```

### gRPC Client no puede conectar

```bash
# Verificar servicios
kubectl get services -n blackfriday

# Probar conectividad
kubectl exec -it <go-api-pod> -n blackfriday -- ping grpc-server-1-service
```

## 📚 Tecnologías Utilizadas

- **Rust**: API REST con Axum
- **Go**: API REST con Gorilla Mux, gRPC Servers
- **gRPC**: Comunicación entre microservicios
- **Kafka**: Message broker para eventos
- **Kubernetes**: Orquestación de contenedores
- **Docker**: Containerización
- **Protocol Buffers**: Serialización de datos

## 🎯 Próximas Mejoras

- [ ] Consumer de Kafka para procesamiento de eventos
- [ ] Base de datos (PostgreSQL/MongoDB) para persistencia
- [ ] Redis para caché
- [ ] Metrics con Prometheus/Grafana
- [ ] Tracing distribuido con Jaeger
- [ ] API Gateway con rate limiting
- [ ] Autenticación JWT
- [ ] Tests de integración
- [ ] CI/CD pipeline
- [ ] Helm charts

## 👨‍💻 Autor

Proyecto 2 - SOPES1 - 202300638

## 📄 Licencia

Este proyecto es parte del curso de Sistemas Operativos 1.
