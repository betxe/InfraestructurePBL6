output "kafka_ip" {
  description = "IP estática del LXC Kafka"
  value       = var.lxc_ip
}

output "kafka_bootstrap_server" {
  description = "Bootstrap server de Kafka (usar en KAFKA_BOOTSTRAP_SERVERS)"
  value       = "${var.lxc_ip}:9092"
}
