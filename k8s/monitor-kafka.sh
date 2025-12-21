#!/bin/bash

echo "📡 Monitoreando topic 'ventas' en Kafka..."
echo "Presiona Ctrl+C para detener"
echo ""

# Obtener el nombre del pod de Kafka
KAFKA_POD=$(kubectl get pods -n blackfriday -l app=kafka -o jsonpath='{.items[0].metadata.name}')

if [ -z "$KAFKA_POD" ]; then
    echo "❌ No se encontró el pod de Kafka"
    exit 1
fi

echo "📦 Pod de Kafka: $KAFKA_POD"
echo ""

# Consumir mensajes del topic
kubectl exec -it $KAFKA_POD -n blackfriday -- \
    kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic ventas \
    --from-beginning \
    --property print.key=true \
    --property key.separator=" => "
