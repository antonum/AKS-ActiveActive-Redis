output "k8s_cluster1_fqdn" {
    value = "https://${azurerm_kubernetes_cluster.k8s1.fqdn}"
}
output "k8s_cluster2_fqdn" {
    value = "https://${azurerm_kubernetes_cluster.k8s2.fqdn}"
}