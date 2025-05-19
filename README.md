# 🌐 Proyecto: Hosting Web Multiusuario en LinuxLab

Este proyecto implementa una solución completa de **hosting web multiusuario** en una máquina virtual Ubuntu Server, ideal para fines educativos en el entorno LinuxLab.

---

## 🚀 ¿Qué hicimos?

Desplegamos un **servidor web multiusuario** con las siguientes herramientas clave:

- ✅ **Servidor Web – NGINX**  
  Aloja sitios web personales para cada estudiante.  
  Acceso: `http://192.17.42.125:8013/usuario01/`

- ✅ **Servidor de Base de Datos – MariaDB**  
  Cada usuario tiene su propia base de datos con acceso restringido.

- ✅ **phpMyAdmin**  
  Herramienta web para administrar bases de datos MariaDB.  
  Acceso: `http://192.17.42.125:8013/phpmyadmin`

- ✅ **Servidor FTP – vsftpd**  
  Permite a los usuarios subir archivos a sus sitios web de forma segura.

- ✅ **Script Bash de Automatización**  
  Crea automáticamente cuentas de hosting para los estudiantes.

---

## ⚙️ ¿Qué hace el script?

Nuestro script automatiza el proceso de creación de cuentas de hosting web:

- 🧑‍💻 Crea un **usuario del sistema** (ejemplo: `usuario05`)
- 📂 Crea su directorio web en `/home/usuario05/public_html`
- 🌐 Genera un archivo `index.html` de bienvenida
- 🛡️ Crea una **base de datos MariaDB** y un usuario asociado
- 🔐 Genera **contraseñas aleatorias** para FTP y la base de datos
- 🧩 Inserta automáticamente un bloque `location` en el archivo de configuración de NGINX
- 📝 Genera un archivo `credenciales.txt` con todos los accesos del usuario

### ▶️ Ejecución del script

```bash
sudo ./nombre_script.sh
📋 Requisitos
🐧 Ubuntu Server 20.04 o superior

🌐 NGINX

🐘 PHP + PHP-FPM

🛢️ MariaDB

🧰 phpMyAdmin

📡 vsftpd

👨‍💻 Autores
👨‍🎓 Antony Cajamarca

👨‍🎓 Patricio Proaño

🖥️ Entorno de desarrollo: LinuxLab (vhost13)

🎓 Universidad: Universidad Politécnica Salesiana
