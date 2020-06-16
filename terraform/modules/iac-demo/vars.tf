variable "aws_region" {
  type = string
}


# --------------------------------------------------
# Networking
# --------------------------------------------------

variable "vpc_cidr_block" {
  default = "192.168.0.0/16"
}

variable "subnet_cidr_blocks" {
  default = ["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"]
}

variable "workload_dns_zone_name" {
  type = string
}


# --------------------------------------------------
# Server common
# --------------------------------------------------

variable "ec2_public_key" {
  type = string
}

variable "ec2_private_key_path" {
  type    = string
  default = ""
}


# --------------------------------------------------
# Web server 1
# --------------------------------------------------

variable "web1_server_name" {
  type = string
}

variable "web1_server_instance_type" {
  type    = string
}

variable "web1_server_windows_server_version" {
  type    = string
  default = ""
}


# --------------------------------------------------
# Web server 2
# --------------------------------------------------

variable "web2_server_name" {
  type = string
}

variable "web2_server_instance_type" {
  type    = string
}

variable "web2_server_windows_server_version" {
  type    = string
  default = ""
}