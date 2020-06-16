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
  description = local.default_resource_name
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
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 3389
  to_port           = 3389
}

module "securitygrouprule_http" {
  source            = "C:/code/infrastructure-modules//_sub/compute/ec2-sgrule-cidr"
  security_group_id = module.securitygroup.id
  description       = "Allow HTTP access from internet"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
}

module "securitygrouprule_ssh" {
  source            = "C:/code/infrastructure-modules//_sub/compute/ec2-sgrule-cidr"
  security_group_id = module.securitygroup.id
  description       = "Allow HTTP access from internet"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
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
# Server general
# --------------------------------------------------

module "ec2_keypair" {
  source     = "C:/code/infrastructure-modules//_sub/compute/ec2-keypair"
  name       = local.default_resource_name
  public_key = var.ec2_public_key
}


# --------------------------------------------------
# Web server 1 - off-the-shelve image
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
  private_key_path            = var.ec2_private_key_path
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

data "template_file" "rdpfile_web1" {
  template = file("${path.module}/rdp_template")
  vars = {
    address = "${element(module.ec2_dns_record_web1.record_name, 0)}.${data.aws_route53_zone.workload.name}"
    username = ".\\administrator"
  }
}

resource "local_file" "rdpfile_web1" {
  content = data.template_file.rdpfile_web1.rendered
  filename = "C:/code/runsource-iac-demo/terraform/${local.default_resource_name}_${var.web1_server_name}.rdp"
}


# --------------------------------------------------
# Web server 2 - custom image
# --------------------------------------------------

module "ec2_instance_web2" {
  source                      = "C:/code/infrastructure-modules//_sub/compute/ec2-instance"
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

data "template_file" "rdpfile_web2" {
  template = file("${path.module}/rdp_template")
  vars = {
    address = "${element(module.ec2_dns_record_web2.record_name, 0)}.${data.aws_route53_zone.workload.name}"
    username = ".\\administrator"
  }
}

resource "local_file" "rdpfile_web2" {
  content = data.template_file.rdpfile_web2.rendered
  filename = "C:/code/runsource-iac-demo/terraform/${local.default_resource_name}_${var.web2_server_name}.rdp"
}
