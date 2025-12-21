package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"time"

	pb "go-api-rest/proto"

	"github.com/gorilla/mux"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Estructuras para la API REST
type Producto struct {
	ID        string  `json:"id"`
	Nombre    string  `json:"nombre"`
	Categoria string  `json:"categoria"`
	Precio    float64 `json:"precio"`
	Stock     int32   `json:"stock"`
}

type CompraRequest struct {
	ProductoID string `json:"producto_id"`
	Cantidad   int32  `json:"cantidad"`
	Usuario    string `json:"usuario"`
}

type CompraResponse struct {
	Mensaje string `json:"mensaje"`
	Estado  string `json:"estado"`
}

// Lista de productos
var productos = []Producto{
	{"prod001", "Laptop Gaming", "Electronica", 1200.50, 15},
	{"prod002", "Smartphone", "Electronica", 799.99, 30},
	{"prod003", "Camiseta Premium", "Ropa", 29.99, 100},
	{"prod004", "Sofá Moderno", "Hogar", 599.00, 8},
	{"prod005", "Set de Maquillaje", "Belleza", 89.90, 50},
}

// Pool de conexiones gRPC a los servidores
var grpcClients []*grpc.ClientConn
var grpcServerURLs []string

func init() {
	// Obtener URLs de los servidores gRPC desde variables de entorno
	serversEnv := os.Getenv("GRPC_SERVERS")
	if serversEnv == "" {
		serversEnv = "localhost:50051,localhost:50052"
	}
	grpcServerURLs = strings.Split(serversEnv, ",")
}

// Inicializar conexiones gRPC
func initGRPCClients() error {
	for _, url := range grpcServerURLs {
		url = strings.TrimSpace(url)
		log.Printf("🔌 Conectando a servidor gRPC: %s", url)

		conn, err := grpc.Dial(url, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			log.Printf("⚠️  Error conectando a %s: %v", url, err)
			continue
		}
		grpcClients = append(grpcClients, conn)
		log.Printf("✅ Conectado a %s", url)
	}

	if len(grpcClients) == 0 {
		return fmt.Errorf("no se pudo conectar a ningún servidor gRPC")
	}

	return nil
}

// Cerrar conexiones gRPC
func closeGRPCClients() {
	for _, conn := range grpcClients {
		conn.Close()
	}
}

// Obtener cliente gRPC de forma aleatoria (load balancing simple)
func getRandomGRPCClient() *grpc.ClientConn {
	if len(grpcClients) == 0 {
		return nil
	}
	idx := rand.Intn(len(grpcClients))
	return grpcClients[idx]
}

// Handler para listar productos
func listarProductosHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(productos)
}

// Handler para comprar producto
func comprarProductoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req CompraRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: "JSON inválido",
			Estado:  "error",
		})
		return
	}

	// Validar que el producto existe
	var producto *Producto
	for _, p := range productos {
		if p.ID == req.ProductoID {
			producto = &p
			break
		}
	}

	if producto == nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: "Producto no encontrado",
			Estado:  "error",
		})
		return
	}

	// Validar cantidad
	if req.Cantidad <= 0 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: "La cantidad debe ser mayor a 0",
			Estado:  "error",
		})
		return
	}

	if req.Cantidad > producto.Stock {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: fmt.Sprintf("Stock insuficiente. Disponible: %d", producto.Stock),
			Estado:  "error",
		})
		return
	}

	// Obtener cliente gRPC
	conn := getRandomGRPCClient()
	if conn == nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: "No hay servidores gRPC disponibles",
			Estado:  "error",
		})
		return
	}

	// Crear cliente gRPC
	client := pb.NewProductSaleServiceClient(conn)

	// Convertir categoría a enum
	var categoria pb.CategoriaProducto
	switch producto.Categoria {
	case "Electronica":
		categoria = pb.CategoriaProducto_Electronica
	case "Ropa":
		categoria = pb.CategoriaProducto_Ropa
	case "Hogar":
		categoria = pb.CategoriaProducto_Hogar
	case "Belleza":
		categoria = pb.CategoriaProducto_Belleza
	default:
		categoria = pb.CategoriaProducto_Electronica
	}

	// Enviar venta al servidor gRPC
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	grpcReq := &pb.ProductSaleRequest{
		Categoria:       categoria,
		ProductoId:      producto.ID,
		Precio:          producto.Precio,
		CantidadVendida: req.Cantidad,
	}

	log.Printf("📤 Enviando venta a servidor gRPC: %s - %s (cantidad: %d)",
		producto.ID, producto.Nombre, req.Cantidad)

	resp, err := client.ProcesarVenta(ctx, grpcReq)
	if err != nil {
		log.Printf("❌ Error al procesar venta: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(CompraResponse{
			Mensaje: fmt.Sprintf("Error al procesar la venta: %v", err),
			Estado:  "error",
		})
		return
	}

	log.Printf("✅ Venta procesada exitosamente: %s", resp.Estado)

	// Responder al cliente
	json.NewEncoder(w).Encode(CompraResponse{
		Mensaje: fmt.Sprintf("Compra realizada exitosamente: %d unidades de %s",
			req.Cantidad, producto.Nombre),
		Estado: resp.Estado,
	})
}

// Health check
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":       "ok",
		"service":      "go-api-rest",
		"grpc_servers": fmt.Sprintf("%d disponibles", len(grpcClients)),
	})
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Inicializar conexiones gRPC
	if err := initGRPCClients(); err != nil {
		log.Fatalf("❌ Error inicializando clientes gRPC: %v", err)
	}
	defer closeGRPCClients()

	// Crear router
	r := mux.NewRouter()
	r.HandleFunc("/productos", listarProductosHandler).Methods("GET")
	r.HandleFunc("/comprar", comprarProductoHandler).Methods("POST")
	r.HandleFunc("/health", healthHandler).Methods("GET")

	// Obtener puerto
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 API REST (Deployment 1) escuchando en puerto %s", port)
	log.Printf("📡 Conectado a %d servidores gRPC", len(grpcClients))
	log.Printf("📋 Endpoints:")
	log.Printf("   GET  /productos - Listar productos")
	log.Printf("   POST /comprar    - Comprar producto")
	log.Printf("   GET  /health     - Health check")

	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("❌ Error al iniciar servidor: %v", err)
	}
}
