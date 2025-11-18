# Archivo: leaks.tf
# Este archivo es solo para validar que los escáneres detectan secretos correctamente.
#######################################################################################

variable "aws_secret_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"
}

variable "github_token" {
  default = "ghp_abCDefGHIjkLMNopQRstUVWXyZ123456789"
}

variable "db_password" {
  default = "P@ssw0rd!23FAKE"
}

variable "aws_secret_access_ke2y" {
  default = "AKIA2Z3X4Y5W6V7U8T9S"
}
variable "github_token2" {
  default = "ghp_abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
}
variable "db_password2" {
  default = "dG9rZW5fZm9yX3Rlc3RpbmcxMjM0NTY"
}
#######################################################################################
