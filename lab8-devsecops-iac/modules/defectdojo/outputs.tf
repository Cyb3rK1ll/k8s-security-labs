output "load_balancer_hostname" {
  value       = try(data.kubernetes_service.defectdojo.status[0].load_balancer[0].ingress[0].hostname, "")
  description = "Hostname del Load Balancer que publica DefectDojo."
}

output "admin_password" {
  value       = random_password.admin_password.result
  description = "Contraseña del usuario admin de DefectDojo."
  sensitive   = true
}
