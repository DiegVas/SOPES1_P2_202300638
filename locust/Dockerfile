FROM python:3.11-slim

WORKDIR /locust

# Instalar locust
RUN pip install --no-cache-dir locust==2.20.0

# Copiar locustfile
COPY locustfile.py .

# Exponer puerto de Locust
EXPOSE 8089

# Comando para ejecutar Locust
ENTRYPOINT ["locust"]
