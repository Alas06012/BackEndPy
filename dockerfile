# Usa una imagen base de Python
FROM python:3.12-slim

# Instala dependencias del sistema necesarias para MySQL
RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev \
    pkg-config \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Establece el directorio de trabajo
WORKDIR /app

# Copia primero el archivo de requisitos para aprovechar el caché de Docker
COPY requirements.txt .

# Instala las dependencias de Python
RUN pip install --upgrade pip 
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto de la aplicación
COPY . .

#permisos de ejecución al script
RUN chmod +x /app/entrypoint.sh

# Expone el puerto que usa Flask
EXPOSE 5000

# Comando para ejecutar la aplicación
CMD ["python", "run.py", "--host=0.0.0.0"]
