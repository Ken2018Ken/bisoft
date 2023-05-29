provider "aws" {
    region = "us-east-1"
}

resource "aws_instance" "example" {
    ami = "ami-05171730429275e8e"
    instance_type = "t2.micro"

    tags = {
      Name="terraform trials"
    }
  
}