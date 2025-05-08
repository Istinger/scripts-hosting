#!/bin/bash

# Comprobación de argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <número_usuario>"
    exit 1
fi

NUMERO="$1"  # No usamos printf "%02d" para evitar el cero inicial
USERNAME="usuario$NUMERO"
DB_NAME="${USERNAME}_db"
NGINX_CONF="/etc/nginx/sites-available/$USERNAME"

echo "Eliminando $USERNAME..."

# 1. Eliminar usuario del sistema
sudo deluser --remove-home "$USERNAME"
if [ $? -eq 0 ]; then
    echo "Usuario $USERNAME eliminado."
else
    echo "Error al eliminar el usuario $USERNAME (puede que no exista)."
fi

# 2. Eliminar base de datos y usuario en MariaDB con contraseña root (123)
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

# 3. Eliminar configuración de NGINX
if [ -f "$NGINX_CONF" ]; then
    sudo rm -f "/etc/nginx/sites-enabled/$USERNAME"
    sudo rm -f "$NGINX_CONF"
    echo "Configuración de NGINX eliminada."
    sudo nginx -t && sudo systemctl reload nginx
else
    echo "No se encontró configuración NGINX para $USERNAME."
fi

echo "Eliminación completa de $USERNAME."

