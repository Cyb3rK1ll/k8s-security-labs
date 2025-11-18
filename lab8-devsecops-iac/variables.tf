variable "project_name" {
  type    = string
  default = "lab9"
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "domain_name" {
  type    = string
  default = "threatvision.claumagagnotti.com"
}

variable "gitlab_project_path" {
  type    = string
  default = "claumagagnotti/lab9-iac-secops"
}

variable "gitlab_ref" {
  type    = string
  default = "main"
}

variable "gitlab_ci_role_name" {
  type    = string
  default = "gitlab-eks-lab9-role"
}
