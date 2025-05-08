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
PASSWORD=$(openssl rand -base64 12)  # Usamos la misma contraseña para FTP y la base de datos

# Crear usuario del sistema
echo "Creando usuario del sistema $USERNAME..."
sudo useradd -m -s /bin/bash $USERNAME
if [ $? -eq 0 ]; then
    echo "Usuario $USERNAME creado correctamente."
else
    echo "Error al crear el usuario $USERNAME."
    exit 2
fi

# Crear directorio web y public_html
echo "Creando directorio web en $WEB_DIR..."
sudo mkdir -p $WEB_DIR/public_html
sudo chown $USERNAME:$USERNAME $WEB_DIR/public_html
sudo chmod 755 $WEB_DIR/public_html
if [ $? -eq 0 ]; then
    echo "Directorio web y public_html creados correctamente."
else
    echo "Error al crear el directorio web."
    exit 3
fi

# Crear directorio /home/usuarioX si no existe y asignar permisos
USER_HOME="/home/$USERNAME"
if [ ! -d "$USER_HOME" ]; then
   echo "Creando el directorio $USER_HOME..."
    sudo mkdir -p "$USER_HOME"
    sudo chown $USERNAME:$USERNAME "$USER_HOME"
    sudo chmod 755 "$USER_HOME"
    echo "Directorio $USER_HOME creado y permisos asignados correctamente."
else
    echo "El directorio $USER_HOME ya existe."
fi

# Crear subdirectorio public_html dentro de /home/usuarioX si no existe
USER_PUBLIC_HTML="/home/$USERNAME/public_html"
if [ ! -d "$USER_PUBLIC_HTML" ]; then
    echo "Creando el directorio $USER_PUBLIC_HTML..."
    sudo mkdir -p "$USER_PUBLIC_HTML"
    sudo chown $USERNAME:$USERNAME "$USER_PUBLIC_HTML"
    sudo chmod 755 "$USER_PUBLIC_HTML"
    echo "Directorio public_html creado y permisos asignados correctamente."
else
    echo "El directorio public_html ya existe."
fi

# Crear archivo index.html con el mensaje "Hola usuario XX"
echo "Creando archivo index.html en $USER_PUBLIC_HTML..."
echo "<html><body><h1>Hola, $USERNAME</h1></body></html>" | sudo tee "$USER_PUBLIC_HTML/index.html" > /dev/null
sudo chown $USERNAME:www.data "$USER_PUBLIC_HTML/index.html"
sudo chmod -r 755 "$USER_PUBLIC_HTML/index.html"
echo "Archivo index.html creado correctamente."

# Crear base de datos y usuario de base de datos
echo "Creando base de datos y usuario de base de datos $DB_NAME..."
sudo mysql -u root -p123 <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
if [ $? -eq 0 ]; then
    echo "Base de datos $DB_NAME y usuario $DB_USER creados correctamente."
else
    echo "Error al crear la base de datos y el usuario de base de datos."
    exit 4
fi

# Configuración FTP (requiere sudo)
echo "Configurando acceso FTP para $USERNAME..."
echo "$USERNAME:$PASSWORD" | sudo chpasswd
if [ $? -eq 0 ]; then
    echo "Contraseña FTP configurada correctamente."
else
    echo "Error al configurar la contraseña FTP."
    exit 5
fi

# Crear archivo de credenciales en public_html
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

# Ejecutar el comando chmod 755 en /home/usuarioXX
echo "Ajustando permisos en /home/$USERNAME..."
sudo chmod 755 "/home/$USERNAME"

# Final
echo "Proceso completado. Credenciales guardadas en: $CRED_FILE"
