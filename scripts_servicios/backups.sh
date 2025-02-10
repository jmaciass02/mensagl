#!/bin/bash    

# Configuración
DB_USER="openfire"
DB_PASS="_Admin123"
DB_NAME="openfire"
REMOTE_USER="ubuntu"
REMOTE_SERVER="10.217.2.150"
REMOTE_PATH="/home/ubuntu/backups/"
LOCAL_PATH="/tmp/mysql_backup"
BACKUP_DATE=$(date +\%Y-\%m-\%d_\%H-\%M-\%S)
BACKUP_FILE="mysql_backup_$BACKUP_DATE.sql"
REMOTE_BACKUP_PATH="$REMOTE_PATH$BACKUP_FILE"

# Crear un dump de la base de datos
echo "Realizando el dump de la base de datos..."
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $LOCAL_PATH/$BACKUP_FILE

# Realizar una copia incremental usando rsync
echo "Realizando la copia incremental..."
rsync -avz -e "ssh" $LOCAL_PATH/$BACKUP_FILE $REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH

# Limpiar el archivo de copia local
rm -f $LOCAL_PATH/$BACKUP_FILE
echo "Copia realizada y archivo temporal eliminado."

