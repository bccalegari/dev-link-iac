########################################
# ServiceAccount
########################################
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins-sa"
    namespace = "devlink"
  }
}

########################################
# ServiceAccount Token
########################################
resource "kubernetes_secret" "jenkins_sa_token" {
  metadata {
    name      = "${kubernetes_service_account.jenkins.metadata[0].name}-token"
    namespace = "devlink"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.jenkins.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

########################################
# Role
########################################
resource "kubernetes_role" "jenkins" {
  metadata {
    name      = "jenkins-deploy-role"
    namespace = "devlink"
  }

  rule {
    api_groups = ["", "apps", "batch"]
    resources  = ["deployments", "pods", "services", "jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec", "pods/log", "pods/portforward"]
    verbs      = ["create", "get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

########################################
# RoleBinding
########################################
resource "kubernetes_role_binding" "jenkins" {
  metadata {
    name      = "jenkins-deploy-binding"
    namespace = "devlink"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = "devlink"
  }
}

########################################
# PersistentVolumeClaim
########################################
resource "kubernetes_persistent_volume_claim" "jenkins" {
  metadata {
    name      = "jenkins-pvc"
    namespace = "devlink"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

########################################
# External data
########################################
data "external" "jenkins_secrets" {
  program = ["bash", "${path.module}/generate_jenkins_secrets.sh"]
}

########################################
# Jenkins Basic Auth Credentials
########################################
resource "kubernetes_secret" "jenkins_basic_auth" {
  metadata {
    name      = "jenkins-basic-auth"
    namespace = "devlink"
  }

  type = "Opaque"

  data = {
    username = data.external.jenkins_secrets.result.username
    password = data.external.jenkins_secrets.result.password
  }
}

########################################
# Deployment
########################################
resource "kubernetes_deployment_v1" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "devlink"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "jenkins"
      }
    }

    template {
      metadata {
        labels = {
          app = "jenkins"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.jenkins.metadata[0].name

        image_pull_secrets {
          name = "registry-cred"
        }

        init_container {
          name  = "wait-for-image"
          image = "curlimages/curl:7.88.1"
          env_from {
            secret_ref {
              name = "registry-basic-auth"
            }
          }
          command = [
            "sh",
            "-c",
            "echo 'Waiting for devlink-jenkins image...'; until curl -u $username:$password -s http://registry.devlink.svc.cluster.local:5000/v2/devlink-jenkins/tags/list | grep latest >/dev/null 2>&1; do echo 'Image not ready yet, sleeping 5s...'; sleep 5; done; echo 'Image found, continuing...'"
          ]
        }

        container {
          name  = "jenkins"
          image = "localhost:32000/devlink-jenkins:latest"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "jenkins-home"
            mount_path = "/var/jenkins_home"
          }

          env {
            name = "REGISTRY_USER"
            value_from {
              secret_key_ref {
                name = "registry-basic-auth"
                key  = "username"
              }
            }
          }

          env {
            name = "REGISTRY_PASS"
            value_from {
              secret_key_ref {
                name = "registry-basic-auth"
                key  = "password"
              }
            }
          }

          env {
            name  = "JENKINS_USER"
            value_from {
              secret_key_ref {
                name = "jenkins-basic-auth"
                key  = "username"
              }
            }
          }

          env {
            name  = "JENKINS_PASS"
            value_from {
              secret_key_ref {
                name = "jenkins-basic-auth"
                key  = "password"
              }
            }
          }
        }

        volume {
          name = "jenkins-home"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.jenkins.metadata[0].name
          }
        }
      }
    }
  }
}

########################################
# Service
########################################
resource "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "devlink"
  }

  spec {
    selector = {
      app = "jenkins"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    port {
      name        = "jnlp"
      port        = 50000
      target_port = 50000
    }

    type = "ClusterIP"
  }
}

########################################
# Ingress
########################################
resource "kubernetes_ingress_v1" "jenkins" {
  metadata {
    name      = "jenkins-ingress"
    namespace = "devlink"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "jenkins.devlink.localhost"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.jenkins.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}