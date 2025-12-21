package main

import (
"context"
"encoding/json"
"fmt"
"log"
"net"
"os"
"time"

pb "grpc-server/proto"

"github.com/segmentio/kafka-go"
"google.golang.org/grpc"
)

type productSaleServer struct {
pb.UnimplementedProductSaleServiceServer
kafkaWriter *kafka.Writer
serverID    string
}

// Estructura para el mensaje Kafka
type VentaKafkaMessage struct {
ServerID        string    `json:"server_id"`
ProductoID      string    `json:"producto_id"`
Categoria       string    `json:"categoria"`
Precio          float64   `json:"precio"`
CantidadVendida int32     `json:"cantidad_vendida"`
Total           float64   `json:"total"`
Timestamp       time.Time `json:"timestamp"`
}

// Inicializar Kafka Writer
func newKafkaWriter(brokers []string, topic string) *kafka.Writer {
return &kafka.Writer{
Addr:         kafka.TCP(brokers...),
Topic:        topic,
Balancer:     &kafka.LeastBytes{},
BatchSize:    1,
RequiredAcks: kafka.RequireOne,
Async:        false,
}
}

// ProcesarVenta implementa el servicio gRPC definido en el proto
func (s *productSaleServer) ProcesarVenta(ctx context.Context, req *pb.ProductSaleRequest) (*pb.ProductSaleResponse, error) {
	categoria := pb.CategoriaProducto_name[int32(req.Categoria)]
	total := req.Precio * float64(req.CantidadVendida)

	log.Printf("📦 [%s] Venta recibida:", s.serverID)
	log.Printf("   Producto ID: %s", req.ProductoId)
	log.Printf("   Categoría: %s", categoria)
	log.Printf("   Precio: $%.2f", req.Precio)
	log.Printf("   Cantidad: %d", req.CantidadVendida)
	log.Printf("   Total: $%.2f", total)

// Crear mensaje para Kafka
mensaje := VentaKafkaMessage{
ServerID:        s.serverID,
ProductoID:      req.ProductoId,
Categoria:       categoria,
Precio:          req.Precio,
CantidadVendida: req.CantidadVendida,
Total:           total,
Timestamp:       time.Now(),
}

// Serializar a JSON
mensajeJSON, err := json.Marshal(mensaje)
if err != nil {
log.Printf("❌ Error al serializar mensaje: %v", err)
return &pb.ProductSaleResponse{Estado: "error"}, err
}

// Publicar en Kafka
err = s.kafkaWriter.WriteMessages(ctx, kafka.Message{
Key:   []byte(req.ProductoId),
Value: mensajeJSON,
})

if err != nil {
log.Printf("❌ Error al publicar en Kafka: %v", err)
return &pb.ProductSaleResponse{Estado: "error"}, err
}

log.Printf("✅ [%s] Mensaje publicado en Kafka exitosamente", s.serverID)
log.Println("   --------------------------------")

return &pb.ProductSaleResponse{
Estado: "exitoso",
}, nil
}

func main() {
port := os.Getenv("GRPC_PORT")
if port == "" {
port = "50051"
}

serverID := os.Getenv("SERVER_ID")
if serverID == "" {
serverID = "grpc-server-1"
}

// Configuración de Kafka
kafkaBroker := os.Getenv("KAFKA_BROKER")
if kafkaBroker == "" {
kafkaBroker = "localhost:9092"
}

kafkaTopic := os.Getenv("KAFKA_TOPIC")
if kafkaTopic == "" {
kafkaTopic = "ventas"
}

// Crear Kafka writer
kafkaWriter := newKafkaWriter([]string{kafkaBroker}, kafkaTopic)
defer kafkaWriter.Close()

log.Printf("📡 Conectado a Kafka: %s (topic: %s)", kafkaBroker, kafkaTopic)

lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
if err != nil {
log.Fatalf("❌ Error al escuchar en el puerto %s: %v", port, err)
}

grpcServer := grpc.NewServer()
pb.RegisterProductSaleServiceServer(grpcServer, &productSaleServer{
kafkaWriter: kafkaWriter,
serverID:    serverID,
})

log.Printf("🚀 [%s] Servidor gRPC escuchando en el puerto %s", serverID, port)
log.Println("📡 Esperando peticiones de venta...")

if err := grpcServer.Serve(lis); err != nil {
log.Fatalf("❌ Error al iniciar el servidor: %v", err)
}
}
