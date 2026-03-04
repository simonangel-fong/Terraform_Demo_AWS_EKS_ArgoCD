output "eks_kubeconfig_command" {
  value = "\naws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}\n"
}

output "argocd_ui_url" {
  value = module.argocd_eks_capability.argocd_server_url
}