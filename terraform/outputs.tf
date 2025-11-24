output "nginx_ip" {
  value       = var.nginx_ip
  description = "IP address of nginx-gateway LXC"
}

output "grpc_app_1_ip" {
  value       = var.grpc_app_1_ip
  description = "IP address of grpc-app-1 LXC"
}

output "grpc_app_2_ip" {
  value       = var.grpc_app_2_ip
  description = "IP address of grpc-app-2 LXC"
}
