#!/bin/bash

while true; do
    clear
    echo "===== MENÚ DE GESTIÓN DE HOSTING ====="
    echo "1. Crear cuenta de hosting"
    echo "2. Eliminar cuenta de hosting"
    echo "3. Cancelar / Salir"
    echo "======================================="
    read -p "Seleccione una opción [1-3]: " OPCION

    case "$OPCION" in
        1)
            read -p "Ingrese el número de usuario a crear (ej: 4 para usuario4): " NUM
            bash crear_cuenta_hosting.sh "$NUM"
            read -p "Presione Enter para continuar..." ;;
        2)
            read -p "Ingrese el número de usuario a eliminar (ej: 4 para usuario4): " NUM
            bash eliminar_usuarios.sh "$NUM"
            read -p "Presione Enter para continuar..." ;;
        3)
            echo "Saliendo del sistema. ¡Hasta luego!"
            exit 0 ;;
        *)
            echo "Opción inválida. Intente de nuevo."
            read -p "Presione Enter para continuar..." ;;
    esac
done
