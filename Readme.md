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

## Scripts

### `lemp.sh`
Instala y configura la pila LEMP:
- **Nginx** como servidor web.
- **PHP-FPM** con las extensiones necesarias para WordPress (`php-mysql`, `php-curl`, `php-gd`, `php-mbstring`, `php-xml`, etc.).
- **MariaDB**, configurada para escuchar únicamente en `127.0.0.1`.
- Crea la base de datos `wordpress` y un usuario con permisos solo sobre ella.
- Ajusta los límites de subida de PHP y Nginx a **64 MB**.
- Define un virtual host básico para WordPress en el puerto 80.

### `wordpress.sh`
Utiliza **WP-CLI** para instalar y configurar WordPress de forma desatendida:
- Descarga WordPress en español (`--locale=es_ES`).
- Crea `wp-config.php` con las credenciales de la base de datos.
- Instala el sitio con el título, usuario administrador (distinto de `admin`) y correo definidos en `.env`.
- Configura la zona horaria `Europe/Madrid` y enlaces permanentes con `/%postname%/`.
- Instala y activa el tema **Astra** y los plugins **Wordfence** y **Limit Login Attempts Reloaded**.
- Crea tres usuarios adicionales con roles de editor, autor y colaborador.
- Genera una página y dos entradas de ejemplo.
- Ajusta propietario (`www-data:www-data`) y permisos: carpetas `755`, ficheros `644`, `wp-config.php` `640`.

### `https.sh`
Habilita HTTPS:
- Genera un **certificado autofirmado** con SAN para `localhost` y `127.0.0.1`.
- Configura Nginx para escuchar en el puerto 443 con **HTTP/2**.
- Redirige todo el tráfico HTTP a `https://localhost:8443` (respetando el puerto mapeado).
- Actualiza las opciones `siteurl` y `home` de WordPress a `https://localhost:8443` y reemplaza cualquier referencia residual a `http://` para evitar contenido mixto.

### `security.sh`
Aplica el refuerzo de seguridad:
- Añade `define('DISALLOW_FILE_EDIT', true);` en `wp-config.php` para prohibir la edición de temas y plugins desde el panel.
- Elimina la meta etiqueta de versión de WordPress y oculta la versión de Nginx (`server_tokens off;`).
- Elimina `readme.html` y `license.txt`.
- Configura el plugin **Limit Login Attempts Reloaded** (3 intentos, 20 minutos de bloqueo).
- Añade cabeceras de seguridad en Nginx (`X-Frame-Options`, `X-Content-Type-Options`, etc.).
- 
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
