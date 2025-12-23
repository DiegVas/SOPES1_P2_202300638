package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
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

// Mapeo de productos a nombres descriptivos por categoría
var productNames = map[string]string{
	"prod001": "Laptop Gaming ROG",
	"prod002": "Smartphone Galaxy S24",
	"prod003": "Camiseta Nike Deportiva",
	"prod004": "Sofá Moderno 3 Plazas",
	"prod005": "Set Maquillaje Premium",
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getProductName(productID string) string {
	if name, ok := productNames[productID]; ok {
		return name
	}
	return productID
}

func main() {
	// Configurar logger Zap
	config := zap.NewProductionConfig()
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	logger, err := config.Build()
	if err != nil {
		panic(fmt.Sprintf("Error inicializando zap logger: %v", err))
	}
	defer logger.Sync()
	
	logger.Info("🚀 Iniciando Kafka Consumer para Valkey")

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
		logger.Warn("⚠️ No se pudo conectar a Redis (continuando...)",
			zap.Error(err),
			zap.String("redis_addr", redisAddr),
		)
	} else {
		logger.Info("✅ Conectado a Valkey/Redis",
			zap.String("redis_addr", redisAddr),
		)
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

	logger.Info("✅ Escuchando mensajes de Kafka",
		zap.String("topic", kafkaTopic),
		zap.String("broker", kafkaBroker),
		zap.String("group", kafkaGroup),
	)

	// Canal para manejo de señales
	sigchan := make(chan os.Signal, 1)
	signal.Notify(sigchan, syscall.SIGINT, syscall.SIGTERM)

	// Goroutine para consumir mensajes
	go func() {
		for {
			msg, err := reader.ReadMessage(ctx)
			if err != nil {
				logger.Error("❌ Error leyendo mensaje de Kafka",
					zap.Error(err),
					zap.String("topic", kafkaTopic),
				)
				time.Sleep(time.Second)
				continue
			}

			logger.Debug("📨 Mensaje recibido",
				zap.String("payload", string(msg.Value)),
				zap.Int("partition", msg.Partition),
				zap.Int64("offset", msg.Offset),
			)

			// Parsear mensaje
			var compra CompraMessage
			if err := json.Unmarshal(msg.Value, &compra); err != nil {
				logger.Warn("⚠️ Error parseando JSON",
					zap.Error(err),
					zap.String("raw_message", string(msg.Value)),
				)
				continue
			}

			// Almacenar en Redis
			if err := storeInRedis(ctx, redisClient, &compra, logger); err != nil {
				logger.Error("❌ Error almacenando en Redis",
					zap.Error(err),
					zap.String("producto_id", compra.ProductoID),
				)
				continue
			}

			logger.Info("✅ Compra almacenada",
				zap.String("producto_id", compra.ProductoID),
				zap.String("categoria", compra.Categoria),
				zap.Int32("cantidad_vendida", compra.CantidadVendida),
				zap.Float64("total", compra.Total),
				zap.String("server_id", compra.ServerID),
			)
		}
	}()

	// Esperar señal de terminación
	<-sigchan
	logger.Info("🛑 Cerrando Kafka Consumer...")
}

func storeInRedis(ctx context.Context, client *redis.Client, compra *CompraMessage, logger *zap.Logger) error {
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
	
	// Guardar nombre descriptivo del producto
	client.HSet(ctx, "productos:nombres", compra.ProductoID, getProductName(compra.ProductoID))

	// Incrementar contador por servidor
	client.HIncrBy(ctx, "servidores:ventas", compra.ServerID, 1)

	// Incrementar contador por categoría (cantidad vendida)
	client.HIncrBy(ctx, "categorias:ventas", compra.Categoria, int64(compra.CantidadVendida))

	// Incrementar contador de REPORTES/TRANSACCIONES por categoría
	client.HIncrBy(ctx, "categorias:reportes", compra.Categoria, 1)

	// Guardar información del producto (para queries de precio)
	productKey := "producto:info:" + compra.ProductoID
	client.HSet(ctx, productKey,
		"categoria", compra.Categoria,
		"ultimo_precio", compra.Precio,
		"producto_id", compra.ProductoID,
		"nombre", getProductName(compra.ProductoID),
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

	// === NUEVO: Calcular y almacenar precio promedio por categoría ===
	// Obtener suma total de precios y cantidad de compras
	categoriaSumKey := "categoria:" + compra.Categoria + ":suma_precios"
	categoriaCountKey := "categoria:" + compra.Categoria + ":count_compras"
	
	// Incrementar suma total de precios (multiplicado por 100 para evitar decimales)
	precioInt := int64(compra.Precio * 100)
	client.IncrBy(ctx, categoriaSumKey, precioInt)
	
	// Incrementar contador de compras
	client.Incr(ctx, categoriaCountKey)
	
	// Calcular y guardar promedio
	sumaTotal, _ := client.Get(ctx, categoriaSumKey).Int64()
	countTotal, _ := client.Get(ctx, categoriaCountKey).Int64()
	
	if countTotal > 0 {
		promedio := float64(sumaTotal) / float64(countTotal) / 100.0
		client.HSet(ctx, "categorias:precio_promedio", compra.Categoria, promedio)
	}

	// === NUEVO: Calcular precio total generado por categoría ===
	client.HIncrByFloat(ctx, "categorias:total_ingresos", compra.Categoria, compra.Total)

	// === NUEVO: Tracking de precios máximo y mínimo globales ===
	// Obtener precio actual máximo y mínimo
	precioMaxStr, _ := client.Get(ctx, "global:precio_maximo").Result()
	precioMinStr, _ := client.Get(ctx, "global:precio_minimo").Result()
	
	// Si no existen, inicializar con el precio actual
	if precioMaxStr == "" {
		client.Set(ctx, "global:precio_maximo", compra.Precio, 0)
		client.Set(ctx, "global:precio_maximo_producto", compra.ProductoID, 0)
	} else {
		// Actualizar si es mayor
		var precioMax float64
		if _, err := fmt.Sscanf(precioMaxStr, "%f", &precioMax); err == nil {
			if compra.Precio > precioMax {
				client.Set(ctx, "global:precio_maximo", compra.Precio, 0)
				client.Set(ctx, "global:precio_maximo_producto", compra.ProductoID, 0)
			}
		}
	}
	
	if precioMinStr == "" {
		client.Set(ctx, "global:precio_minimo", compra.Precio, 0)
		client.Set(ctx, "global:precio_minimo_producto", compra.ProductoID, 0)
	} else {
		// Actualizar si es menor
		var precioMin float64
		if _, err := fmt.Sscanf(precioMinStr, "%f", &precioMin); err == nil {
			if compra.Precio < precioMin {
				client.Set(ctx, "global:precio_minimo", compra.Precio, 0)
				client.Set(ctx, "global:precio_minimo_producto", compra.ProductoID, 0)
			}
		}
	}

	// === NUEVO: Sorted set global de productos por ventas (para top/bottom) ===
	// Esto permite obtener fácilmente el más y menos vendido
	client.ZIncrBy(ctx, "global:productos_ranking", float64(compra.CantidadVendida), compra.ProductoID)

	// === NUEVO: Actualizar producto MÁS y MENOS vendido (keys simples para Grafana) ===
	// Obtener el ranking actual
	topProductos, _ := client.ZRevRangeWithScores(ctx, "global:productos_ranking", 0, 0).Result()
	bottomProductos, _ := client.ZRangeWithScores(ctx, "global:productos_ranking", 0, 0).Result()
	
	if len(topProductos) > 0 {
		productoMasVendido := topProductos[0].Member.(string)
		cantidadMasVendido := topProductos[0].Score
		nombreMasVendido := getProductName(productoMasVendido)
		
		// Keys simples con GET para Grafana (formato: Producto | Cantidad)
		client.Set(ctx, "stat:mas_vendido_nombre", nombreMasVendido, 0)
		client.Set(ctx, "stat:mas_vendido_cantidad", fmt.Sprintf("%.0f", cantidadMasVendido), 0)
		client.Set(ctx, "stat:mas_vendido_completo", fmt.Sprintf("%s (%.0f unidades)", nombreMasVendido, cantidadMasVendido), 0)
		client.Set(ctx, "stat:mas_vendido_id", productoMasVendido, 0)
	}
	
	if len(bottomProductos) > 0 {
		productoMenosVendido := bottomProductos[0].Member.(string)
		cantidadMenosVendido := bottomProductos[0].Score
		nombreMenosVendido := getProductName(productoMenosVendido)
		
		// Keys simples con GET para Grafana
		client.Set(ctx, "stat:menos_vendido_nombre", nombreMenosVendido, 0)
		client.Set(ctx, "stat:menos_vendido_cantidad", fmt.Sprintf("%.0f", cantidadMenosVendido), 0)
		client.Set(ctx, "stat:menos_vendido_completo", fmt.Sprintf("%s (%.0f unidades)", nombreMenosVendido, cantidadMenosVendido), 0)
		client.Set(ctx, "stat:menos_vendido_id", productoMenosVendido, 0)
	}

	// === NUEVO: Promedio de unidades vendidas por transacción por categoría ===
	// Ya tenemos categorias:ventas (total unidades) y categorias:reportes (total transacciones)
	// Calcular y guardar promedio
	totalUnidades, _ := client.HGet(ctx, "categorias:ventas", compra.Categoria).Int64()
	totalTransacciones, _ := client.HGet(ctx, "categorias:reportes", compra.Categoria).Int64()
	
	if totalTransacciones > 0 {
		promedioUnidades := float64(totalUnidades) / float64(totalTransacciones)
		client.HSet(ctx, "categorias:promedio_unidades", compra.Categoria, promedioUnidades)
	}

	// === NUEVO: Variación de precios por categoría (especial para Belleza) ===
	// Rastrear precio máximo y mínimo por categoría
	precioMaxCatKey := "categoria:" + compra.Categoria + ":precio_maximo"
	precioMinCatKey := "categoria:" + compra.Categoria + ":precio_minimo"
	
	// Obtener o inicializar precio máximo de la categoría
	precioMaxCat := compra.Precio
	if val, err := client.Get(ctx, precioMaxCatKey).Float64(); err == nil {
		if compra.Precio > val {
			precioMaxCat = compra.Precio
			client.Set(ctx, precioMaxCatKey, compra.Precio, 0)
			client.Set(ctx, precioMaxCatKey+"_producto", compra.ProductoID, 0)
		} else {
			precioMaxCat = val
		}
	} else {
		// Primera vez, inicializar
		client.Set(ctx, precioMaxCatKey, compra.Precio, 0)
		client.Set(ctx, precioMaxCatKey+"_producto", compra.ProductoID, 0)
	}
	
	// Obtener o inicializar precio mínimo de la categoría
	precioMinCat := compra.Precio
	if val, err := client.Get(ctx, precioMinCatKey).Float64(); err == nil {
		if compra.Precio < val {
			precioMinCat = compra.Precio
			client.Set(ctx, precioMinCatKey, compra.Precio, 0)
			client.Set(ctx, precioMinCatKey+"_producto", compra.ProductoID, 0)
		} else {
			precioMinCat = val
		}
	} else {
		// Primera vez, inicializar
		client.Set(ctx, precioMinCatKey, compra.Precio, 0)
		client.Set(ctx, precioMinCatKey+"_producto", compra.ProductoID, 0)
	}
	
	// Calcular variación de precio de la categoría
	variacion := precioMaxCat - precioMinCat
	porcentajeVariacion := float64(0)
	if precioMinCat > 0 {
		porcentajeVariacion = (variacion / precioMinCat) * 100
	}
	
	client.Set(ctx, "categoria:"+compra.Categoria+":variacion_precio", variacion, 0)
	client.Set(ctx, "categoria:"+compra.Categoria+":variacion_porcentaje", porcentajeVariacion, 0)
	
	// === NUEVO: Estadísticas específicas para Belleza ===
	if compra.Categoria == "Belleza" {
		productoMaxBelleza, _ := client.Get(ctx, precioMaxCatKey+"_producto").Result()
		productoMinBelleza, _ := client.Get(ctx, precioMinCatKey+"_producto").Result()
		
		client.Set(ctx, "stat:belleza_precio_max", precioMaxCat, 0)
		client.Set(ctx, "stat:belleza_precio_min", precioMinCat, 0)
		client.Set(ctx, "stat:belleza_producto_max", productoMaxBelleza, 0)
		client.Set(ctx, "stat:belleza_producto_min", productoMinBelleza, 0)
		client.Set(ctx, "stat:belleza_variacion", variacion, 0)
		client.Set(ctx, "stat:belleza_variacion_texto", 
			fmt.Sprintf("Max: $%.2f | Min: $%.2f | Dif: $%.2f", precioMaxCat, precioMinCat, variacion), 0)
		
		// Guardar variación como time series (sorted set con timestamp)
		timestamp, _ := time.Parse(time.RFC3339, compra.Timestamp)
		client.ZAdd(ctx, "timeseries:belleza_variacion", redis.Z{
			Score:  float64(timestamp.Unix()),
			Member: fmt.Sprintf("%.2f", variacion),
		})
		
		// Guardar precio máximo como time series
		client.ZAdd(ctx, "timeseries:belleza_precio_max", redis.Z{
			Score:  float64(timestamp.Unix()),
			Member: fmt.Sprintf("%.2f", precioMaxCat),
		})
		
		// Guardar precio mínimo como time series
		client.ZAdd(ctx, "timeseries:belleza_precio_min", redis.Z{
			Score:  float64(timestamp.Unix()),
			Member: fmt.Sprintf("%.2f", precioMinCat),
		})
		
		// Limitar el histórico a las últimas 1000 entradas
		client.ZRemRangeByRank(ctx, "timeseries:belleza_variacion", 0, -1001)
		client.ZRemRangeByRank(ctx, "timeseries:belleza_precio_max", 0, -1001)
		client.ZRemRangeByRank(ctx, "timeseries:belleza_precio_min", 0, -1001)
	}

	return nil
}
