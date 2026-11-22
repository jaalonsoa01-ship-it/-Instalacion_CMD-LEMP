Vagrant.configure("2") do |config|
  # Imagen base Debian 12 solicitada
  config.vm.box = "debian/bookworm64"

  # Nombre de la MV y hostname
  config.vm.hostname = "lempJoaquinAlejandroAlonsoAdams"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "lempJoaquinAlejandroAlonsoAdams"
    vb.memory = "1024"
    vb.cpus = 2
  end

  # Mapeo de puertos: 8080 -> 80 y 8443 -> 443
  config.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: false
  config.vm.network "forwarded_port", guest: 443, host: 8443, auto_correct: false

  # Ejecución secuencial de los scripts de aprovisionamiento
  config.vm.provision "shell", path: "provision/lemp.sh"
  config.vm.provision "shell", path: "provision/wordpress.sh"
  config.vm.provision "shell", path: "provision/https.sh"
  config.vm.provision "shell", path: "provision/security.sh"
end