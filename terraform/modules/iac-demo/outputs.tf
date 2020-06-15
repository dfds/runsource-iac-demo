output "ad_admin_username" {
  value = module.activedirectory.admin_username
}

output "admin_server_dns_alias" {
  value = "${element(module.ec2_dns_record_admin.record_name, 0)}.${data.aws_route53_zone.workload.name}"
}

output "admin_server_public_dns" {
  value = module.ec2_instance_admin.public_dns
}

# output "admin_server_password_data" {
#   value = module.ec2_instance_admin.password_data
# }

output "web1_server_dns_alias" {
  value = "${element(module.ec2_dns_record_web1.record_name, 0)}.${data.aws_route53_zone.workload.name}"
}

output "web1_server_public_dns" {
  value = module.ec2_instance_web1.public_dns
}

output "web1_server_password" {
  value = module.ec2_instance_web1.password
}

# output "web1_server_password_data" {
#   value = module.ec2_instance_web1.password_data
# }

output "web2_server_dns_alias" {
  value = "${element(module.ec2_dns_record_web2.record_name, 0)}.${data.aws_route53_zone.workload.name}"
}

output "web2_server_public_dns" {
  value = module.ec2_instance_web2.public_dns
}
