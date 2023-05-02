
data "aws_availability_zones" "working" {}

data "aws_subnets" "subnet_ids" {
  tags                                      = {
    Name                                    = var.subnet_name
  }
}

data "aws_security_group" "default" {
    name = "default"
    
}

data "aws_vpc" "procard" {}