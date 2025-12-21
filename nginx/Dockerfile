FROM nginx:alpine

# Copiar configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf

# Crear directorio de logs si no existe
RUN mkdir -p /var/log/nginx

# Exponer puerto 80
EXPOSE 80

# Comando por defecto de nginx
CMD ["nginx", "-g", "daemon off;"]
