#!/bin/bash

# ================================
# SCRIPT PARA ELIMINAR UNA CUENTA
# ================================

# Comprobación de argumento
if [ -z "$1" ]; then
    echo "❌ Uso: $0 <número_usuario>"
    exit 1
fi

NUMERO="$1"
USERNAME="usuario$NUMERO"
DB_NAME="${USERNAME}_db"
SITE_CONF="/etc/nginx/sites-available/${USERNAME}.com"
SITE_LINK="/etc/nginx/sites-enabled/${USERNAME}.com"
WEB_DIR="/var/www/$USERNAME"
USER_HOME="/home/$USERNAME"
NGINX_MULTI="/etc/nginx/sites-available/multiusuario"

echo "Eliminando cuenta: $USERNAME "

# 1. Eliminar usuario del sistema y su home
echo "[1] 🧹 Eliminando usuario del sistema..."
if id "$USERNAME" &>/dev/null; then
    sudo deluser --remove-home "$USERNAME"
    echo "Usuario $USERNAME eliminado."
else
    echo "Usuario $USERNAME no existe, se omite."
fi

# 2. Eliminar base de datos y usuario MySQL
echo "[2] Eliminando base de datos y usuario en MySQL..."
sudo mysql -u root -p123 <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF
echo "Base de datos y usuario eliminados."

# 3. Eliminar bloque location en multiusuario
echo "[3] Eliminando bloque location en $NGINX_MULTI..."
if grep -q "location /$USERNAME/" "$NGINX_MULTI"; then
    sudo sed -i "/location \/$USERNAME\//,/^ *}/d" "$NGINX_MULTI"
    echo "Bloque location eliminado de $NGINX_MULTI."
else
    echo "No se encontró bloque location para $USERNAME."
fi

# 4. Eliminar archivo de configuración personalizado
echo "[4] Eliminando configuración NGINX personalizada..."
if [ -f "$SITE_CONF" ]; then
    sudo rm -f "$SITE_CONF"
    echo "$SITE_CONF eliminado."
fi

if [ -L "$SITE_LINK" ]; then
    sudo rm -f "$SITE_LINK"
    echo "Enlace simbólico $SITE_LINK eliminado."
fi

# 5. Eliminar carpeta web en /var/www
echo "[5] Eliminando carpeta en $WEB_DIR..."
if [ -d "$WEB_DIR" ]; then
    sudo rm -rf "$WEB_DIR"
    echo "Carpeta $WEB_DIR eliminada."
else
    echo "Carpeta $WEB_DIR no existe."
fi

# 6. Eliminar carpeta public_html en /home/usuarioX si queda
if [ -d "$USER_HOME/public_html" ]; then
    sudo rm -rf "$USER_HOME/public_html"
    echo "public_html en $USER_HOME eliminado."
fi

# 7. Eliminar archivo de logs si existen
echo "[6] Eliminando logs de NGINX si existen..."
sudo rm -f "/var/log/nginx/${USERNAME}_error.log"
sudo rm -f "/var/log/nginx/${USERNAME}_access.log"
echo "Logs eliminados."

# 8. Recargar NGINX
echo "[7] Recargando NGINX..."
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "NGINX recargado correctamente."
else
    echo "Error al probar configuración de NGINX."
fi

# 9. Reiniciar vsftpd
echo "[8] Reiniciando vsftpd..."
sudo systemctl restart vsftpd

echo "Eliminación completa de la cuenta: $USERNAME"

