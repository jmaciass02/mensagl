#!/bin/bash

# Actualiza el sistema y asegura que los paquetes necesarios estén instalados
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Instalar paquetes necesarios
sudo DEBIAN_FRONTEND=noninteractive apt install -y openjdk-17-jre default-jre-headless wget mysql-client; sudo apt-get --fix-broken install -y

# Descargar e instalar Openfire

wget https://download.igniterealtime.org/openfire/openfire_4.9.2_all.deb -O openfire_4.9.2_all.deb && sudo dpkg -i openfire_4.9.2_all.deb; sudo apt-get --fix-broken install -y


# Habilitar y arrancar el servicio de Openfire
sudo systemctl enable openfire
sudo systemctl start openfire

# Limpiar archivos .deb descargados
rm openfire_4.9.2_all.deb
