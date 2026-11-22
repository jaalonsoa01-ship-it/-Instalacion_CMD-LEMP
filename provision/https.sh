#!/bin/bash
set -e
if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
source /vagrant/.env
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

echo "=== [1/3] Generando certificado autofirmado con SAN para localhost ==="
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/wordpress.key \
    -out /etc/nginx/ssl/wordpress.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=IAW/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "=== [2/3] Configurando Virtual Host en Nginx con HTTP/2 y redirección 8080 -> 8443 ==="
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80 default_server;
    server_name localhost;
    # Redirección explícita manteniendo el puerto mapeado del anfitrión
    return 301 https://localhost:8443\$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    server_name localhost;

    ssl_certificate /etc/nginx/ssl/wordpress.crt;
    ssl_certificate_key /etc/nginx/ssl/wordpress.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/html;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress

echo "=== [3/3] Asegurando URLs HTTPS en WordPress ==="
cd /var/www/html
wp option update home "https://localhost:8443" --allow-root
wp option update siteurl "https://localhost:8443" --allow-root

nginx -t
systemctl reload nginx
echo "=== HTTPS y HTTP/2 configurados correctamente ==="