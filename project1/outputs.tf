# VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

# Public Subnets
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

# All Private Subnets Combined
output "private_subnet_ids" {
  description = "List of all private subnet IDs (weblayer, applayer, dblayer)"
  value = concat(
    aws_subnet.private_weblayer[*].id,
    aws_subnet.private_applayer[*].id,
    aws_subnet.private_dblayer[*].id
  )
}

# Individual Private Subnet Layers
output "weblayer_subnet_ids" {
  description = "List of private web layer subnet IDs"
  value       = aws_subnet.private_weblayer[*].id
}

output "applayer_subnet_ids" {
  description = "List of private app layer subnet IDs"
  value       = aws_subnet.private_applayer[*].id
}

output "dblayer_subnet_ids" {
  description = "List of private database layer subnet IDs"
  value       = aws_subnet.private_dblayer[*].id
}

# NAT Gateway Public IP
output "nat_gateway_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# Security Groups
output "bastion_security_group_id" {
  description = "The ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "windows_admin_security_group_id" {
  description = "The ID of the Windows admin security group"
  value       = aws_security_group.windows_admin.id
}

output "linux_admin_security_group_id" {
  description = "The ID of the Linux admin security group"
  value       = aws_security_group.linux_admin.id
}
