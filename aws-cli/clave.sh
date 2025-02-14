# Crear par de claves SSH y almacenar la clave en una variable
PEM_KEY=$(aws ec2 create-key-pair \
    --key-name "${KEY_NAME}" \
    --query "KeyMaterial" \
    --output text)

# Guardar la clave en un archivo
echo "${PEM_KEY}" > "${KEY_NAME}.pem"
chmod 400 "${KEY_NAME}.pem"
echo "Clave SSH creada y almacenada en: ${KEY_NAME}.pem"

# Usar la variable PEM_KEY en otros comandos
echo "Contenido de la clave SSH almacenada en variable:"
echo "${PEM_KEY}"