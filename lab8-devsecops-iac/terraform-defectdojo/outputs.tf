output "defectdojo_load_balancer" {
  value       = module.defectdojo.load_balancer_hostname
  description = "Hostname del Load Balancer que publica DefectDojo."
}

output "defectdojo_admin_password" {
  value       = module.defectdojo.admin_password
  description = "Contraseña admin generada para DefectDojo."
  sensitive   = true
}
