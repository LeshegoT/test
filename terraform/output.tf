output "heapoverflow_db_endpoint" {
  value = aws_db_instance.heapoverflow_instance.endpoint
}

output "heapoverflow_db_address" {
  value = aws_db_instance.heapoverflow_instance.address
}

output "heapoverflow_db_port" {
  value = aws_db_instance.heapoverflow_instance.port
}