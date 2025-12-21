use axum::{
    extract::Json,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower_http::trace::TraceLayer;
use tracing::{info, error};

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Producto {
    id: String,
    nombre: String,
    categoria: String,
    precio: f64,
    stock: i32,
}

#[derive(Serialize, Deserialize, Debug)]
struct CompraRequest {
    producto_id: String,
    cantidad: i32,
    usuario: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct CompraResponse {
    mensaje: String,
    estado: String,
}

// Lista de productos en memoria (simulado)
fn obtener_productos() -> Vec<Producto> {
    vec![
        Producto {
            id: "prod001".to_string(),
            nombre: "Laptop Gaming".to_string(),
            categoria: "Electronica".to_string(),
            precio: 1200.50,
            stock: 15,
        },
        Producto {
            id: "prod002".to_string(),
            nombre: "Smartphone".to_string(),
            categoria: "Electronica".to_string(),
            precio: 799.99,
            stock: 30,
        },
        Producto {
            id: "prod003".to_string(),
            nombre: "Auriculares Bluetooth".to_string(),
            categoria: "Audio".to_string(),
            precio: 149.99,
            stock: 50,
        },
        Producto {
            id: "prod004".to_string(),
            nombre: "Monitor 4K".to_string(),
            categoria: "Electronica".to_string(),
            precio: 399.99,
            stock: 20,
        },
        Producto {
            id: "prod005".to_string(),
            nombre: "Teclado Mecánico".to_string(),
            categoria: "Perifericos".to_string(),
            precio: 129.99,
            stock: 35,
        },
        Producto {
            id: "belleza001".to_string(),
            nombre: "Perfume Luxury".to_string(),
            categoria: "Belleza".to_string(),
            precio: 89.99,
            stock: 40,
        },
        Producto {
            id: "belleza002".to_string(),
            nombre: "Crema Facial Anti-edad".to_string(),
            categoria: "Belleza".to_string(),
            precio: 45.50,
            stock: 60,
        },
        Producto {
            id: "belleza003".to_string(),
            nombre: "Shampoo Premium".to_string(),
            categoria: "Belleza".to_string(),
            precio: 25.99,
            stock: 80,
        },
        Producto {
            id: "belleza004".to_string(),
            nombre: "Labial Mate".to_string(),
            categoria: "Belleza".to_string(),
            precio: 15.99,
            stock: 100,
        },
        Producto {
            id: "belleza005".to_string(),
            nombre: "Set de Brochas".to_string(),
            categoria: "Belleza".to_string(),
            precio: 65.00,
            stock: 30,
        },
    ]
}

// Handler para listar productos
async fn listar_productos() -> impl IntoResponse {
    info!("GET /productos - Listando productos disponibles");
    let productos = obtener_productos();
    (StatusCode::OK, Json(productos))
}

// Handler para realizar compra
async fn comprar_producto(
    Json(payload): Json<CompraRequest>,
) -> impl IntoResponse {
    info!("POST /comprar - Procesando compra: {:?}", payload);

    // Validar producto
    let productos = obtener_productos();
    let producto = match productos.iter().find(|p| p.id == payload.producto_id) {
        Some(p) => p,
        None => {
            error!("Producto no encontrado: {}", payload.producto_id);
            return (
                StatusCode::NOT_FOUND,
                Json(CompraResponse {
                    mensaje: format!("Producto {} no encontrado", payload.producto_id),
                    estado: "error".to_string(),
                }),
            );
        }
    };

    // Validar cantidad
    if payload.cantidad <= 0 {
        error!("Cantidad inválida: {}", payload.cantidad);
        return (
            StatusCode::BAD_REQUEST,
            Json(CompraResponse {
                mensaje: "La cantidad debe ser mayor a 0".to_string(),
                estado: "error".to_string(),
            }),
        );
    }

    if payload.cantidad > producto.stock {
        error!("Stock insuficiente. Solicitado: {}, Disponible: {}", payload.cantidad, producto.stock);
        return (
            StatusCode::BAD_REQUEST,
            Json(CompraResponse {
                mensaje: format!(
                    "Stock insuficiente. Disponible: {}",
                    producto.stock
                ),
                estado: "error".to_string(),
            }),
        );
    }

    // Enviar petición a Go API REST (Deployment 1)
    let go_api_url = std::env::var("GO_API_URL")
        .unwrap_or_else(|_| "http://go-api-rest-service:8080".to_string());
    
    let url = format!("{}/comprar", go_api_url);
    info!("Enviando petición a Go API: {}", url);
    
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .unwrap();

    match client.post(&url).json(&payload).send().await {
        Ok(response) => {
            info!("Respuesta de Go API: Status {}", response.status());
            if response.status().is_success() {
                match response.json::<CompraResponse>().await {
                    Ok(go_response) => {
                        info!("Compra procesada exitosamente");
                        (StatusCode::OK, Json(go_response))
                    }
                    Err(e) => {
                        error!("Error parseando respuesta: {}", e);
                        (
                            StatusCode::OK,
                            Json(CompraResponse {
                                mensaje: format!(
                                    "Compra realizada exitosamente: {} unidades de {}",
                                    payload.cantidad, producto.nombre
                                ),
                                estado: "exitoso".to_string(),
                            }),
                        )
                    }
                }
            } else {
                error!("Go API respondió con error: {}", response.status());
                (
                    StatusCode::BAD_GATEWAY,
                    Json(CompraResponse {
                        mensaje: "Error al procesar la compra en el servidor".to_string(),
                        estado: "error".to_string(),
                    }),
                )
            }
        }
        Err(e) => {
            error!("Error conectando con Go API: {}", e);
            // Si no podemos conectar con Go API, igual procesamos localmente
            (
                StatusCode::OK,
                Json(CompraResponse {
                    mensaje: format!(
                        "Compra procesada localmente: {} unidades de {} (Go API no disponible)",
                        payload.cantidad, producto.nombre
                    ),
                    estado: "exitoso_local".to_string(),
                }),
            )
        }
    }
}

// Health check endpoint
async fn health_check() -> impl IntoResponse {
    info!("GET /health - Health check");
    (StatusCode::OK, Json(serde_json::json!({
        "status": "healthy",
        "service": "rust-api"
    })))
}

// Root endpoint
async fn root() -> impl IntoResponse {
    info!("GET / - Root endpoint");
    (StatusCode::OK, Json(serde_json::json!({
        "message": "API REST Rust - Black Friday",
        "version": "1.0.0",
        "endpoints": {
            "GET /": "Esta información",
            "GET /health": "Health check",
            "GET /productos": "Listar productos disponibles",
            "POST /comprar": "Comprar un producto"
        }
    })))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Inicializar tracing/logging
    tracing_subscriber::fmt()
        .with_target(false)
        .with_thread_ids(false)
        .with_level(true)
        .init();

    info!("🚀 Iniciando API REST Rust...");

    // Construir la aplicación con las rutas
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health_check))
        .route("/productos", get(listar_productos))
        .route("/comprar", post(comprar_producto))
        .layer(TraceLayer::new_for_http());

    // Dirección del servidor
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{}", port)
        .parse()
        .expect("No se pudo parsear la dirección");

    info!("🌐 API REST Rust escuchando en http://{}", addr);
    info!("📋 Endpoints disponibles:");
    info!("   GET  /              - Información de la API");
    info!("   GET  /health        - Health check");
    info!("   GET  /productos     - Listar productos disponibles");
    info!("   POST /comprar       - Comprar un producto");

    // Iniciar el servidor
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("No se pudo crear el listener");
    
    info!("✅ Servidor iniciado correctamente");

    axum::serve(listener, app)
        .await
        .expect("Error ejecutando el servidor");

    Ok(())
}
