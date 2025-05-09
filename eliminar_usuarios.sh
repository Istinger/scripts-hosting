#!/bin/bash

# Comprobación de argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <número_usuario>"
    exit 1
fi

NUMERO="$1"
USERNAME="usuario$NUMERO"
DB_NAME="${USERNAME}_db"
NGINX_FILE="/etc/nginx/sites-available/multiusuario"
WEB_DIR="/var/www/$USERNAME"
HOME_DIR="/home/$USERNAME"

echo "=== Eliminando $USERNAME ==="

# 1. Eliminar usuario del sistema y su home
echo "[1] Eliminando usuario del sistema..."
if id "$USERNAME" &>/dev/null; then
    sudo deluser --remove-home "$USERNAME"
    echo "→ Usuario $USERNAME eliminado."
else
    echo "→ Usuario $USERNAME no existe, se omite."
fi

# 2. Eliminar base de datos y usuario en MariaDB
echo "[2] Eliminando base de datos y usuario en MariaDB..."
sudo mysql -u root -p123 <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF
echo "→ Base de datos y usuario eliminados."

# 3. Eliminar bloque location en archivo NGINX
echo "[3] Eliminando bloque location en NGINX..."
if grep -q "location /$USERNAME/" "$NGINX_FILE"; then
    sudo sed -i "/location \/$USERNAME\//,/^ *}/d" "$NGINX_FILE"
    echo "→ Bloque location eliminado de $NGINX_FILE."
else
    echo "→ No se encontró bloque location para $USERNAME en NGINX."
fi

# 4. Eliminar carpeta web si fue creada en /var/www
echo "[4] Eliminando carpeta web en $WEB_DIR..."
if [ -d "$WEB_DIR" ]; then
    sudo rm -rf "$WEB_DIR"
    echo "→ Carpeta $WEB_DIR eliminada."
else
    echo "→ Carpeta $WEB_DIR no existe."
fi

# 5. Recargar NGINX solo si la configuración es válida
echo "[5] Recargando NGINX..."
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "→ NGINX recargado correctamente."
else
    echo "Error de sintaxis en NGINX. Revisa $NGINX_FILE"
fi

echo "Eliminación completa de $USERNAME."
