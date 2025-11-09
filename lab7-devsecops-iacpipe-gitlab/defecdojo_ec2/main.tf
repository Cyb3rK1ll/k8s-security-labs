provider "aws" {
  region  = "eu-west-1"
  profile = "k8s-labs"
}

variable "use_existing_defectdojo_role" {
  description = "Set to true to reuse an existing IAM role instead of creating a new one."
  type        = bool
  default     = true
}

variable "defectdojo_role_name" {
  description = "Name of the IAM role that backs DefectDojo backups. Must match the existing role when reuse is enabled."
  type        = string
  default     = "DefectDojoBackupRole"
}

variable "enable_defectdojo_restore" {
  description = "Set to true to restore a previous DefectDojo backup after provisioning."
  type        = bool
  default     = true
}

variable "defectdojo_restore_bucket" {
  description = "S3 bucket where DefectDojo backups are stored."
  type        = string
  default     = "defectdojo-backup-lab9-devsecops"
}

variable "defectdojo_restore_db_object" {
  description = "S3 object key (path/filename) for the database backup to restore."
  type        = string
  default     = "defectdojo_db_backup_2025-11-06_2313.sql"
}

variable "defectdojo_restore_media_object" {
  description = "S3 object key (path/filename) for the media backup to restore."
  type        = string
  default     = "dojo_media_backup_2025-11-06_2313.tar.gz"
}

resource "aws_security_group" "dojo_sg" {
  name        = "defectdojo-sg"
  description = "Allow HTTP and SSH for DefectDojo"
  ingress = [
    {
      description      = "HTTP"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      description      = "All outbound"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

# --- IAM ROLE FOR EC2 (permite subir/restaurar backups de S3) ---
resource "aws_iam_role" "defectdojo_role" {
  count = var.use_existing_defectdojo_role ? 0 : 1
  name  = var.defectdojo_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

locals {
  defectdojo_role_name = var.use_existing_defectdojo_role ? var.defectdojo_role_name : aws_iam_role.defectdojo_role[0].name
}

# --- POLICY: acceso a tu bucket S3 ---
resource "aws_iam_role_policy" "defectdojo_s3_policy" {
  name = "DefectDojoS3AccessPolicy"
  role = local.defectdojo_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::defectdojo-backup-lab9-devsecops",
          "arn:aws:s3:::defectdojo-backup-lab9-devsecops/*"
        ]
      }
    ]
  })
}

# --- INSTANCE PROFILE ---
resource "aws_iam_instance_profile" "defectdojo_instance_profile" {
  name = "DefectDojoInstanceProfile"
  role = local.defectdojo_role_name
}

# --- EC2 INSTANCE ---
resource "aws_instance" "defectdojo" {
  ami           = "ami-0025245f3ca0bcc82" # Amazon Linux 2 en eu-west-1
  instance_type = "t3.medium"
  #Si ya tenes una key pair creada, podes listar las existentes con el siguiente comando:
  #aws ec2 describe-key-pairs --region eu-west-1 --profile k8s-labs
  /*Si no tenes una key pair creada, creala con el siguiente comando:
  aws ec2 create-key-pair \
  --key-name defectdojo-key \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-1 \
  --profile k8s-labs > defectdojo-key.pem
  */
  key_name               = "defectdojo-key" # <-- Cambiá esto por tu clave existente
  vpc_security_group_ids = [aws_security_group.dojo_sg.id]

  iam_instance_profile = aws_iam_instance_profile.defectdojo_instance_profile.name


  tags = {
    Name = "DefectDojo-Server"
  }

  # Ejecuta el script de instalación automáticamente
  user_data = file("${path.module}/install_defectdojo.sh")

  # Mensaje informativo mientras se espera
  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Esperando a que DefectDojo termine de inicializarse (esto puede tardar varios minutos)...'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/defectdojo-key.pem") # Clave privada local
      host        = self.public_ip
    }
  }
}

resource "null_resource" "defectdojo_restore_script" {
  depends_on = [aws_instance.defectdojo]

  triggers = {
    script_hash = filesha256("${path.module}/restore_defectDojo.sh")
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/defectdojo-key.pem")
    host        = aws_instance.defectdojo.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/restore_defectDojo.sh"
    destination = "/home/ec2-user/restore_defectDojo.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /home/ec2-user/restore_defectDojo.sh"]
  }
}

resource "null_resource" "defectdojo_install_log" {
  depends_on = [null_resource.defectdojo_restore_script]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/defectdojo-key.pem")
    host        = aws_instance.defectdojo.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏱️ Esperando a que aparezca /var/log/defectdojo_install.log...'",
      "sudo bash -lc 'while [ ! -f /var/log/defectdojo_install.log ]; do sleep 5; done'",
      "sudo bash -lc $'if [ -f /var/log/defectdojo_install.done ]; then\\n  echo \"ℹ️ Instalador ya finalizó; mostrando últimas 200 líneas:\"\\n  tail -n 200 /var/log/defectdojo_install.log\\nelse\\n  echo \"=== Streaming /var/log/defectdojo_install.log ===\"\\n  tail -n +1 -F /var/log/defectdojo_install.log &\\n  TAIL_PID=$!\\n  while [ ! -f /var/log/defectdojo_install.done ]; do sleep 2; done\\n  kill $TAIL_PID\\nfi'",
      "echo '=== Fin del log de instalación ==='"
    ]
  }
}

resource "null_resource" "defectdojo_restore" {
  count      = var.enable_defectdojo_restore ? 1 : 0
  depends_on = [null_resource.defectdojo_install_log]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/defectdojo-key.pem")
    host        = aws_instance.defectdojo.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "if [ -z \"${var.defectdojo_restore_db_object}\" ] || [ -z \"${var.defectdojo_restore_media_object}\" ]; then echo 'Faltan los objetos de backup para restaurar' >&2; exit 1; fi",
      "echo '♻️ Iniciando restore automático de DefectDojo...' ",
      "bash /home/ec2-user/restore_defectDojo.sh '${var.defectdojo_restore_bucket}' '${var.defectdojo_restore_db_object}' '${var.defectdojo_restore_media_object}'"
    ]
  }
}

resource "null_resource" "defectdojo_summary" {
  triggers = {
    restore_enabled = tostring(var.enable_defectdojo_restore)
    restore_ids     = join(",", null_resource.defectdojo_restore.*.id)
  }

  depends_on = [null_resource.defectdojo_install_log]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/defectdojo-key.pem")
    host        = aws_instance.defectdojo.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "ADMIN_PW=$(sudo awk -F': ' '/Admin password:/ {print $2}' /home/ec2-user/defectdojo_admin_credentials.log 2>/dev/null | tail -1)",
      "echo '============================================================'",
      "echo ' 📋 DefectDojo listo'",
      "echo '------------------------------------------------------------'",
      "echo 'IP pública: ${aws_instance.defectdojo.public_ip}'",
      "echo 'URL: http://${aws_instance.defectdojo.public_dns}:8080'",
      "echo 'Usuario: admin'",
      "if [ -n \"$ADMIN_PW\" ]; then echo \"Contraseña: $ADMIN_PW\"; else echo 'Contraseña no encontrada; revisá /home/ec2-user/defectdojo_admin_credentials.log'; fi",
      "echo '============================================================'"
    ]
  }
}


output "dojo_public_ip" {
  value = aws_instance.defectdojo.public_ip
}

output "dojo_url" {
  value = "http://${aws_instance.defectdojo.public_dns}:8080"
}
