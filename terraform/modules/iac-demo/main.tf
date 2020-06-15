# --------------------------------------------------
# Init
# --------------------------------------------------

terraform {
  backend "s3" {
  }
}

provider "aws" {
  region  = var.aws_region
  version = "~> 2.43"

  # profile = "qa-orgrole"

  #   assume_role {
  #     role_arn = var.aws_assume_role_arn
  #   }
}


# --------------------------------------------------
# Local variables
# --------------------------------------------------

locals {
  default_resource_name = "iac-demo"
}


# --------------------------------------------------
# Network infrastructure
# --------------------------------------------------

module "vpc" {
  source     = "C:/code/infrastructure-modules//_sub/network/vpc"
  name       = local.default_resource_name
  cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source      = "C:/code/infrastructure-modules//_sub/network/vpc-subnet"
  name        = local.default_resource_name
  vpc_id      = module.vpc.id
  cidr_blocks = var.subnet_cidr_blocks
}


# --------------------------------------------------
# Network security
# --------------------------------------------------

module "securitygroup" {
  source      = "C:/code/infrastructure-modules//_sub/compute/ec2-securitygroup"
  name        = local.default_resource_name
  description = "ADSync QA"
  vpc_id      = module.vpc.id
}

module "securitygrouprule_rdp_tcp" {
  source            = "C:/code/infrastructure-modules//_sub/compute/ec2-sgrule-cidr"
  security_group_id = module.securitygroup.id
  description       = "Allow RDP access from internet"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 3389
  to_port           = 3389
}

module "securitygrouprule_rdp_udp" {
  source            = "C:/code/infrastructure-modules//_sub/compute/ec2-sgrule-cidr"
  security_group_id = module.securitygroup.id
  description       = "Allow RDP access from internet"
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/24"]
  from_port         = 3389
  to_port           = 3389
}

module "securitygrouprule_http" {
  source            = "C:/code/infrastructure-modules//_sub/compute/ec2-sgrule-cidr"
  security_group_id = module.securitygroup.id
  description       = "Allow HTTP access from internet"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/24"]
  from_port         = 80
  to_port           = 80
}


# --------------------------------------------------
# Internet access
# --------------------------------------------------

module "vpc_internet_gateway" {
  source = "C:/code/infrastructure-modules//_sub/network/internet-gateway"
  name   = local.default_resource_name
  vpc_id = module.vpc.id
}

module "vpc_route_table" {
  source     = "C:/code/infrastructure-modules//_sub/network/route-table"
  name       = local.default_resource_name
  vpc_id     = module.vpc.id
  gateway_id = module.vpc_internet_gateway.id
}

module "route_table_assoc" {
  source         = "C:/code/infrastructure-modules//_sub/network/route-table-assoc"
  subnet_ids     = module.subnets.ids
  route_table_id = module.vpc_route_table.id
}


# --------------------------------------------------
# Active Directory
# --------------------------------------------------

module "activedirectory" {
  source     = "C:/code/infrastructure-modules//_sub/security/active-directory"
  name       = var.ad_name
  password   = var.ad_password
  edition    = var.ad_edition
  subnet_ids = slice(module.subnets.ids, 0, 2) # exactly two subnets, in different AZs, are required
}


resource "aws_vpc_dhcp_options" "ad" {
  domain_name         = var.ad_name
  domain_name_servers = module.activedirectory.dns_ip_addresses
}

resource "aws_vpc_dhcp_options_association" "ad" {
  vpc_id          = module.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.ad.id
}


# --------------------------------------------------
# Server general
# --------------------------------------------------

module "ec2_keypair" {
  source     = "C:/code/infrastructure-modules//_sub/compute/ec2-keypair"
  name       = local.default_resource_name
  public_key = var.ec2_public_key
}

locals {
  ssm_document_map = {
    "schemaVersion" = "1.0"
    "description"   = "Join an instance to a the ${var.ad_name} domain"
    "runtimeConfig" = {
      "aws:domainJoin" = {
        "properties" = {
          "directoryId"    = module.activedirectory.id
          "directoryName"  = var.ad_name
          "dnsIpAddresses" = module.activedirectory.dns_ip_addresses
        }
      }
    }
  }
  ssm_document_json = jsonencode(local.ssm_document_map)
}

resource "aws_ssm_document" "doc" {
  name          = "Join_${var.ad_name}_domain"
  document_type = "Command"
  content       = local.ssm_document_json
}


# --------------------------------------------------
# Admin server
# --------------------------------------------------

data "template_file" "user_data_admin" {
  template = file("${path.module}/ec2_user_data_admin")
  vars = {
  }
}

module "ec2_instance_admin" {
  source                      = "C:/code/infrastructure-modules//_sub/compute/ec2-instance"
  instance_type               = var.admin_server_instance_type
  key_name                    = module.ec2_keypair.key_name
  name                        = "${local.default_resource_name}_${var.admin_server_name}"
  user_data                   = data.template_file.user_data_admin.rendered
  ami_platform_filters        = ["windows"]
  ami_name_filters            = ["*Server-${var.admin_server_windows_server_version}-English-Full-Base*"]
  ami_owners                  = ["amazon"]
  vpc_security_group_ids      = [module.securitygroup.id]
  subnet_id                   = element(module.subnets.ids, 2)
  associate_public_ip_address = true
  get_password_data           = true
  aws_managed_policy          = "AmazonEC2RoleforSSM"
}

module "ec2_dns_record_admin" {
  source       = "C:/code/infrastructure-modules//_sub/network/route53-record"
  zone_id      = data.aws_route53_zone.workload.id
  record_name  = [var.admin_server_name]
  record_type  = "CNAME"
  record_value = module.ec2_instance_admin.public_dns
  record_ttl   = 60
}

resource "aws_ssm_association" "assoc_admin" {
  name        = aws_ssm_document.doc.name
  instance_id = module.ec2_instance_admin.id
}

data "template_file" "rdpfile_admin" {
  template = file("${path.module}/rdp_template")
  vars = {
    address = "${element(module.ec2_dns_record_admin.record_name, 0)}.${data.aws_route53_zone.workload.name}"
    username = module.activedirectory.admin_username
  }
}

resource "local_file" "rdpfile_admin" {
  content = data.template_file.rdpfile_admin.rendered
  filename = "C:/code/runsource-iac-demo/terraform//${local.default_resource_name}_${var.admin_server_name}.rdp"
}


# --------------------------------------------------
# Web server 1
# --------------------------------------------------

data "template_file" "user_data_web1" {
  template = file("${path.module}/ec2_user_data_web1")
  vars = {
  }
}

module "ec2_instance_web1" {
  source                      = "C:/code/infrastructure-modules//_sub/compute/ec2-instance"
  instance_type               = var.web1_server_instance_type
  key_name                    = module.ec2_keypair.key_name
  name                        = "${local.default_resource_name}_${var.web1_server_name}"
  user_data                   = data.template_file.user_data_web1.rendered
  ami_platform_filters        = ["windows"]
  ami_name_filters            = ["*Server-${var.web1_server_windows_server_version}-English-Full-Base*"]
  ami_owners                  = ["amazon"]
  vpc_security_group_ids      = [module.securitygroup.id]
  subnet_id                   = element(module.subnets.ids, 2)
  associate_public_ip_address = true
  get_password_data           = true
  private_key_path            = "C:/Users/rasmus/.ssh/id_rsa_ec2_sandbox"
  aws_managed_policy          = "AmazonEC2RoleforSSM"
}

module "ec2_dns_record_web1" {
  source       = "C:/code/infrastructure-modules//_sub/network/route53-record"
  zone_id      = data.aws_route53_zone.workload.id
  record_name  = [var.web1_server_name]
  record_type  = "CNAME"
  record_value = module.ec2_instance_web1.public_dns
  record_ttl   = 60
}

resource "aws_ssm_association" "assoc_web1" {
  name        = aws_ssm_document.doc.name
  instance_id = module.ec2_instance_web1.id
}

data "template_file" "rdpfile_web1" {
  template = file("${path.module}/rdp_template")
  vars = {
    address = "${element(module.ec2_dns_record_web1.record_name, 0)}.${data.aws_route53_zone.workload.name}"
    username = module.activedirectory.admin_username
  }
}

resource "local_file" "rdpfile_web1" {
  content = data.template_file.rdpfile_web1.rendered
  filename = "C:/code/runsource-iac-demo/terraform/${local.default_resource_name}_${var.web1_server_name}.rdp"
}


# --------------------------------------------------
# Web server 2
# --------------------------------------------------

module "ec2_instance_web2" {
  source                      = "../ec2-instance-custom"
  instance_type               = var.web2_server_instance_type
  key_name                    = module.ec2_keypair.key_name
  name                        = "${local.default_resource_name}_${var.web2_server_name}"
  ami_platform_filters        = ["windows"]
  ami_name_filters            = ["web2-*"]
  ami_owners                  = ["944250853760"]
  vpc_security_group_ids      = [module.securitygroup.id]
  subnet_id                   = element(module.subnets.ids, 2)
  associate_public_ip_address = true
  aws_managed_policy          = "AmazonEC2RoleforSSM"
}

module "ec2_dns_record_web2" {
  source       = "C:/code/infrastructure-modules//_sub/network/route53-record"
  zone_id      = data.aws_route53_zone.workload.id
  record_name  = [var.web2_server_name]
  record_type  = "CNAME"
  record_value = module.ec2_instance_web2.public_dns
  record_ttl   = 60
}

resource "aws_ssm_association" "assoc_web2" {
  name        = aws_ssm_document.doc.name
  instance_id = module.ec2_instance_web2.id
}

data "template_file" "rdpfile_web2" {
  template = file("${path.module}/rdp_template")
  vars = {
    address = "${element(module.ec2_dns_record_web2.record_name, 0)}.${data.aws_route53_zone.workload.name}"
    username = "Administrator"
  }
}

resource "local_file" "rdpfile_web2" {
  content = data.template_file.rdpfile_web2.rendered
  filename = "C:/code/runsource-iac-demo/terraform/${local.default_resource_name}_${var.web2_server_name}.rdp"
}
