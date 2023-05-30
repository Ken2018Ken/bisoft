#Specifies the provider and region where the clod instrastructure resources are being created
provider "aws" {
    region = "us-east-1"
}

# creating an instance from an existing image, and using an existing security group

resource "aws_instance" "solo_instance" {
    ami = "ami-0d659ab07f0f08020"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello Ninjas from space"> index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    user_data_replace_on_change = true

    tags = {
      Name="terraform trials"
    }
  
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}


variable "server_port"{
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
}

output "public_ip" {
  value= aws_instance.solo_instance.public_ip
  description ="The public ip address of the web server"
  
}

data "aws_vpc" "default" {
  default = true
  
}



resource "aws_launch_configuration" "example" {
  image_id = "ami-0d659ab07f0f08020"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]
  user_data = <<-EOF
                #!/bin/bash
                echo "Hello Ninjas from space"> index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
  
  #required when using a launch configuration with an auto scaling group

  lifecycle {
    create_before_destroy = true
  }
  
}

# creating an auto scaling group

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
  
}

# getting list of subnets from the default vpc for use with the aws load balancer
data "aws_subnets" "default" {
  filter {
    name= "vpc-id"
    values = [ data.aws_vpc.default.id ]
  }
  
}


#creating an application load balancer (ALB is optimal for severs that serve https)

resource "aws_lb" "example"{
  name = "terraform-asg-example"
  load_balancer_type ="application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb.id]
}

# creating load balancer listerners

resource "aws_lb_listener" "http"{
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"

  # By default, return a simple 404 page

  default_action{
    type="fixed-response"

    fixed_response {
      content_type="text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}

#create aws security group to allow incoming requests on port 80 so that you can access the LB over HTTP and allow outgoing requests on all ports so that the load balanceer can perform health checks

resource "aws_security_group" "alb"{
  name = "terraform-example-alb"

  #allow in bound HTTP requests on port 80
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  # allow outbound requests

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }


}

# create a target group for your ASG.

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol ="HTTP"
  vpc_id = data.aws_vpc.default.id

# creating health check parameters for the target group
  health_check {
    path= "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  
}

#create listener rules

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition{
    path_pattern {
      values = ["*"]
    }
  }
# load balancer action on encountering trafic from out

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# get load balancer DNS name and out put it when terraform apply is done.
output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
  
}