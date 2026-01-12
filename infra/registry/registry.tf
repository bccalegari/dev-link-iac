########################################
# PersistentVolumeClaim
########################################
resource "kubernetes_persistent_volume_claim_v1" "registry" {
  metadata {
    name      = "registry-pvc"
    namespace = "devlink"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

########################################
# External data
########################################
data "external" "registry_secrets" {
  program = ["bash", "${path.module}/generate_registry_secrets.sh"]
}

########################################
# Registry Auth Secret
########################################
resource "kubernetes_secret_v1" "registry_auth" {
  metadata {
    name      = "registry-auth-secret"
    namespace = "devlink"
  }

  type = "Opaque"

  data = {
    htpasswd = data.external.registry_secrets.result.htpasswd
  }
}

########################################
# Registry Docker Credentials
########################################
resource "kubernetes_secret_v1" "registry_cred" {
  metadata {
    name      = "registry-cred"
    namespace = "devlink"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = data.external.registry_secrets.result.dockerconfigjson
  }
}

locals {
  auth = jsondecode(data.external.registry_secrets.result.basic_auth)
}


########################################
# Registry Basic Auth Credentials
########################################
resource "kubernetes_secret_v1" "registry_basic_auth" {
  metadata {
    name      = "registry-basic-auth"
    namespace = "devlink"
  }

  type = "Opaque"

  data = {
    username = local.auth.username
    password = local.auth.password
  }
}

########################################
# Deployment
########################################
resource "kubernetes_deployment_v1" "registry" {
  metadata {
    name      = "registry"
    namespace = "devlink"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
      }

      spec {
        container {
          name  = "registry"
          image = "registry:3"

          port {
            container_port = 5000
          }

          volume_mount {
            name       = "registry-storage"
            mount_path = "/var/lib/registry"
          }

          volume_mount {
            name       = "registry-auth"
            mount_path = "/auth"
          }

          env {
            name  = "REGISTRY_AUTH"
            value = "htpasswd"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_REALM"
            value = "Registry Realm"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_PATH"
            value = "/auth/htpasswd"
          }
        }

        volume {
          name = "registry-storage"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.registry.metadata[0].name
          }
        }

        volume {
          name = "registry-auth"

          secret {
            secret_name = kubernetes_secret_v1.registry_auth.metadata[0].name
          }
        }
      }
    }
  }
}

########################################
# Service
########################################
resource "kubernetes_service_v1" "registry" {
  metadata {
    name      = "registry"
    namespace = "devlink"
  }

  spec {
    selector = {
      app = "registry"
    }

    type = "NodePort"

    port {
      port        = 5000
      target_port = 5000
      node_port   = 32000
    }
  }
}