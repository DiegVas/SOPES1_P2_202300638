# Comparativa de Rendimiento: 1 vs. 2 Réplicas

## 1. Resumen

Se evaluó el sistema bajo dos configuraciones: una sola réplica y dos réplicas del backend principal. Las pruebas se realizaron con Locust simulando tráfico realista de compras.

---

## 2. Capacidad de Respuesta (RPS) y Carga

| Configuración | Solicitudes Totales | RPS Promedio |
| ------------- | ------------------- | ------------ |
| 1 réplica     | 52,765              | 212.1        |
| 2 réplicas    | 44,711              | 154.6        |

**Observación:**  
Con una sola réplica, el sistema procesó más solicitudes y mantuvo un RPS más alto y estable.

---

## 3. Tiempos de Latencia (ms)

| Endpoint              | 1 réplica | 2 réplicas |
| --------------------- | --------- | ---------- |
| POST /comprar         | 163       | 1126       |
| GET /health           | 57        | 496        |
| GET /productos        | 58        | 370        |
| **Promedio agregado** | 116       | 805        |

**Observación:**  
La latencia promedio aumentó casi 7 veces al duplicar las réplicas.

---

## 4. Estabilidad y Percentiles

| Métrica              | 1 réplica | 2 réplicas |
| -------------------- | --------- | ---------- |
| Percentil 95 compras | 500 ms    | 1,800 ms   |
| Máximo registrado    | 1,547 ms  | 54,557 ms  |

**Observación:**  
Con 2 réplicas, se observaron picos de latencia extremos y menor estabilidad.

---

## 5. Análisis

- **Escalabilidad:** El aumento de réplicas no mejoró el rendimiento; al contrario, degradó la capacidad de respuesta.
- **Posibles causas:**
  - Cuellos de botella en la orquestación o balanceo de carga.
  - Problemas de sincronización de estado entre instancias.
  - Gestión ineficiente de conexiones gRPC/Kafka bajo alta concurrencia.
- **Recomendación:**
  - Revisar la lógica de balanceo y la configuración de los clientes gRPC/Kafka.
  - Analizar logs y métricas de red para identificar el origen del cuello de botella.

---

## 6. Conclusión

Duplicar las réplicas no siempre implica mayor rendimiento. En este caso, la arquitectura y la gestión de estado/conexiones deben optimizarse para aprovechar la escalabilidad horizontal.

---
