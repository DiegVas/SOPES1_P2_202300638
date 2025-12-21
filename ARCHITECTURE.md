# Arquitectura del Sistema - Black Friday Microservices

## Flujo de Datos

```
1. Cliente → Rust API (GET /productos)
   └─> Responde directamente con lista de productos

2. Cliente → Rust API (POST /comprar)
   └─> Rust API → Go API REST (POST /comprar)
       └─> Go API REST (Load Balancer) → gRPC Server (aleatorio)
           └─> gRPC Server → Kafka (topic: ventas)
               └─> Kafka almacena mensaje
```

## Componentes

### Frontend Layer

- **Cliente**: curl, Postman, navegador, etc.
- **Protocolo**: HTTP/REST

### API Gateway Layer

- **Rust API** (Puerto 3000)
  - Framework: Axum
  - Endpoints: GET /productos, POST /comprar
  - Validaciones de negocio
  - Reenvía compras a Go API REST

### Application Layer

- **Go API REST** (Deployment 1 - Puerto 8080)
  - Framework: Gorilla Mux
  - Cliente gRPC interno
  - Load balancing entre gRPC servers
  - 2 réplicas para alta disponibilidad

### Processing Layer

- **gRPC Server 1** (Deployment 2 - Puerto 50051)
  - 1 réplica
  - Recibe peticiones gRPC
  - Escribe en Kafka
- **gRPC Server 2** (Deployment 3 - Puerto 50051)
  - 2 réplicas
  - Recibe peticiones gRPC
  - Escribe en Kafka

### Message Queue Layer

- **Kafka** (Puerto 9092)

  - Topic: ventas
  - Almacena todos los eventos de venta
  - Permite procesamiento asíncrono

- **Zookeeper** (Puerto 2181)
  - Coordinación de Kafka

## Escalabilidad

### Horizontal Scaling

```bash
# Escalar Go API REST
kubectl scale deployment go-api-rest --replicas=5 -n blackfriday

# Escalar gRPC Server 1
kubectl scale deployment grpc-server-1 --replicas=3 -n blackfriday

# Escalar gRPC Server 2
kubectl scale deployment grpc-server-2 --replicas=5 -n blackfriday
```

### Load Distribution

- Go API REST usa round-robin entre gRPC servers
- Kubernetes Service distribuye carga entre réplicas
- Kafka particiona mensajes por clave (producto_id)

## Resiliencia

### Retry Logic

- Go API REST reintenta conexión gRPC en caso de fallo
- Si un gRPC server falla, el load balancer usa otro

### Health Checks

- Liveness probes en todos los deployments
- Readiness probes para detectar servicios no listos

### Data Persistence

- Kafka persiste mensajes en disco
- Replicación configurada para durabilidad

## Monitoreo

### Logs

- Cada servicio genera logs estructurados
- Identificador único por servidor (SERVER_ID)
- Timestamp en cada evento

### Metrics

- Kubernetes métricas nativas (CPU, memoria)
- Custom metrics desde aplicaciones

### Tracing

- Seguimiento de peticiones end-to-end
- Identificación de cuellos de botella

## Security (Próximas mejoras)

- [ ] TLS/SSL entre servicios
- [ ] Autenticación JWT
- [ ] Network policies en Kubernetes
- [ ] Secrets management
- [ ] Rate limiting
