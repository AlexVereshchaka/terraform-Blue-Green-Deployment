provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      CreatedBy = "Terraform"
      Goal    = "Test-Blue/Green Deployment"
    }
  }
}


# data "aws_ami" "my_ami" {
#   most_recent = true
#   owners = ["231873460872"]
  

# #   filter {
# #     name   = "name"
# #     values = ["389DS"]
# #   }
# #   filter {
# #     name = "owner-id"
# #     values = ["231873460872"]
# #   }
# }


#-------------------------------------------------------------------------------
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.working.names[0]
}


resource "aws_launch_template" "server" {
  name                   = "Blue-Green-LT"
  image_id               = "ami-07e910bcd63425b7a"
  instance_type          = "t2.nano"
  vpc_security_group_ids = [data.aws_security_group.default.id]
  user_data              = filebase64("./user_data.sh")
}

resource "aws_autoscaling_group" "server" {
  name                = "BAWSUATGATE3_10_112-ASG-Ver-${aws_launch_template.server.latest_version}"
  min_size            = 1
  max_size            = 2
  min_elb_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = [aws_default_subnet.default_az1.id]
  target_group_arns   = [aws_lb_target_group.server_nlb.arn]

  launch_template {
    id      = aws_launch_template.server.id
    version = aws_launch_template.server.latest_version
  }

  dynamic "tag" {
    for_each = {
      Name   = "AWSUATGATE3_10_112-v${aws_launch_template.server.latest_version}"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

#-------------------------------------------------------------------------------
resource "aws_lb" "nlb" {
  name               = "Blue-Green-NLB"
  load_balancer_type = "network"
  internal = true
  security_groups    = [data.aws_security_group.default.id]
  subnets            = [aws_default_subnet.default_az1.id]
}

resource "aws_lb_target_group" "server_nlb" {
  name                 = "Blue-Green-TG"
  vpc_id               = data.aws_vpc.procard.id
  port                 = 80
  protocol             = "tcp"
  deregistration_delay = 10 # seconds
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "tcp"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server_nlb.arn
  }
}


