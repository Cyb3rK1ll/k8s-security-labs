# Subnets for public load balancers (tagged by EKS/VPC module)
data "aws_subnets" "elb" {
  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster_name}"
    values = ["shared"]
  }

  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }
}

# Cert-manager
resource "helm_release" "cert_manager" {
  provider        = helm
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  namespace       = "cert-manager"
  create_namespace = true
  version         = "v1.15.3"
  timeout         = 600

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubectl_manifest" "letsencrypt_cluster_issuer" {
  provider = kubectl

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: magagnotticla@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
YAML

  depends_on = [helm_release.cert_manager]
}

# Traefik
resource "helm_release" "traefik" {
  provider        = helm
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true
  version          = "29.0.0"
  timeout          = 600

  values = [
    yamlencode({
      ports = {
        web = {
          nodePort = 32080
        }
        websecure = {
          nodePort = 32443
        }
      }
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-internal"           = "false"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"             = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-subnets"            = join(",", data.aws_subnets.elb.ids)
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" = "TCP"
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"     = "32080"
        }
      }
    })
  ]
}

# Namespace para la app (Juice Shop)
resource "kubernetes_namespace" "prod" {
  provider = kubernetes

  metadata {
    name = "prod"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Certificado TLS emitido por cert-manager
resource "kubectl_manifest" "juice_shop_certificate" {
  provider = kubectl

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: juice-shop-tls
  namespace: prod
spec:
  secretName: juice-shop-tls
  dnsNames:
    - ${var.domain_name}
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
YAML

  depends_on = [
    kubectl_manifest.letsencrypt_cluster_issuer,
    kubernetes_namespace.prod
  ]
}

# IngressRoute para Juice Shop-
resource "kubectl_manifest" "ingress_juice_shop" {
  provider = kubectl

  yaml_body = <<YAML
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: juice-shop
  namespace: prod
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`${var.domain_name}`)
      kind: Rule
      services:
        - name: juice-shop
          port: 80
  tls:
    secretName: juice-shop-tls
YAML

  depends_on = [
    helm_release.traefik,
    kubectl_manifest.letsencrypt_cluster_issuer,
    kubernetes_namespace.prod,
    kubectl_manifest.juice_shop_certificate
  ]
}
