#!/bin/bash    

# Configuration variables
REMOTE_DB_SERVER="10.218.2.200"
REMOTE_DB_PATH="/var/lib/mysql/openfire"
LOCAL_PATH="/home/ubuntu/backups/"
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="mysql_backup_$BACKUP_DATE.tar.gz"
REMOTE_SNAPSHOT_FILE="/tmp/mysql_snapshot.snar"
TEMP_SNAPSHOT_FILE="/tmp/temp_snapshot.snar"
FULL_BACKUP_FILE="full_backup_marker"

# SSH options to disable strict host key checking and specify private key
SSH_OPTIONS="-o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem"

# crear el directorio de backups si no existe
if [ ! -d "$LOCAL_PATH" ]; then
  mkdir -p "$LOCAL_PATH"
fi

# Si el archivo de snapshot no existe o el backup mas nuevo es de hace al menos una semana
if ssh $SSH_OPTIONS ubuntu@$REMOTE_DB_SERVER "[ ! -f $REMOTE_SNAPSHOT_FILE ]" || [ ! -f "$LOCAL_PATH/$FULL_BACKUP_FILE" ] || find "$LOCAL_PATH" -name "$FULL_BACKUP_FILE" -mtime +7 | grep -q "$FULL_BACKUP_FILE"; then
  # backup completo si no existe una snapshot/backup completo o el mas nuevo es de hace al menos una semana
  ssh $SSH_OPTIONS ubuntu@$REMOTE_DB_SERVER "sudo tar --listed-incremental=$TEMP_SNAPSHOT_FILE -czf - -C / $REMOTE_DB_PATH" > "$LOCAL_PATH/$BACKUP_FILE"
  
  # Move the temporary snapshot file to the final location
  ssh $SSH_OPTIONS ubuntu@$REMOTE_DB_SERVER "sudo mv $TEMP_SNAPSHOT_FILE $REMOTE_SNAPSHOT_FILE"
  
  touch "$LOCAL_PATH/$FULL_BACKUP_FILE"
else
  # backups incrementales 
  ssh $SSH_OPTIONS ubuntu@$REMOTE_DB_SERVER "sudo tar --listed-incremental=$REMOTE_SNAPSHOT_FILE -czf - -C / $REMOTE_DB_PATH" > "$LOCAL_PATH/$BACKUP_FILE"
fi

#borrando los backups mas viejos que un mes
find "$LOCAL_PATH" -name "mysql_backup_*.tar.gz" -mtime +30 -exec rm {} \;
