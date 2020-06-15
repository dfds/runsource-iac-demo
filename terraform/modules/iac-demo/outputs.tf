output "admin_username" {
  value = module.activedirectory.admin_username
}

output "server1_dns_alias" {
  value = "${element(module.ec2_dns_record_server1.record_name, 0)}.${data.aws_route53_zone.workload.name}"
}

output "server1_public_dns" {
  value = module.ec2_instance_server1.public_dns
}

# output "server1_password_data" {
#   value = module.ec2_instance_server1.password_data
#   sensitive = true
# }

output "server2_dns_alias" {
  value = "${element(module.ec2_dns_record_server2.record_name, 0)}.${data.aws_route53_zone.workload.name}"
}

output "server2_public_dns" {
  value = module.ec2_instance_server2.public_dns
}

# output "server2_password_data" {
#   value = module.ec2_instance_server2.password_data
#   sensitive = true
# }
