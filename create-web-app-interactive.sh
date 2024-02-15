#!/bin/bash

# Función para verificar e instalar Zenity
check_install_zenity() {
    if ! command -v zenity &>/dev/null; then
        echo "Zenity no está instalado. Intentando instalar Zenity..."
        if [[ -f /etc/debian_version ]]; then
            sudo apt-get update && sudo apt-get install zenity
            elif [[ -f /etc/redhat-release ]]; then
            sudo dnf install zenity
            elif [[ -f /etc/arch-release ]]; then
            sudo pacman -Sy zenity
        else
            echo "No se pudo determinar el gestor de paquetes. Instala Zenity manualmente."
            exit 1
        fi
        if ! command -v zenity &>/dev/null; then
            echo "La instalación de Zenity ha fallado. Instala Zenity manualmente e intenta de nuevo."
            exit 1
        fi
    fi
}

# Función para verificar e instalar ImageMagick
check_install_imagemagick() {
    if ! command -v convert &>/dev/null; then
        echo "ImageMagick no está instalado. Intentando instalar ImageMagick..."
        if [[ -f /etc/debian_version ]]; then
            sudo apt-get update && sudo apt-get install imagemagick
            elif [[ -f /etc/redhat-release ]]; then
            sudo dnf install imagemagick
            elif [[ -f /etc/arch-release ]]; then
            sudo pacman -Sy imagemagick
        else
            echo "No se pudo determinar el gestor de paquetes. Instala ImageMagick manualmente."
            exit 1
        fi
        if ! command -v convert &>/dev/null; then
            echo "La instalación de ImageMagick ha fallado. Instala ImageMagick manualmente e intenta de nuevo."
            exit 1
        fi
    fi
}

# Verificar e instalar Zenity e ImageMagick antes de proceder
check_install_zenity
check_install_imagemagick

install() {
    # Función para crear el script de inicio de la aplicación
    create_startup_script() {
        local app_name="$1"
        local url="$2"
        local script_path="$3/start-$app_name.sh"
        local icon_path="$4"
        
        # Crear el script de inicio
        echo "#!/bin/bash
PROFILE_DIR=\"\$HOME/.config/$app_name-chrome-profile\"
URL=\"$url\"
CLASS=\"$app_name\"

        google-chrome --app=\"\$URL\" --user-data-dir=\"\$PROFILE_DIR\" --class=\"\$CLASS\" &" > "$script_path"
        
        # Hacer el script ejecutable
        chmod +x "$script_path"
    }
    
    # Función para crear el archivo .desktop
    create_desktop_entry() {
        local app_name="$1"
        local script_path="$2"
        local desktop_file_path="$3/$app_name.desktop"
        local icon_path="$4"
        
        # Crear el archivo .desktop
        echo "[Desktop Entry]
Name=$app_name
Exec=$script_path
Type=Application
Terminal=false
Icon=$icon_path
X-GNOME-Autostart-enabled=$autostart_enabled
StartupWMClass=$app_name" > "$desktop_file_path"
    }
    
    # Función para crear el enlace en autostart
    create_autostart_link() {
        local app_name="$1"
        local desktop_file_path="$2"
        local autostart_path="$3"
        
        # Crear el enlace simbólico en la carpeta autostart
        ln -sf "$desktop_file_path" "$autostart_path"
    }
    
    # Solicitar al usuario la información de la aplicación usando Zenity
    app_name=$(zenity --entry --title="Crear aplicación web" --text="Introduce el nombre de la aplicación (sin espacios):")
    app_url=$(zenity --entry --title="Crear aplicación web" --text="Introduce la URL de la aplicación:")
    icon_path=$(zenity --file-selection --title="Selecciona un ícono para la aplicación" --file-filter="*.png *.svg *.xpm" --save --confirm-overwrite)
    # Preguntar si el programa debe iniciar automáticamente
    autostart=$(zenity --list --title="Inicio automático" --text="¿Quieres que la aplicación se inicie automáticamente al encender el equipo?" --radiolist  --column "Seleccionar" --column "Opción" FALSE "Sí" TRUE "No" --hide-header)
    autostart_enabled="true"
    if [ "$autostart" == "No" ]; then
        autostart_enabled="false"
    fi

    # Comprobar si el usuario ha cancelado el proceso
    if [ -z "$app_name" ] || [ -z "$app_url" ] || [ -z "$icon_path" ]; then
        zenity --error --text="Creación de aplicación web cancelada."
        exit 1
    fi
    
    # Definir las rutas de los directorios
    SCRIPT_DIR="$HOME/scripts/chrome-apps"
    DESKTOP_FILE_DIR="$HOME/.local/share/applications"
    AUTOSTART_DIR="$HOME/.config/autostart"
    ICON_DIR="$HOME/icons"
    
    # Crear directorios si no existen
    mkdir -p "$SCRIPT_DIR" "$DESKTOP_FILE_DIR" "$AUTOSTART_DIR" "$ICON_DIR"
    
    # Copiar el ícono seleccionado al directorio de íconos
    # Asegurarse de que el nombre del archivo del ícono mantenga su extensión original
    extension="${icon_path##*.}"
    new_icon_path="$ICON_DIR/${app_name}-icon.$extension"
    
    # Usar ImageMagick para redimensionar el ícono manteniendo la proporción
    convert "$icon_path" -resize 128x128 "$new_icon_path"
    
    # Actualizar la ruta del ícono para reflejar la nueva ubicación
    icon_path="$new_icon_path"
    
    # Llamar a las funciones para crear los archivos necesarios
    create_startup_script "$app_name" "$app_url" "$SCRIPT_DIR" "$icon_path"
    create_desktop_entry "$app_name" "$SCRIPT_DIR/start-$app_name.sh" "$DESKTOP_FILE_DIR" "$icon_path"
    create_autostart_link "$app_name" "$DESKTOP_FILE_DIR/$app_name.desktop" "$AUTOSTART_DIR/$app_name.desktop"
    
    zenity --info --text="$app_name ha sido configurado correctamente."
}

uninstall() {
    # Solicitar al usuario el nombre de la aplicación a desinstalar
    app_name=$(zenity --entry --title="Desinstalar aplicación web" --text="Introduce el nombre de la aplicación a desinstalar:")
    # Comprobar si el usuario ha cancelado el proceso
    if [ -z "$app_name" ]; then
        zenity --error --text="Desinstalación de aplicación web cancelada."
        exit 1
    fi
    
    # Definir las rutas de los archivos a eliminar
    SCRIPT_DIR="$HOME/scripts/chrome-apps"
    DESKTOP_FILE_DIR="$HOME/.local/share/applications"
    AUTOSTART_DIR="$HOME/.config/autostart"
    ICON_DIR="$HOME/icons"
    
    # Eliminar los archivos y directorios relacionados con la aplicación
    rm -f "$SCRIPT_DIR/start-$app_name.sh"
    rm -f "$DESKTOP_FILE_DIR/$app_name.desktop"
    rm -f "$AUTOSTART_DIR/$app_name.desktop"
    rm -f "$ICON_DIR/$app_name-icon.*"
    
    zenity --info --text="$app_name ha sido desinstalado correctamente."
}

# Mostrar un diálogo de selección para instalar o desinstalar la aplicación
action=$(zenity --list --title="Crear o desinstalar aplicación web" --column="Acción" "Instalar" "Desinstalar")

# Llamar a la función correspondiente según la acción seleccionada
case $action in
    "Instalar")
        install
    ;;
    "Desinstalar")
        uninstall
    ;;
    *)
        zenity --error --text="Acción no válida."
        exit 1
    ;;
esac
