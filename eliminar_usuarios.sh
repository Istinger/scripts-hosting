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

echo "Eliminando $USERNAME..."

# 1. Eliminar usuario del sistema y su home
sudo deluser --remove-home "$USERNAME"
if [ $? -eq 0 ]; then
    echo "Usuario $USERNAME eliminado."
else
    echo "Error al eliminar el usuario $USERNAME (puede que no exista)."
fi

# 2. Eliminar base de datos y usuario en MariaDB
echo "Eliminando base de datos y usuario en MariaDB..."
sudo mysql -u root -p123 <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "Base de datos y usuario de base de datos eliminados correctamente."
else
    echo "Error al eliminar base de datos o usuario de base de datos."
fi

# 3. Eliminar el bloque location /usuarioX/ del archivo multiusuario
echo "Eliminando configuración NGINX para $USERNAME..."
sudo sed -i "/location \/usuario$NUMERO\//,/^ *}/d" "$NGINX_FILE"

# 4. Probar y recargar NGINX
echo "Recargando NGINX..."
sudo nginx -t && sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo "NGINX recargado correctamente."
else
    echo "Error en la recarga de NGINX. Revisa el archivo $NGINX_FILE."
fi

echo "Eliminación completa de $USERNAME.

