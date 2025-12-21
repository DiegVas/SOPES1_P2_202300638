from locust import HttpUser, task, between
import random
import json

class BlackFridayUser(HttpUser):
    wait_time = between(1, 3)  # Espera entre 1 y 3 segundos entre peticiones
    
    # Lista de productos disponibles
    productos = [
        {"id": "prod001", "nombre": "Laptop Gaming"},
        {"id": "prod002", "nombre": "Smartphone"},
        {"id": "prod003", "nombre": "Auriculares Bluetooth"},
        {"id": "prod004", "nombre": "Monitor 4K"},
        {"id": "prod005", "nombre": "Teclado Mecánico"}
    ]
    
    # Lista de usuarios simulados
    usuarios = [
        "maria", "juan", "pedro", "ana", "luis",
        "carmen", "jose", "laura", "miguel", "sofia"
    ]
    
    @task(3)
    def listar_productos(self):
        """Listar productos disponibles (tarea frecuente)"""
        with self.client.get("/productos", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(5)
    def comprar_producto(self):
        """Comprar un producto aleatorio (tarea más frecuente)"""
        producto = random.choice(self.productos)
        usuario = random.choice(self.usuarios)
        cantidad = random.randint(1, 5)
        
        payload = {
            "producto_id": producto["id"],
            "cantidad": cantidad,
            "usuario": usuario
        }
        
        with self.client.post("/comprar",
                             json=payload,
                             catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if data.get("estado") in ["exitoso", "exitoso_local"]:
                        response.success()
                    else:
                        response.failure(f"Estado: {data.get('estado')}")
                except:
                    response.failure("Invalid JSON response")
            elif response.status_code == 400:
                # Stock insuficiente es una respuesta válida
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(1)
    def health_check(self):
        """Health check (tarea ocasional)"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    def on_start(self):
        """Se ejecuta cuando un usuario comienza"""
        pass
