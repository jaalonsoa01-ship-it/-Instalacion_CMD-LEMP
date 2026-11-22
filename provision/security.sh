#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
source /vagrant/.env 
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)

WEB_ROOT="/var/www/html"

if [ -d /vagrant ]; then
    OUT_DIR="/vagrant"
else
    OUT_DIR="$(cd "$(dirname "$0")" && pwd)/log" # Es usado para comprobar que los ficheros se generaban correctamente
                                                 # Siempre se recomienda hacerlo en carpetas aparte
fi

echo "=== [1/4] Instalando WPScan y Fail2ban ==="
export DEBIAN_FRONTEND=noninteractive
apt-get install -y ruby ruby-dev build-essential libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev zlib1g-dev fail2ban
if ! command -v wpscan &> /dev/null; then
    gem install wpscan --no-document
fi

# Descargar/actualizar la base de datos inicial de WPScan (obligatorio en instalaciones nuevas)
wpscan --update

echo "=== [2/4] Ejecutando WPScan ANTES del refuerzo ==="
wpscan --url https://localhost --disable-tls-checks --no-update --enumerate u,vp,vt -o "${OUT_DIR}/wpscan_antes.txt" -f cli || true

echo "=== [3/4] Aplicando medidas de hardening ==="
# 1. Ocultar versión de Nginx
sed -i 's/# server_tokens off;/server_tokens off;/' /etc/nginx/nginx.conf

# 2. Eliminar ficheros que exponen información innecesaria
rm -f ${WEB_ROOT}/readme.html ${WEB_ROOT}/license.txt

# 3. Bloquear edición de ficheros desde el panel y forzar SSL en admin
cd ${WEB_ROOT}
wp config set DISALLOW_FILE_EDIT true --raw --allow-root
wp config set FORCE_SSL_ADMIN true --raw --allow-root

# 4. Ocultar versión de WordPress en el código fuente (mu-plugin limpio)
mkdir -p ${WEB_ROOT}/wp-content/mu-plugins
cat > ${WEB_ROOT}/wp-content/mu-plugins/ocultar-version.php <<'EOF'
<?php
remove_action('wp_head', 'wp_generator');
add_filter('the_generator', '__return_empty_string');
EOF

# 5. Bloquear acceso a xmlrpc.php y añadir cabeceras de seguridad en Nginx
cat > /etc/nginx/conf.d/security.conf <<'EOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
EOF

if ! grep -q "xmlrpc.php" /etc/nginx/sites-available/wordpress; then
    sed -i '/location ~ \\.ht/i \    location = /xmlrpc.php { deny all; }\n' /etc/nginx/sites-available/wordpress
fi

# 6. Configurar Fail2ban para proteger wp-login.php contra fuerza bruta
cat > /etc/fail2ban/filter.d/wordpress.conf <<'EOF'
[Definition]
failregex = ^<HOST> .* "POST /wp-login.php
ignoreregex =
EOF

cat > /etc/fail2ban/jail.d/wordpress.conf <<'EOF'
[wordpress]
enabled = true
port = http,https
filter = wordpress
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 600
EOF

# Reaplicar propietario y permisos estrictos tras crear mu-plugins
chown -R www-data:www-data ${WEB_ROOT}
find ${WEB_ROOT} -type d -exec chmod 755 {} \;
find ${WEB_ROOT} -type f -exec chmod 644 {} \;
chmod 640 ${WEB_ROOT}/wp-config.php

nginx -t
systemctl restart nginx fail2ban

echo "=== [4/4] Ejecutando WPScan DESPUÉS del refuerzo ==="
wpscan --url https://localhost --disable-tls-checks --no-update --enumerate u,vp,vt -o "${OUT_DIR}/wpscan_despues.txt" -f cli || true

echo "=== Auditoría y refuerzo completados ==="