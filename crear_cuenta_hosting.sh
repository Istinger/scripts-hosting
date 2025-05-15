#!/bin/bash

# Buscar el siguiente número disponible para el nombre de usuario
NEXT_NUM=1
while id "usuario$NEXT_NUM" &>/dev/null; do
    ((NEXT_NUM++))
done

USERNAME="usuario$NEXT_NUM"
WEB_DIR="/var/www/$USERNAME"
DB_NAME="${USERNAME}_db"
DB_USER="${USERNAME}"
PASSWORD=$(openssl rand -base64 12)

echo "Creando cuenta para: $USERNAME"

# Crear usuario del sistema
echo "Creando usuario del sistema $USERNAME..."
sudo useradd -m -s /bin/bash "$USERNAME"
if [ $? -ne 0 ]; then
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi
echo "Usuario $USERNAME creado correctamente."

# Crear directorio web y public_html
echo "Creando directorio web en $WEB_DIR..."
sudo mkdir -p "$WEB_DIR/public_html"
sudo chown "$USERNAME:$USERNAME" "$WEB_DIR/public_html"
sudo chmod 755 "$WEB_DIR/public_html"

# Crear directorio /home/usuarioX si no existe
USER_HOME="/home/$USERNAME"
if [ ! -d "$USER_HOME" ]; then
    sudo mkdir -p "$USER_HOME"
    sudo chown "$USERNAME:$USERNAME" "$USER_HOME"
    sudo chmod 755 "$USER_HOME"
fi

# Crear public_html en /home/usuarioX
USER_PUBLIC_HTML="$USER_HOME/public_html"
if [ ! -d "$USER_PUBLIC_HTML" ]; then
    sudo mkdir -p "$USER_PUBLIC_HTML"
    sudo chown "$USERNAME:$USERNAME" "$USER_PUBLIC_HTML"
    sudo chmod 755 "$USER_PUBLIC_HTML"
fi

# Crear archivo index.html personalizado
echo "Creando archivo index.html en $USER_PUBLIC_HTML..."

sudo tee "$USER_PUBLIC_HTML/index.html" > /dev/null <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Bienvenido $USERNAME</title>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Roboto', sans-serif;
            background-color: #f4f6f8;
            color: #333;
            text-align: center;
            padding: 40px;
        }
        h1 {
            color: #2c3e50;
            font-size: 2.5em;
        }
        .info {
            margin-top: 30px;
            background-color: #ffffff;
            border-radius: 10px;
            padding: 20px;
            display: inline-block;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            text-align: left;
        }
        .info h2 {
            color: #2980b9;
        }
        .info p {
            font-size: 1.1em;
            margin: 10px 0;
        }
        code {
            background-color: #ecf0f1;
            padding: 4px 8px;
            border-radius: 4px;
            font-family: monospace;
        }
        a {
            color: #2980b9;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <h1>Hola, $USERNAME 👋</h1>
    <div class="info">
        <h2>Acceso a phpMyAdmin</h2>
        <p>URL: <a href="http://172.17.42.125:8013/phpmyadmin/" target="_blank">http://172.17.42.125:8013/phpmyadmin/</a></p>
        <p>Usuario BD: <code>$USERNAME</code></p>
        <p>Contraseña BD: <code>$PASSWORD</code></p>

        <h2>Datos para FileZilla (FTP)</h2>
        <p>Servidor: <code>172.17.42.125</code></p>
        <p>Usuario: <code>$USERNAME</code></p>
        <p>Contraseña: <code>$PASSWORD</code></p>
        <p>Puerto: <code>2113</code></p>
    </div>
</body>
</html>
EOF
sudo chown "$USERNAME:www-data" "$USER_PUBLIC_HTML/index.html"
sudo chmod 755 "$USER_PUBLIC_HTML/index.html"

# Crear base de datos y usuario
echo "Creando base de datos $DB_NAME..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configurar contraseña FTP
echo "Configurando acceso FTP..."
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Crear archivo de credenciales en /home/usuarioX
echo "Generando archivo credenciales.txt en $USER_HOME..."
CRED_FILE="$USER_HOME/credenciales.txt"
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

# Ajustar permisos finales
sudo chmod 755 "$USER_HOME"
sudo chmod o+x "$USER_HOME"
sudo chmod -R 755 "$USER_PUBLIC_HTML"
sudo chown -R www-data:www-data "$USER_PUBLIC_HTML"

# Configurar NGINX
NGINX_CONF="/etc/nginx/sites-available/multiusuario"
if ! grep -q "location /$USERNAME/" "$NGINX_CONF"; then
    sudo sed -i "/^}/i \    location /$USERNAME/ {\n        alias /home/$USERNAME/public_html/;\n        index index.html;\n        try_files \$uri \$uri/ =404;\n    }\n" "$NGINX_CONF"
    echo "Bloque location /$USERNAME/ añadido a $NGINX_CONF."
fi

# CONFIGURACIÓN NGINX - ARCHIVO usuarioX.com
SITE_CONF="/etc/nginx/sites-available/${USERNAME}.com"
PORT="80"

echo "🌐 Configurando NGINX para $USERNAME..."

sudo tee "$SITE_CONF" > /dev/null <<EOF
server {
    listen ${PORT};
    server_name ${USERNAME}.com;

    root /home/${USERNAME}/public_html;
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    error_log /var/log/nginx/${USERNAME}_error.log;
    access_log /var/log/nginx/${USERNAME}_access.log;
}
EOF

# ENLACE SIMBÓLICO EN sites-enabled
if [ ! -e "/etc/nginx/sites-enabled/${USERNAME}.com" ]; then
    sudo ln -s "$SITE_CONF" "/etc/nginx/sites-enabled/"
fi

# REVISAR Y RECARGAR NGINX
echo "Recargando NGINX..."
sudo nginx -t && sudo systemctl reload nginx

# REINICIAR VSFTPD
echo "Reiniciando vsftpd..."
sudo systemctl restart vsftpd

echo "Usuario $USERNAME creado exitosamente con acceso web, FTP y base de datos."

