provider "aws" {
  region  = "eu-west-1"
  profile = "k8s-labs"
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
  name = "DefectDojoBackupRole"

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

# --- POLICY: acceso a tu bucket S3 ---
resource "aws_iam_role_policy" "defectdojo_s3_policy" {
  name = "DefectDojoS3AccessPolicy"
  role = aws_iam_role.defectdojo_role.id

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
  role = aws_iam_role.defectdojo_role.name
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

  # Espera y muestra el resultado final
  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Esperando a que DefectDojo termine de inicializarse (esto puede tardar varios minutos)...'",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/defectdojo-key.pem") # Clave privada local
      host        = self.public_ip
    }
  }
}


output "dojo_public_ip" {
  value = aws_instance.defectdojo.public_ip
}

output "dojo_url" {
  value = "http://${aws_instance.defectdojo.public_dns}:8080"
}
