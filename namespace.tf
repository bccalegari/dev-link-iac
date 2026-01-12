resource "kubernetes_namespace_v1" "devlink" {
  metadata {
    name = "devlink"
  }
}