#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
# Cargar variables de entorno
source /vagrant/.env
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/4] Actualizando repositorios e instalando pila LEMP ==="
apt-get update -y
apt-get install -y nginx mariadb-server php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl curl unzip

# Detectar versión de PHP instalada dinámicamente (ej. 8.2 en Debian 12)
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

echo "=== [2/4] Configurando límites de subida de 64M en PHP y Nginx ==="
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/${PHP_VER}/fpm/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 64M/' /etc/php/${PHP_VER}/fpm/php.ini

# Configurar client_max_body_size en Nginx
echo "client_max_body_size 64M;" > /etc/nginx/conf.d/uploads.conf

echo "=== [3/4] Asegurando MariaDB en local y creando BD ==="
# Garantizar que MariaDB solo escuche en localhost
sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl enable --now mariadb
systemctl enable --now php${PHP_VER}-fpm
systemctl enable --now nginx

# Crear base de datos y usuario con permisos exclusivos
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

systemctl restart mariadb php${PHP_VER}-fpm nginx
echo "=== Pila LEMP desplegada correctamente ==="