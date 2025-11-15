terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  common_tags = merge(
    {
      Project   = "opencti-misp"
      ManagedBy = "terraform"
      Owner     = coalesce(var.owner_tag, data.aws_caller_identity.current.account_id)
    },
    var.extra_tags,
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-subnet"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-sg"
  description = "Allow SSH, HTTP/HTTPS, Portainer and OpenCTI/MISP access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "Portainer HTTPS"
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "OpenCTI UI (direct fallback)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "MISP UI (direct fallback)"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-sg"
  })
}

resource "aws_instance" "opencti_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    HOSTNAME               = "${var.name_prefix}-opencti"
    DOCKER_PACKAGE_VERSION = var.docker_version
    CONTAINERD_VERSION     = var.containerd_version
    DOCKER_COMPOSE_VERSION = var.docker_compose_plugin_version
    PORTAINER_VERSION      = var.portainer_version
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ec2"
  })

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
  }

  # Espera a que cloud-init y apt terminen su instalación inicial.
  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 5; done",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 5; done",
      "until command -v docker >/dev/null 2>&1; do sleep 5; done"
    ]
  }

  # Prepara directorios temporales y limpia despliegues previos.
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /opt/misp-image /opt/misp /opt/scripts",
      "sudo rm -rf /tmp/misp-image /tmp/misp-scripts /tmp/misp-compose.yml /tmp/misp-env /tmp/deploy_stack.sh",
      "sudo mkdir -p /opt /tmp"
    ]
  }

  # Copia la carpeta misp-image al host remoto.
  provisioner "file" {
    source      = "${path.module}/../misp-image"
    destination = "/tmp/misp-image"
  }

  # Copia las automatizaciones de HAProxy.
  provisioner "file" {
    source      = "${path.module}/../scripts"
    destination = "/tmp/misp-scripts"
  }

  # Copia docker-compose.yml y el archivo .env usados por la pila.
  provisioner "file" {
    source      = "${path.module}/../docker-compose.yml"
    destination = "/tmp/misp-compose.yml"
  }

  provisioner "file" {
    source      = "${path.module}/../.env"
    destination = "/tmp/misp-env"
  }

  # Script que ejecuta la configuración final (HAProxy + docker compose).
  provisioner "file" {
    source      = "${path.module}/deploy_stack.sh"
    destination = "/tmp/deploy_stack.sh"
  }

  # Mueve los artefactos a /opt y ejecuta la automatización completa.
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/deploy_stack.sh",
      "sudo /tmp/deploy_stack.sh '${var.haproxy_cert_cn}' '${var.compose_project_name}'"
    ]
  }
}
