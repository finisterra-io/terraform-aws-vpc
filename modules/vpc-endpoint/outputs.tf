output "id" {
  description = "The ID of the VPC endpoint"
  value       = aws_vpc_endpoint.this[0].id
}
