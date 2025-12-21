# Etapa de construcción
FROM rust:1.83-slim AS builder

WORKDIR /app

# Instalar dependencias necesarias para compilación
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    libprotobuf-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copiar archivos de configuración
COPY api/Cargo.toml api/Cargo.lock* ./
COPY proto/struct_saales.proto proto/

# Crear directorio src con un archivo dummy para cachear dependencias
RUN mkdir -p src && \
    echo "fn main() {println!(\"Dummy\");}" > src/main.rs && \
    cargo build --release && \
    rm -rf src target/release/deps/api* target/release/api*

# Copiar código fuente real
COPY api/src ./src

# Compilar aplicación en release mode
RUN cargo build --release && \
    strip target/release/api

# Etapa final - imagen mínima
FROM debian:bookworm-slim

WORKDIR /app

# Instalar solo las dependencias de runtime necesarias
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Copiar el binario compilado
COPY --from=builder /app/target/release/api /app/api

# Asegurar permisos de ejecución
RUN chmod +x /app/api

# Crear usuario no-root para seguridad
RUN useradd -m -u 1000 rustuser && \
    chown -R rustuser:rustuser /app

USER rustuser

# Variables de entorno por defecto
ENV PORT=3000
ENV RUST_LOG=info
ENV RUST_BACKTRACE=1

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["/bin/sh", "-c", "pidof api || exit 1"]

# Ejecutar la aplicación
CMD ["/app/api"]
