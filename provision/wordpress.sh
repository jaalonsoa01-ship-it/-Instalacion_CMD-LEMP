#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
source /vagrant/.env
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)

WEB_ROOT="/var/www/html"
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

echo "=== [1/4] Instalando WP-CLI ==="
if [ ! -f /usr/local/bin/wp ]; then
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

echo "=== [2/4] Descargando e instalando WordPress ==="
rm -rf ${WEB_ROOT}/*
cd ${WEB_ROOT}

wp core download --allow-root

wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --dbhost="localhost" \
    --allow-root

wp core install \
    --url="${WP_URL}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASS}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root

wp language core install "${WP_LOCALE}" --activate --allow-root

echo "=== [3/4] Configurando ajustes, tema, plugins, usuarios y contenido ==="
# Zona horaria y enlaces permanentes
wp option update timezone_string "${WP_TIMEZONE}" --allow-root
wp rewrite structure '/%postname%/' --hard --allow-root

# Tema distinto al de por defecto y limpieza de inactivos si se desea
wp theme install ${WP_THEME} --activate --allow-root

# Instalar y activar al menos 2 plugins
for plugin in ${WP_PLUGINS}; do
    wp plugin install ${plugin} --activate --allow-root
done

# Crear los 3 usuarios adicionales (editor, autor, colaborador)
wp user create "${WP_EDITOR_USER}" "${WP_EDITOR_EMAIL}" --role=editor --user_pass="${WP_EDITOR_PASS}" --allow-root
wp user create "${WP_AUTHOR_USER}" "${WP_AUTHOR_EMAIL}" --role=author --user_pass="${WP_AUTHOR_PASS}" --allow-root
wp user create "${WP_CONTRIB_USER}" "${WP_CONTRIB_EMAIL}" --role=contributor --user_pass="${WP_CONTRIB_PASS}" --allow-root

# Crear 1 página y 2 entradas
wp post create --post_type=page --post_title="Sobre el Proyecto LEMP" --post_content="Página de información del despliegue automatizado." --post_status=publish --allow-root
wp post create --post_type=post --post_title="Primera entrada automatizada" --post_content="Desplegado mediante Vagrant y WP-CLI." --post_status=publish --allow-root
wp post create --post_type=post --post_title="Segunda entrada de prueba" --post_content="Verificando enlaces permanentes y pila LEMP." --post_status=publish --allow-root

echo "=== [4/4] Aplicando propietario y permisos estrictos ==="
chown -R www-data:www-data ${WEB_ROOT}
find ${WEB_ROOT} -type d -exec chmod 755 {} \;
find ${WEB_ROOT} -type f -exec chmod 644 {} \;
chmod 640 ${WEB_ROOT}/wp-config.php

echo "=== WordPress configurado correctamente ==="