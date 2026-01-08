module "registry" {
  source = "./infra/registry"
}

module "jenkins" {
  source = "./infra/jenkins"
  depends_on = [module.registry]
}