package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
)

type CompraMessage struct {
	ServerID        string  `json:"server_id"`
	ProductoID      string  `json:"producto_id"`
	Categoria       string  `json:"categoria"`
	Precio          float64 `json:"precio"`
	CantidadVendida int32   `json:"cantidad_vendida"`
	Total           float64 `json:"total"`
	Timestamp       string  `json:"timestamp"`
}

var (
	kafkaBroker = getEnv("KAFKA_BROKER", "kafka-service:9092")
	kafkaTopic  = getEnv("KAFKA_TOPIC", "compras")
	kafkaGroup  = getEnv("KAFKA_GROUP", "valkey-consumer-group")
	redisAddr   = getEnv("REDIS_ADDR", "valkey-service:6379")
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	log.Println("🚀 Iniciando Kafka Consumer para Valkey...")

	// Configurar cliente Redis/Valkey
	ctx := context.Background()
	redisClient := redis.NewClient(&redis.Options{
		Addr:         redisAddr,
		Password:     "",
		DB:           0,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	// Verificar conexión a Redis
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️ No se pudo conectar a Redis: %v (continuando...)", err)
	} else {
		log.Println("✅ Conectado a Valkey/Redis")
	}

	// Configurar Kafka Reader
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:        []string{kafkaBroker},
		Topic:          kafkaTopic,
		GroupID:        kafkaGroup,
		MinBytes:       10e1,  // 100 bytes
		MaxBytes:       10e6,  // 10MB
		CommitInterval: time.Second,
		StartOffset:    kafka.FirstOffset,
	})
	defer reader.Close()

	log.Printf("✅ Escuchando mensajes de Kafka en topic '%s'...", kafkaTopic)

	// Canal para manejo de señales
	sigchan := make(chan os.Signal, 1)
	signal.Notify(sigchan, syscall.SIGINT, syscall.SIGTERM)

	// Goroutine para consumir mensajes
	go func() {
		for {
			msg, err := reader.ReadMessage(ctx)
			if err != nil {
				log.Printf("❌ Error leyendo mensaje de Kafka: %v", err)
				time.Sleep(time.Second)
				continue
			}

			log.Printf("📨 Mensaje recibido: %s", string(msg.Value))

			// Parsear mensaje
			var compra CompraMessage
			if err := json.Unmarshal(msg.Value, &compra); err != nil {
				log.Printf("⚠️ Error parseando JSON: %v", err)
				continue
			}

			// Almacenar en Redis
			if err := storeInRedis(ctx, redisClient, &compra); err != nil {
				log.Printf("❌ Error almacenando en Redis: %v", err)
				continue
			}

			log.Printf("✅ Compra almacenada: Producto %s, Cantidad %d, Categoría %s, Total %.2f",
				compra.ProductoID, compra.CantidadVendida, compra.Categoria, compra.Total)
		}
	}()

	// Esperar señal de terminación
	<-sigchan
	log.Println("🛑 Cerrando Kafka Consumer...")
}

func storeInRedis(ctx context.Context, client *redis.Client, compra *CompraMessage) error {
	// Clave única para cada compra
	key := "compra:" + compra.ProductoID + ":" + compra.Timestamp

	// Convertir compra a JSON
	data, err := json.Marshal(compra)
	if err != nil {
		return err
	}

	// Almacenar en Redis con TTL de 24 horas
	if err := client.Set(ctx, key, data, 24*time.Hour).Err(); err != nil {
		return err
	}

	// Incrementar contador de compras
	client.Incr(ctx, "total:compras")

	// Agregar a lista de compras por producto
	client.RPush(ctx, "producto:"+compra.ProductoID+":compras", key)

	// Incrementar contador por producto (cantidad vendida)
	client.HIncrBy(ctx, "productos:ventas", compra.ProductoID, int64(compra.CantidadVendida))

	// Incrementar contador por servidor
	client.HIncrBy(ctx, "servidores:ventas", compra.ServerID, 1)

	// Incrementar contador por categoría (cantidad vendida)
	client.HIncrBy(ctx, "categorias:ventas", compra.Categoria, int64(compra.CantidadVendida))

	// Guardar información del producto (para queries de precio)
	productKey := "producto:info:" + compra.ProductoID
	client.HSet(ctx, productKey,
		"categoria", compra.Categoria,
		"ultimo_precio", compra.Precio,
		"producto_id", compra.ProductoID,
	)

	// Incrementar ventas por producto en su categoría
	client.HIncrBy(ctx, "categoria:"+compra.Categoria+":productos", compra.ProductoID, int64(compra.CantidadVendida))

	// Guardar precio del producto en sorted set (para min/max/avg)
	client.ZAdd(ctx, "precios:"+compra.ProductoID, redis.Z{
		Score:  compra.Precio,
		Member: compra.Timestamp,
	})

	// Guardar todos los precios por categoría
	client.ZAdd(ctx, "categoria:"+compra.Categoria+":precios", redis.Z{
		Score:  compra.Precio,
		Member: compra.ProductoID + ":" + compra.Timestamp,
	})

	// Guardar histórico de precios para time series (sorted set por timestamp)
	timestamp, _ := time.Parse(time.RFC3339, compra.Timestamp)
	client.ZAdd(ctx, "timeseries:precio:"+compra.ProductoID, redis.Z{
		Score:  float64(timestamp.Unix()),
		Member: compra.Precio,
	})

	// Lista de todos los productos (set)
	client.SAdd(ctx, "productos:todos", compra.ProductoID)

	// Lista de productos por categoría
	client.SAdd(ctx, "categoria:"+compra.Categoria+":productos_unicos", compra.ProductoID)

	return nil
}
