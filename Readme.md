# Instalación de CMS en pila LEMP  
## Indice
1. Introducción, explicando qué se va a realizar y sobre qué infraestructura.
2. Scripts
3. Auditoría
4. Problemas Encontrados
5. Bibliografía

## Introducción

Se desea desplegar el CMS WordPress en una única máquina con una pila LEMP (Nginx, PHP-FPM y MariaDB), su infraestructura usara una Debian 12 desplegada con Vagrant (box debian/bookworm64) + VirtualBox, con nombre lempJoaquinAlejandroAlonsoAdams, sin hacer nada a mano, siendo que todo el despliegue se hará con un ``vagrant up``. Además, la web se servirá por HTTPS, se reforzará su seguridad y se auditará con WPScan. Poseerá puertos mapeados, siendo el 8080 del anfitrión  al 80 de la máquina (guest HTTP) y el 8443 al 443 (guest HTTPS). 

El objetivo es disponer de un entorno reproducible, seguro y listo para desarrollo o pruebas, sin intervención manual.

## Explicación rápida de Scripts

### `lemp.sh`
- Comprobar que el usuario es root (por los permisos y buscar las variables de entorno:
```
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
# Cargar variables de entorno
source /vagrant/.env
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)
export DEBIAN_FRONTEND=noninteractive
```

- Actualizar repositorios e instalar pila LEMP con las extensiones necesarias para WordPress (`php-mysql`, `php-curl`, `php-gd`, `php-mbstring`, `php-xml`, etc.), junto a la detección de la versión de PHO
```
apt-get update -y
apt-get install -y nginx mariadb-server php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl curl unzip
# Detectar versión de PHP instalada dinámicamente (ej. 8.2 en Debian 12)
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
```

- Configurando límites de subida de 64M en PHP y el client_max_body_size en Nginx
```
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/${PHP_VER}/fpm/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 64M/' /etc/php/${PHP_VER}/fpm/php.ini
# Configurar client_max_body_size en Nginx
echo "client_max_body_size 64M;" > /etc/nginx/conf.d/uploads.conf
```

- Asegurando MariaDB en local y creando BD, configurada para escuchar únicamente en `127.0.0.1`
```
sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl enable --now mariadb
systemctl enable --now php${PHP_VER}-fpm
systemctl enable --now nginx
```

- Crea la base de datos `wordpress` y un usuario con permisos solo sobre ella.
```
# Crear base de datos y usuario con permisos exclusivos
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
systemctl restart mariadb php${PHP_VER}-fpm nginx
```

### `wordpress.sh`
Utiliza **WP-CLI** para instalar y configurar WordPress de forma desatendida:
- Comprobar que el usuario es root (por los permisos y buscar las variables de entorno:
```
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then echo "Error: Ejecuta este script con sudo (sudo $0)"; exit 1; fi
# Cargar variables de entorno
source /vagrant/.env
# source "$(dirname "$0")/.env" (Este es el usado para pruebas manuales)
export DEBIAN_FRONTEND=noninteractive
```

- Instalando WP-CLI
```
if [ ! -f /usr/local/bin/wp ]; then
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi
```

- Descargar e instalar Wordpress
```
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
```

- Configurando ajustes, tema, plugins, usuarios y contenido.
```
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
```

- Aplicando propietario y permisos estrictos
```
chown -R www-data:www-data ${WEB_ROOT}
find ${WEB_ROOT} -type d -exec chmod 755 {} \;
find ${WEB_ROOT} -type f -exec chmod 644 {} \;
chmod 640 ${WEB_ROOT}/wp-config.php
```



### `https.sh`
Habilita HTTPS:
- Genera un **certificado autofirmado** con SAN para `localhost` y `127.0.0.1`.
```
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/wordpress.key \
    -out /etc/nginx/ssl/wordpress.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=IAW/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

- Configurando Virtual Host en Nginx con HTTP/2 y redirección 8080 -> 8443
```
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
```
- Asegurando URLs HTTPS en WordPress
```
cd /var/www/html
wp option update home "https://localhost:8443" --allow-root
wp option update siteurl "https://localhost:8443" --allow-root

nginx -t
systemctl reload nginx
```

- Actualiza las opciones `siteurl` y `home` de WordPress a `https://localhost:8443` y reemplaza cualquier referencia residual a `http://` para evitar contenido mixto.
```

```

### `security.sh`
Aplica el refuerzo de seguridad:
- Añade `define('DISALLOW_FILE_EDIT', true);` en `wp-config.php` para prohibir la edición de temas y plugins desde el panel.
```

```

- Elimina la meta etiqueta de versión de WordPress y oculta la versión de Nginx (`server_tokens off;`).
```

```

- Elimina `readme.html` y `license.txt`.
```

```

- Configura el plugin **Limit Login Attempts Reloaded** (3 intentos, 20 minutos de bloqueo).
```

```

- Añade cabeceras de seguridad en Nginx (`X-Frame-Options`, `X-Content-Type-Options`, etc.).
```

```

Tras comprobar que todo funciona, lo organizamos con el siguiente formato, añadiendo el siguiente vagrantfile


Despues de eso, nos metemos en consola de comandos (CMD) e indicamos Vagrant up

Nota 1: Si os sale un error por salto de linea, se recomienda usar estos dos comandos

```
# Transformar saltos de windows a saltos de linux
Get-ChildItem -Include *.env,*.sh -Recurse -File | ForEach-Object {
    $contenido = [System.IO.File]::ReadAllText($_.FullName) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($_.FullName, $contenido)
}
```

Si no os funciona, podeis usar este otro comando

```
foreach ($f in @(".env", ".env.example")) {
    if (Test-Path $f) {
        $c = [System.IO.File]::ReadAllText((Resolve-Path $f)) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Resolve-Path $f), $c)
    }
}
```
Para reanudar el proceso, siempre podemos retomar el proceso:
```
vagrant provision
```




## Bibliografía
- Documentación oficial de Vagrant: https://www.vagrantup.com/docs
- Documentación oficial de Nginx: https://nginx.org/en/docs/
- Documentación oficial de WP-CLI: https://wp-cli.org/
- WPScan: https://wpscan.com/
- Guía de seguridad de WordPress: https://wordpress.org/support/article/hardening-wordpress/
- Checklist de seguridad para WordPress (UNAM): https://www.seguridad.unam.mx/sites/default/files/checklist_wordpress.pdf
