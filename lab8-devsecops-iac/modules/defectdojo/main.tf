terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    random = {
      source = "hashicorp/random"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
 
resource "random_password" "redis" {
  length  = 16
  special = false
}

resource "random_password" "postgres_app" {
  length  = 16
  special = false
}

resource "random_password" "postgres_admin" {
  length  = 16
  special = false
}

resource "random_password" "admin_password" {
  length  = 16
  special = false
}

resource "random_password" "secret_key" {
  length  = 64
  special = false
}

resource "random_password" "credential_key" {
  length  = 64
  special = false
}

resource "random_password" "metrics_password" {
  length  = 16
  special = false
}

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

resource "kubernetes_namespace" "defectdojo" {
  metadata {
    name = "defectdojo"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "workload"                     = "defectdojo"
    }
  }
}

resource "helm_release" "defectdojo" {
  provider        = helm
  name            = "defectdojo"
  chart           = var.chart_url
  namespace       = kubernetes_namespace.defectdojo.metadata[0].name
  create_namespace = false
  timeout         = 2400
  depends_on      = [kubernetes_secret.defectdojo_admin]

  values = [
    yamlencode({
      createRedisSecret       = true
      createPostgresqlSecret  = true
      createSecret = false
      host    = var.domain_name
      siteUrl = "https://${var.domain_name}"
      global = {
        storageClass = var.storage_class
      }
      ingress = {
        enabled = false
      }
      # Permitimos scheduling en cualquier node group disponible
      django = {
        ingress = {
          activateTLS = true
        }
        uwsgi = {
          resources = {
            requests = {
              cpu    = "150m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
      }
      extraEnv = [
        {
          name  = "DD_ALLOWED_HOSTS"
          value = var.domain_name
        },
        {
          name  = "DD_CSRF_TRUSTED_ORIGINS"
          value = "https://${var.domain_name}"
        },
        {
          name  = "DD_SECURE_PROXY_SSL_HEADER"
          value = "HTTP_X_FORWARDED_PROTO,https"
        },
        {
          name  = "DD_PRODUCT_ANNOUNCEMENTS_ENABLED"
          value = "False"
        }
      ]
      service = {
        type = "ClusterIP"
      }
      redis = {
        auth = {
          password = random_password.redis.result
        }
      }
      postgresql = {
        auth = {
          username         = "defectdojo"
          database         = "defectdojo"
          password         = random_password.postgres_app.result
          postgresPassword = random_password.postgres_admin.result
        }
      }
      admin = {
        password                = random_password.admin_password.result
        secretKey               = random_password.secret_key.result
        credentialAes256Key     = random_password.credential_key.result
        metricsHttpAuthPassword = random_password.metrics_password.result
      }
    })
  ]
}

# Ingress expuesto vía Traefik
resource "kubectl_manifest" "defectdojo_ingress" {
  provider = kubectl

  yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: defectdojo
  namespace: defectdojo
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - ${var.domain_name}
      secretName: defectdojo-tls
  rules:
    - host: ${var.domain_name}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: defectdojo-django
                port:
                  name: http
YAML

  depends_on = [helm_release.defectdojo]
}

resource "kubernetes_secret" "defectdojo_admin" {
  metadata {
    name      = "defectdojo"
    namespace = kubernetes_namespace.defectdojo.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "defectdojo"
      "app.kubernetes.io/instance"   = "defectdojo"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    DD_ADMIN_PASSWORD            = random_password.admin_password.result
    DD_SECRET_KEY                = random_password.secret_key.result
    DD_CREDENTIAL_AES_256_KEY    = random_password.credential_key.result
    METRICS_HTTP_AUTH_PASSWORD   = random_password.metrics_password.result
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.defectdojo
  ]
}

data "kubernetes_service" "defectdojo" {
  metadata {
    name      = helm_release.defectdojo.name
    namespace = kubernetes_namespace.defectdojo.metadata[0].name
  }

  depends_on = [helm_release.defectdojo]
}
