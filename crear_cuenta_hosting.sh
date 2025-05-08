#!/bin/bash

# Comprobación de argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <número_usuario>"
    exit 1
fi

# Variables base
USER_NUM=$1
USERNAME="usuario$USER_NUM"
WEB_DIR="/var/www/$USERNAME"
DB_NAME="${USERNAME}_db"
DB_USER="${USERNAME}"
PASSWORD=$(openssl rand -base64 12)
USER_HOME="/home/$USERNAME"
USER_PUBLIC_HTML="$USER_HOME/public_html"

# Crear usuario del sistema
echo "Creando usuario del sistema $USERNAME..."
sudo useradd -m -s /bin/bash $USERNAME
if [ $? -ne 0 ]; then
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi

# Crear directorios y asignar permisos
echo "Creando directorio web en $WEB_DIR..."
sudo mkdir -p $WEB_DIR/public_html
sudo chown $USERNAME:$USERNAME $WEB_DIR/public_html
sudo chmod 755 $WEB_DIR/public_html

if [ ! -d "$USER_HOME" ]; then
    echo "Creando el directorio $USER_HOME..."
    sudo mkdir -p "$USER_HOME"
    sudo chown $USERNAME:$USERNAME "$USER_HOME"
    sudo chmod 755 "$USER_HOME"
fi

if [ ! -d "$USER_PUBLIC_HTML" ]; then
    echo "Creando el directorio $USER_PUBLIC_HTML..."
    sudo mkdir -p "$USER_PUBLIC_HTML"
    sudo chown $USERNAME:$USERNAME "$USER_PUBLIC_HTML"
    sudo chmod 755 "$USER_PUBLIC_HTML"
fi

# Crear archivo index.html
echo "Creando archivo index.html en $USER_PUBLIC_HTML..."
echo "<html><body><h1>Hola, $USERNAME</h1></body></html>" | sudo tee "$USER_PUBLIC_HTML/index.html" > /dev/null
sudo chown $USERNAME:www-data "$USER_PUBLIC_HTML/index.html"
sudo chmod 755 "$USER_PUBLIC_HTML/index.html"

# Crear base de datos y usuario en MariaDB
echo "Creando base de datos y usuario de base de datos $DB_NAME..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configurar acceso FTP
echo "Configurando acceso FTP para $USERNAME..."
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Crear archivo de credenciales
echo "Generando archivo credenciales.txt en $USER_PUBLIC_HTML..."
CRED_FILE="$USER_PUBLIC_HTML/credenciales.txt"
sudo tee $CRED_FILE > /dev/null <<EOF
Credenciales para la cuenta de hosting $USERNAME:

Usuario del sistema: $USERNAME
Contraseña (FTP y Base de Datos): $PASSWORD

Base de Datos: $DB_NAME
Usuario Base de Datos: $DB_USER

Puedes acceder a phpMyAdmin con estas credenciales.
EOF

sudo chown $USERNAME:$USERNAME $CRED_FILE
sudo chmod 600 $CRED_FILE

# Ajustar permisos necesarios para NGINX
echo "Ajustando permisos de acceso para NGINX..."
sudo chmod o+x "$USER_HOME"
sudo chmod -R 755 "$USER_PUBLIC_HTML"
sudo chown -R www-data:www-data "$USER_PUBLIC_HTML"

# Insertar bloque location dentro del server { } en /etc/nginx/sites-available/multiusuario
echo "Agregando configuración NGINX para $USERNAME dentro del bloque server { }..."

read -r -d '' LOCATION_BLOCK <<EOF
    location /$USERNAME/ {
        alias /home/$USERNAME/public_html/;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
EOF

# Insertar justo antes del cierre del bloque server (última línea que contiene solo })
sudo sed -i "/^[[:space:]]*}/i $LOCATION_BLOCK" /etc/nginx/sites-available/multiusuario

# Verificar configuración y recargar NGINX
echo "Recargando NGINX..."
sudo nginx -t && sudo systemctl reload nginx

# Final
echo "Proceso completado. Credenciales guardadas en: $CRED_FILE"

