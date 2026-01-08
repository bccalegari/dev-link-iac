########################################
# Variables
########################################
variable "spring_profile" {
  type    = string
  default = "dev"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "replicas" {
  type = number
}

variable "resources" {
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
}

variable "java_tool_options" {
  type    = string
  default = ""
}

variable "color" {
  type    = string
  default = "blue"
}

########################################
# Deployment
########################################
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service-${var.color}"
    namespace = "devlink"
    labels = {
      app   = "user-service"
      color = var.color
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app   = "user-service"
        color = var.color
      }
    }

    template {
      metadata {
        labels = {
          app   = "user-service"
          color = var.color
        }
      }

      spec {
        image_pull_secrets {
          name = "registry-cred"
        }

        container {
          name  = "user-service"
          image = "localhost:32000/user-service:${var.image_tag}"

          port {
            container_port = 8080
          }

          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = var.spring_profile
          }

          env {
            name  = "JAVA_TOOL_OPTIONS"
            value = var.java_tool_options
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }
        }
      }
    }
  }
}

########################################
# Service
########################################
resource "kubernetes_service" "user_service" {
  metadata {
    name      = "user-service"
    namespace = "devlink"
  }

  spec {
    selector = {
      app   = "user-service"
      color = var.color
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }
  }
}