#!/bin/bash

# Instalar mdadm si no está instalado
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y mdadm

# Crear RAID1
sudo mdadm --create --verbose /dev/md0 --level=1 --name=backups --raid-devices=2 /dev/xvdf /dev/xvdg --force --run

# Esperar a que el RAID esté listo
while [ "$(cat /proc/mdstat | grep -cE 'resync|recover')" -gt 0 ]; do
    echo "Esperando que el RAID termine de sincronizar..."
    sleep 5
done

# Crear sistema de archivos ext4
mkfs.ext4 /dev/md0

# Montar el RAID1
mkdir -p /mnt/raid1
mount /dev/md0 /mnt/raid1

# Obtener UUID y añadir a fstab para persistencia
UUID=$(blkid -s UUID -o value /dev/md0)
echo "UUID=$UUID  /mnt/raid1  ext4  defaults,nofail  0  0" >> /etc/fstab

# Guardar la configuración del RAID
mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf

# Actualizar initramfs
update-initramfs -u

chmod +x /home/ubuntu/backups.sh
mkdir /home/ubuntu/backups
(crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/backups.sh >/dev/null 2>&1") | crontab -
