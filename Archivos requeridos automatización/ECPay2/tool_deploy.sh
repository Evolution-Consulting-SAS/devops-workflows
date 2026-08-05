#!/bin/bash
###############################################################################
# Script: tool_deploy.sh
# Descripción:
#   Script de despliegue del microservicio.
#   Debe ejecutarse desde la raíz del repositorio del microservicio.
#
# Responsabilidades:
#   - Preparar / compilar el microservicio
#   - Construir la imagen Docker correspondiente
#   - Levantar el contenedor del microservicio
#
# Suposiciones:
#   - El docker-compose.yml se encuentra en el directorio padre
#   - El nombre del servicio coincide con el definido en docker-compose.yml
###############################################################################

set -e  # Terminar el script si ocurre cualquier error

echo "==> Iniciando despliegue del microservicio..."

###############################################################################
# CONFIGURACIÓN DEL MICROSERVICIO
# Ajustar estas variables según el microservicio
###############################################################################

# Nombre del servicio tal como está definido en docker-compose.yml
SERVICE_NAME="nombre_del_servicio"

###############################################################################
# PASO 1: Preparar / compilar el microservicio
# Ajustar según la tecnología usada
###############################################################################

echo "==> Compilando microservicio ..."

# ---------------------------------------------------------------------------
# EJEMPLOS
# ---------------------------------------------------------------------------

# --- Spring Boot / Java ---
# sudo mvn clean package -DskipTests

# --- Node.js ---
# sudo npm install
# sudo npm run build

# --- Frontend (React / Angular / Vue) ---
# sudo npm install
# sudo npm run build

echo "==> Compilación del microservicio completado"

###############################################################################
# PASO 2: Despliegue con Docker Compose
###############################################################################

echo "==> Desplegando servicio Docker: ${SERVICE_NAME}"

# Subir al directorio donde está docker-compose.yml
cd ..

# Detener el servicio (si existe)
sudo docker-compose down ${SERVICE_NAME}

# Construir la imagen del servicio
sudo docker-compose build ${SERVICE_NAME}

# Levantar el servicio
sudo docker-compose up -d ${SERVICE_NAME}

echo "==> Servicio ${SERVICE_NAME} desplegado exitosamente"
echo "==> Deploy finalizado"
