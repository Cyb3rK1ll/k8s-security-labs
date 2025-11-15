output "instance_id" {
  description = "ID de la instancia EC2 que ejecuta OpenCTI/MISP."
  value       = aws_instance.opencti_host.id
}

output "public_ip" {
  description = "IP pública asignada a la instancia."
  value       = aws_instance.opencti_host.public_ip
}

output "portainer_url" {
  description = "URL para acceder a Portainer una vez completo el bootstrap."
  value       = "https://${aws_instance.opencti_host.public_ip}:9443"
}

output "opencti_url" {
  description = "URL HTTPS expuesta por HAProxy para OpenCTI."
  value       = "https://${aws_instance.opencti_host.public_ip}"
}

output "misp_url" {
  description = "URL HTTPS expuesta por HAProxy para MISP (requiere DNS/host que empiece con misp.)."
  value       = "https://${aws_instance.opencti_host.public_ip}/misp"
}
