variable "aws_profile" {
  description = "AWS named profile configured in ~/.aws/credentials (k8s-labs en este caso)."
  type        = string
  default     = "k8s-labs"
}

variable "aws_region" {
  description = "Región donde se desplegará la infraestructura."
  type        = string
  default     = "eu-west-1"
}

variable "availability_zone" {
  description = "Zona de disponibilidad para la subred pública."
  type        = string
  default     = "eu-west-1a"
}

variable "name_prefix" {
  description = "Prefijo para nombrar recursos (vpc, sg, instancias, etc.)."
  type        = string
  default     = "opencti-misp"
}

variable "owner_tag" {
  description = "Valor opcional para la etiqueta Owner."
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Mapa de etiquetas adicionales a aplicar a todos los recursos."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.60.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloque CIDR de la subred pública."
  type        = string
  default     = "10.60.10.0/24"
}

variable "allowed_cidrs" {
  description = "Lista de rangos CIDR autorizados para acceder a la instancia."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "Tipo de instancia EC2 que ejecutará Docker/Portainer/OpenCTI."
  type        = string
  default     = "t3.xlarge"
}

variable "key_pair_name" {
  description = "Nombre del key pair existente en AWS para habilitar SSH."
  type        = string
}

variable "root_volume_size" {
  description = "Tamaño (GB) del volumen raíz de la instancia."
  type        = number
  default     = 120
}

variable "docker_version" {
  description = "Versión exacta del paquete docker-ce/docker-ce-cli (formato apt, ej. 5:28.5.2-1~ubuntu.22.04~jammy)."
  type        = string
  default     = "5:28.5.2-1~ubuntu.22.04~jammy"
}

variable "containerd_version" {
  description = "Versión del paquete containerd.io compatible con la distribución."
  type        = string
  default     = "1.7.27-1"
}

variable "docker_compose_plugin_version" {
  description = "Versión del paquete docker-compose-plugin a instalar."
  type        = string
  default     = "2.40.3-1~ubuntu.22.04~jammy"
}

variable "portainer_version" {
  description = "Tag de Portainer CE a desplegar."
  type        = string
  default     = "latest"
}

variable "ssh_private_key_path" {
  description = "Ruta local al archivo PEM usado para conectarse por SSH a la instancia (se usa en los provisioners)."
  type        = string
}

variable "haproxy_cert_cn" {
  description = "Common Name que usará el script de HAProxy al generar el certificado self-signed."
  type        = string
  default     = "*.claumagagnotti.com"
}

variable "compose_project_name" {
  description = "Valor para COMPOSE_PROJECT_NAME al desplegar la pila (permite entornos paralelos)."
  type        = string
  default     = "ti"
}
