provider "aws" {
    region = "us-east-1"
}

resource "aws_instance" "example" {
    ami = "ami-0d659ab07f0f08020"
    instance_type = "t2.micro"
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello Ninjas"> index.html
                nohup busybox httpd -f -p 8080 &
                EOF
    user_data_replace_on_change = true

    tags = {
      Name="terraform trials"
    }
  
}