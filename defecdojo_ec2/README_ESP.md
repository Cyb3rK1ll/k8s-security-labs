# 🛡️ Lab 7 – DevSecOps con DefectDojo en AWS (Versión Consultiva)

Este laboratorio (orientado solo a entornos de prueba y demostración) está diseñado para **conversar con ejecutivos de seguridad (CISO), líderes de AppSec y equipos técnicos** que necesitan evidenciar:

- **Gobernanza**: despliegue repetible vía IaC con trazabilidad completa.  
- **Respuesta a incidentes**: backups en S3 y restauración automatizada con rotación de credenciales.  
- **Time-to-Value**: entorno funcional en ~12 min, ideal para PoC con clientes o auditorías.

---

## 1. Resumen Ejecutivo

| Necesidad del negocio | Cómo lo cubre el lab |
|-----------------------|----------------------|
| Probar madurez DevSecOps ante clientes o auditors | Terraform + scripting generan evidencia auditable (logs, outputs, credenciales). |
| Recuperar la plataforma AppSec ante una contingencia | Restore orquestado desde S3 con reseteo automático de contraseña administrativa. |
| Demostrar control operativo y resiliencia | Systemd mantiene el servicio activo; Terraform monitorea en tiempo real la instalación. |

**Mensaje clave para un CISO:** _“Podemos provisionar, asegurar y recuperar nuestra plataforma de gestión de vulnerabilidades con la misma disciplina IaC que usamos para workloads críticos.”_

---

## 2. Historia de Valor (Consulting Pitch)

1. **Diagnóstico**: muchos programas DevSecOps dependen de instalaciones manuales de DefectDojo → poco auditables, difíciles de recuperar.  
2. **Propuesta**: empaquetar la plataforma en Terraform + shell scripts endurecidos, incluyendo restore y rotación de secretos.  
3. **Resultado**: el cliente obtiene un runbook reutilizable para demos, assessments o DR drills.

---

## 3. Arquitectura & Controles

- **AWS EC2 (Amazon Linux 2023)** con Docker Compose → despliegue rápido y portable.  
- **IAM Role + Instance Profile** con permisos mínimos hacia el bucket S3 de backups.  
- **Security Group** expone únicamente SSH (22) y UI (8080).  
- **Systemd (`defectdojo.service`)** mantiene el stack vivo después de reinicios.  
- **Evidencia**:  
  - `/var/log/defectdojo_install.log` (audit trail completo).  
  - `/home/ec2-user/defectdojo_admin_credentials.log` (gestión de secretos).  
- **Opcional**: restauración automática desde S3 + rotación de contraseña “admin”.

> ⚠️ Alcance: infraestructura de laboratorio/PoC. Para producción se recomienda red privada, WAF/ALB, base de datos administrada, KMS/Secrets Manager y monitoreo continuo.  
> Sugiere mostrar un diagrama tipo `evidence/diagrams/devsecops-defectdojo-architecture.png` durante reuniones con clientes.

---

## 4. Flujo Automatizado

1. **Terraform** crea red, SG, IAM y EC2; copia scripts y transmite el log de instalación en vivo.  
2. **`install_defectdojo.sh`** instala Docker, clona DefectDojo, levanta los contenedores, extrae la contraseña inicial y registra un servicio systemd.  
3. **`restore_defectDojo.sh` (opcional)** descarga backups de S3, resetea la base, rehidrata media y fija una nueva contraseña.  
4. **Resumen Final**: Terraform imprime IP pública, URL y credenciales vigentes.

---

## 5. Indicadores Para Ejecutivos

| KPI | Métrica | Evidencia |
|-----|---------|-----------|
| **MTTD / Observabilidad** | Log en tiempo real durante el `apply`. | `null_resource.defectdojo_install_log`. |
| **MTTR** | Restore completo (DB + media + password) < 5 min. | `restore_defectDojo.sh` con timers incorporados. |
| **Gobernanza** | Evidencias guardadas en disco, permisos restringidos (`chmod 600`). | `defectdojo_admin_credentials.log`. |
| **Resiliencia** | Reinicio automático vía systemd. | `sudo systemctl status defectdojo.service`. |

---

## 6. Requisitos Técnicos

1. Cuenta AWS con perfil `k8s-labs` (modificable).  
2. Terraform v1.5+ local.  
3. AWS CLI configurado + token válido.  
4. (Opcional) Backups preexistentes en S3 si se habilita el restore.

---

## 7. Guía Paso a Paso

```bash
# Crear la key pair (si no existe)
aws ec2 create-key-pair \
  --key-name defectdojo-key \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-1 \
  --profile k8s-labs > defectdojo-key.pem
chmod 400 defectdojo-key.pem

# Terraform
terraform init
terraform apply -auto-approve
```

Durante el `apply` se verá:
- Log streaming del instalador.  
- Restore automático (si `enable_defectdojo_restore=true`).  
- Resumen final con IP/URL/password.

Outputs oficiales:

```text
dojo_public_ip = "34.242.67.67"
dojo_url       = "http://ec2-34-242-67-67.eu-west-1.compute.amazonaws.com:8080"
```

---

## 8. Operación & Evidencias

```bash
# Acceso SSH
ssh -i defectdojo-key.pem ec2-user@$(terraform output -raw dojo_public_ip)

# Logs y credenciales
sudo less /var/log/defectdojo_install.log
cat ~/defectdojo_admin_credentials.log

# Salud de los contenedores
cd ~/django-DefectDojo
docker compose ps

# Servicio persistente
sudo systemctl status defectdojo.service
```

---

## 9. Restore & Rotación de Secretos

Variables clave (ya precargadas con valores de ejemplo):

```hcl
enable_defectdojo_restore        = true
defectdojo_restore_bucket        = "defectdojo-backup-lab9-devsecops"
defectdojo_restore_db_object     = "defectdojo_db_backup_2025-11-06_2313.sql"
defectdojo_restore_media_object  = "dojo_media_backup_2025-11-06_2313.tar.gz"
```

Secuencia:
1. Detiene el stack y levanta solo Postgres.  
2. Limpia la base, restaura DB + media.  
3. Reinicia todos los contenedores y espera a `uwsgi`.  
4. Genera una nueva contraseña aleatoria y la documenta.  
5. Terraform refleja la contraseña en el resumen final.

👉 Mensaje para negocio: _“El laboratorio demuestra que una brecha o corrupción de datos puede revertirse rápidamente sin intervención manual.”_

---

## 10. Próximos Pasos Recomendados

1. **Integrar pipelines**: enviar findings desde GitLab/GitHub para mostrar el ciclo completo DevSecOps.  
2. **Incluir evidencias visuales**: capturas del dashboard y del restore para presentaciones comerciales.  
3. **Expandir controles**: cifrado de backups con KMS, private subnets, o WAF frente al ALB si se expone públicamente.  
4. **Oferta consultiva**: empaquetar el lab como “DevSecOps Readiness Accelerator” para clientes regulados.

---

💬 **Pitch final para ejecutivos:**  
_“Este laboratorio no es una simple demo: es un blueprint reutilizable que combina automatización, resiliencia y reporting. Permite mostrar a tus clientes (o a tu comité ejecutivo) que la seguridad de aplicaciones puede desplegarse, monitorearse y recuperarse con el mismo rigor que la infraestructura crítica.”_
