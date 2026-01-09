terraform {
  backend "kubernetes" {
    namespace     = "devlink"
    secret_suffix = "user-service" 
  }
}