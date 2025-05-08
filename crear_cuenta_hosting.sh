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
DOMAIN="${USERNAME}.local"
HOSTS_ENTRY="127.0.0.1 $DOMAIN"

# Crear usuario del sistema
echo "Creando usuario del sistema $USERNAME..."
sudo useradd -m -s /bin/bash $USERNAME
if [ $? -ne 0 ]; then
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi

# Crear directorio web
echo "Creando directorio web en $WEB_DIR..."
sudo mkdir -p $WEB_DIR/public_html
sudo chown $USERNAME:$USERNAME $WEB_DIR/public_html
sudo chmod 755 $WEB_DIR/public_html

# Crear carpeta personal y public_html en /home
USER_HOME="/home/$USERNAME"
USER_PUBLIC_HTML="$USER_HOME/public_html"

sudo mkdir -p "$USER_PUBLIC_HTML"
sudo chown $USERNAME:$USERNAME "$USER_PUBLIC_HTML"
sudo chmod 755 "$USER_PUBLIC_HTML"

# Crear archivo index.html
echo "<html><body><h1>Hola, $USERNAME</h1></body></html>" | sudo tee "$USER_PUBLIC_HTML/index.html" > /dev/null
sudo chown $USERNAME:www-data "$USER_PUBLIC_HTML/index.html"
sudo chmod 755 "$USER_PUBLIC_HTML/index.html"

# Crear base de datos y usuario
echo "Creando base de datos $DB_NAME y usuario $DB_USER..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configurar contraseña del sistema (FTP)
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Generar credenciales
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

# Crear configuración NGINX
NGINX_CONF="/etc/nginx/sites-available/$USERNAME"
sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /home/$USERNAME/public_html;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOF

# Activar sitio en NGINX
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

# Verificar y recargar NGINX
if sudo nginx -t; then
    sudo systemctl reload nginx
else
    echo "Error en la configuración de NGINX. Abortando..."
    exit 6
fi

# Añadir entrada al /etc/hosts si no existe
if ! grep -q "$HOSTS_ENTRY" /etc/hosts; then
    echo "Añadiendo $DOMAIN a /etc/hosts..."
    echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
    echo "Dominio $DOMAIN añadido a /etc/hosts correctamente."
else
    echo "El dominio $DOMAIN ya está en /etc/hosts."
fi

# Ajustar permisos del home
sudo chmod 755 "$USER_HOME"

# Fin
echo "Cuenta de hosting $USERNAME creada correctamente."
echo "Puedes acceder desde: http://$DOMAIN"
echo "Credenciales guardadas en: $CRED_FILE"

