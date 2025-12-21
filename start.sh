#!/bin/bash

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     SISTEMA BLACK FRIDAY - INICIO RÁPIDO                 ║"
echo "║            Proyecto SOPES1 - 202300638                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado"
    echo "   Instalar: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado"
    echo "   Instalar: sudo apt install docker-compose"
    exit 1
fi

echo "🔍 Verificando requisitos..."
echo "   ✅ Docker instalado"
echo "   ✅ Docker Compose instalado"
echo ""

# Limpiar contenedores previos
echo "🧹 Limpiando contenedores previos..."
docker-compose down -v 2>/dev/null
echo ""

# Construir e iniciar servicios
echo "🚀 Construyendo e iniciando servicios..."
echo "   Esto puede tomar varios minutos en la primera ejecución..."
echo ""

docker-compose up --build -d

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ✅ DESPLIEGUE EXITOSO                        ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "📡 Servicios activos:"
    echo ""
    docker-compose ps
    echo ""
    echo "🌐 Endpoints disponibles:"
    echo "   📱 Rust API:    http://localhost:3000"
    echo "   🔧 Go API REST: http://localhost:8080"
    echo "   📊 Kafka:       localhost:9092"
    echo ""
    echo "📋 Pruebas rápidas:"
    echo "   ./test_api.sh"
    echo ""
    echo "📊 Ver logs en tiempo real:"
    echo "   docker-compose logs -f"
    echo ""
    echo "📊 Ver logs de un servicio específico:"
    echo "   docker-compose logs -f go-api-rest"
    echo "   docker-compose logs -f grpc-server-1"
    echo "   docker-compose logs -f api-rust"
    echo ""
    echo "🛑 Detener servicios:"
    echo "   docker-compose down"
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              🎉 ¡SISTEMA LISTO!                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
else
    echo ""
    echo "❌ Error durante el despliegue"
    echo "   Ver logs: docker-compose logs"
    exit 1
fi
