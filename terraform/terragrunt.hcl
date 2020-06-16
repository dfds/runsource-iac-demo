terraform {
  source = "./modules//iac-demo"
}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "raras-sandbox-state"
    key            = "iac-demo/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
  }
}

inputs = {

  aws_region             = "eu-west-1"
  workload_dns_zone_name = "raras.dfds.cloud"

  ec2_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/9+bC8OYkd9Ir4ZkA1hkv9oZhZ8piH9LzTbp5EEDz1G+rUHVyTWfKE4ItP1WdI0xtUCAKrN9Ufj1/wjZ+krG4g3JfuGhmPSJzPFP5bAiJ0awV1xSL5BO37Tu7kQiA5uBCo83lmE4cvuHTmFMTHh4IXxs5jAubnZjZkscobaDGBM11wfxoW/5oWQ2i0Tn5eULoCsKtBTz4XW/3B92UYx5D8pDB2jBb0WZqWA7OI3pXXYZaS7WsaReC6Jwb7R1NGcc65sAHt37rDYLKIQei3XrRWpWN8KGN75QiDX29/vBxYzvfKKFrixmzi0m95sctr0pekaF205xijtIgoUMaVLVLNp6ocIu0u3yazSMoqcp8cjgcPvOrJ9JQYv9ZiDYJguIJbe356pD4M+py5+dIMf2Jw52ONv4kPbr1dccUGTk5uU5T3LFd3sOd9/8/mSUlIaDwWbcMEO/ooF0z3Kb3TYEz6av3RJRhePqowIkh2HSSTC0nJtlrRzWpw8dtsiKLhR05dD6CXK/4MkVTNltS2QF39lXXegkqWew766rZLR4ciRuJ2JDrbEKGbOlz8RrUWBEybdSJl8BkMY61ouBgGy6o2bQqjQivi70Pf288HMJ17HMBB/XqwWNhUx9GMH/k9z0P6LrsHZkkNQwXAU5YAibvLpCJLMtVVJg/Ybzbbu39HQ== ec2@sandbox"

  web1_server_name                   = "web1"
  web1_server_windows_server_version = "2019"
  web1_server_instance_type          = "t3.medium"

  web2_server_name                   = "web2"
  web2_server_instance_type          = "t3.medium"

}
