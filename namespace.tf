resource "kubernetes_namespace" "devlink" {
  metadata {
    name = "devlink"
  }
}