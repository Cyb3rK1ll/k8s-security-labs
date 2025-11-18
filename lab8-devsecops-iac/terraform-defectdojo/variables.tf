variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "lab9-eks"
}

variable "domain_name" {
  type    = string
  default = "defectdojo.claumagagnotti.com"
}

variable "defectdojo_chart_url" {
  type    = string
  default = "https://github.com/DefectDojo/django-DefectDojo/releases/download/2.52.1/defectdojo-1.8.1.tgz"
}

variable "storage_class" {
  type    = string
  default = "gp2"
}
