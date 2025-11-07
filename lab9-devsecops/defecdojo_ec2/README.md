## Requisitos
1. Cuenta en AWS
2. Token de AWS
3. Perfil de conexión con el nombre k8s-labs

## Despliegue
aws ec2 create-key-pair \
  --key-name defectdojo-key \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-1 \
  --profile k8s-labs > defectdojo-key.pem

terraform init
terraform apply -auto-approve
```
## Output
```text
dojo_public_ip = "3.255.99.28"
dojo_url = "http://ec2-3-255-99-28.eu-west-1.compute.amazonaws.com:8080"
```
## Credenciales
ssh -i defectdojo-key.pem ec2-user@IP_DEL_OUTPUT
cat defectdojo_admin_credentials.log