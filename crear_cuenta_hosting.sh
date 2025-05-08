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
if [ $? -eq 0 ]; then
    echo "Usuario $USERNAME creado correctamente."
else
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi

# Crear directorios y asignar permisos
echo "Preparando directorios..."
sudo mkdir -p "$USER_PUBLIC_HTML"
sudo chown -R $USERNAME:$USERNAME "$USER_HOME"
sudo chmod o+x "$USER_HOME"
sudo chmod -R 755 "$USER_PUBLIC_HTML"

# Crear index.html
echo "Creando archivo index.html..."
echo "<html><body><h1>Hola, $USERNAME</h1></body></html>" | sudo tee "$USER_PUBLIC_HTML/index.html" > /dev/null
sudo chown $USERNAME:www-data "$USER_PUBLIC_HTML/index.html"
sudo chmod 644 "$USER_PUBLIC_HTML/index.html"

# Crear base de datos y usuario en MariaDB
echo "Creando base de datos y usuario en MariaDB..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configurar contraseña FTP
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Crear archivo credenciales.txt
CRED_FILE="$USER_PUBLIC_HTML/credenciales.txt"
sudo tee "$CRED_FILE" > /dev/null <<EOF
Credenciales para la cuenta de hosting $USERNAME:

Usuario del sistema: $USERNAME
Contraseña (FTP y Base de Datos): $PASSWORD

Base de Datos: $DB_NAME
Usuario Base de Datos: $DB_USER

Puedes acceder a phpMyAdmin con estas credenciales.
EOF
sudo chown $USERNAME:$USERNAME "$CRED_FILE"
sudo chmod 600 "$CRED_FILE"

# Agregar bloque location al archivo NGINX
echo "Agregando configuración NGINX para $USERNAME..."

read -r -d '' LOCATION_BLOCK <<EOF
    location /$USERNAME/ {
        alias /home/$USERNAME/public_html/;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
EOF

# Insertar dentro del bloque server { } justo antes del último }
sudo sed -i "/^}/i $LOCATION_BLOCK" /etc/nginx/sites-available/multiusuario

# Verificar y recargar NGINX
sudo nginx -t && sudo systemctl reload nginx

# Final
echo "Proceso completado. Credenciales guardadas en: $CRED_FILE"
