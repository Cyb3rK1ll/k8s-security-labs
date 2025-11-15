## Terraform para OpenCTI + MISP (AWS)

Este módulo crea la infraestructura mínima para replicar el entorno Docker/Portainer en AWS:

- VPC propia con una subred pública.
- Internet Gateway y tabla de rutas.
- Security Group que expone SSH (22), HTTP/HTTPS (80/443), Portainer (9443) y accesos directos a OpenCTI (8080) y MISP (8443).
- Instancia EC2 Ubuntu 22.04 con `user-data` que instala Docker CE, habilita Portainer CE y deja todo listo para desplegar la `docker-compose` actual.

### Requisitos previos
1. Tener credenciales AWS configuradas con el profile `k8s-labs` (o ajustar `var.aws_profile`).
2. Crear un **key pair** existente en la región deseada; su nombre se pasa con `-var "key_pair_name=mi-key"`.
3. Terraform >= 1.6 y el proveedor AWS >= 5.0.

### Uso
```bash
cd terraform
terraform init
terraform plan \
  -var "key_pair_name=mi-key" \
  -var "ssh_private_key_path=$HOME/.ssh/mi-key.pem" \
  -out tfplan

terraform apply tfplan
```

Variables importantes (ver `variables.tf`):

- `allowed_cidrs`: restringe qué IPs pueden entrar por 22/80/443/9443/8080/8443.
- `instance_type` y `root_volume_size`: ajusta recursos para OpenCTI/Elasticsearch.
- `ssh_private_key_path`: ruta local al PEM que Terraform usará para copiar archivos/provisionar la instancia.
- `haproxy_cert_cn` y `compose_project_name`: afinan el despliegue automatizado del reverse proxy y de la pila Docker.
- `portainer_version`/`docker_version`: por si necesitas fijar tags específicos.

### Post-despliegue
1. Accede a Portainer en `https://<public-ip>:9443` y crea el usuario admin (ya está corriendo gracias a `user-data`).
2. Terraform habrá copiado `/opt/misp-image`, `/opt/misp/docker-compose.yml`, `/opt/misp/.env` y `scripts/` y habrá ejecutado:
   - `scripts/setup-haproxy.sh` (con el CN indicado en `haproxy_cert_cn`).
   - `docker compose build misp` + `COMPOSE_PROJECT_NAME=<var.compose_project_name> docker compose up -d`.
3. Verifica que los servicios estén `healthy` (`docker ps`, Portainer) y ajusta DNS (`opencti.*`, `misp.*`) hacia la IP pública o hacia el balanceador que prefieras.

> Nota: Si actualizas archivos locales (docker-compose, misp-image, scripts, .env) vuelve a ejecutar `terraform apply` para que los provisioners vuelvan a copiar/actualizar el despliegue en la instancia.
