Instalación de CMS en pila LEMP  
Se desea desplegar el CMS WordPress en una única máquina con una pila LEMP (Nginx, PHP-FPM y MariaDB), igual que en la práctica guiada de clase, pero esta vez sin hacer nada a mano: todo el despliegue se hará con un vagrant up. Además, la web se servirá por HTTPS, se reforzará su seguridad y se auditará con WPScan.  

Con respecto a la infraestructura:  
* Una máquina Debian 12 desplegada con Vagrant (box debian/bookworm64) + VirtualBox, con nombre lempTuNombre. 
* Puertos mapeados: el 8080 del anfitrión al 80 de la máquina y el 8443 al 443. 

# Procedimiento

Recomendación: Para asegurarte de que los scripts funcionan de forma correcta, recomiendo personalmente, probar los scripts en una maquina virtual y probarlas manualmente antes de usar vagrant.

Los resultados esperados al usar cada script seran los siguientes

1. lemp.sh

2. wordpress.sh

3. https.sh

4. security.sh

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