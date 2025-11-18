# Update kubeconfig to use the EKS cluster
AWS_PROFILE=k8s-labs aws eks update-kubeconfig --region eu-west-1 --name lab9-eks

# Comprueba que el Inaress se creó v apunta al host correcto:
kubectl -n defectdojo get ingress 
kubectl -n defectdojo get ingress defectdojo
kubectl -n defectdojo describe ingress defectdojo

# Verifica que el Service es ClusterIP y los pods están Running :
kubectl -n defectdojo get pods 
kubectl -n defectdojo get svc defectdojo

kubectl -n traefik get svc traefik  

# Desinstalar DefectDojo
helm -n defectdojo uninstall defectdojo

# Ver password DefectDojo
terraform -chdir=terraform-defectdojo output defectdojo_admin_password
"lzecPxbuYcYl9CrS"
