#!/bin/bash

# Buscar el siguiente número de usuario disponible automáticamente
NEXT_NUM=$(ls /home | grep '^usuario[0-9]\+$' | sed 's/usuario//' | sort -n | tail -n 1)
if [ -z "$NEXT_NUM" ]; then
    NEXT_NUM=1
else
    NEXT_NUM=$((NEXT_NUM + 1))
fi

# Variables base
USERNAME="usuario$NEXT_NUM"
USER_HOME="/home/$USERNAME"
WEB_DIR="$USER_HOME/public_html"
DB_NAME="${USERNAME}_db"
DB_USER="${USERNAME}"
PASSWORD=$(openssl rand -base64 12)

# Crear usuario del sistema
echo "Creando usuario del sistema $USERNAME..."
sudo useradd -m -s /bin/bash "$USERNAME"
if [ $? -ne 0 ]; then
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi

# Crear directorio public_html
echo "Creando directorio web en $WEB_DIR..."
sudo mkdir -p "$WEB_DIR"
sudo chown $USERNAME:$USERNAME "$WEB_DIR"
sudo chmod 755 "$WEB_DIR"

# Crear archivo index.html
echo "Creando archivo index.html..."
sudo tee "$WEB_DIR/index.html" > /dev/null <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Bienvenido $USERNAME</title>
    <style>
        body { font-family: sans-serif; background-color: #f4f6f8; text-align: center; padding: 40px; }
        h1 { color: #2c3e50; font-size: 2.5em; }
    </style>
</head>
<body>
    <h1>Hola, $USERNAME 👋</h1>
    <p>Tu cuenta ha sido creada con éxito.</p>
</body>
</html>
EOF

sudo chown $USERNAME:$USERNAME "$WEB_DIR/index.html"
sudo chmod 644 "$WEB_DIR/index.html"

# Crear archivo credenciales.txt en /home/usuarioX (NO en public_html)
echo "Generando archivo credenciales.txt en $USER_HOME..."
CRED_FILE="$USER_HOME/credenciales.txt"
sudo tee "$CRED_FILE" > /dev/null <<EOF
Credenciales para la cuenta de hosting $USERNAME:

Usuario del sistema: $USERNAME
Contraseña (FTP y Base de Datos): $PASSWORD

Base de Datos: $DB_NAME
Usuario Base de Datos: $DB_USER

Acceso a phpMyAdmin:
http://172.17.42.125:8013/phpmyadmin/

Acceso FTP:
Servidor: 172.17.42.125
Puerto: 2113
EOF

sudo chown $USERNAME:$USERNAME "$CRED_FILE"
sudo chmod 600 "$CRED_FILE"

# Crear base de datos y usuario
echo "Creando base de datos y usuario MySQL..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configurar FTP
echo "Configurando acceso FTP..."
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Configuración NGINX
NGINX_CONF="/etc/nginx/sites-available/multiusuario"
if ! grep -q "location /$USERNAME/" "$NGINX_CONF"; then
    sudo sed -i "/^}/i \    location /$USERNAME/ {\n        alias /home/$USERNAME/public_html/;\n        index index.html;\n        try_files \$uri \$uri/ =404;\n    }\n" "$NGINX_CONF"
    echo "Bloque location /$USERNAME/ añadido."
fi

# Recargar servicios
echo "Recargando NGINX y reiniciando vsftpd..."
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart vsftpd

echo "Permisos finales en /home/$USERNAME/public_html..."
sudo chmod -R 755 "$WEB_DIR"
sudo chown -R $USERNAME:$USERNAME "$WEB_DIR"

echo "Usuario $USERNAME creado correctamente con credenciales guardadas en: $CRED_FILE"

