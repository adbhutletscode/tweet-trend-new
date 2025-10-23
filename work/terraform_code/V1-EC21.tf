provider "aws"  {
  region = "us-east-1" 
 
}


 resource "aws_instance" "demo-server-5" {
  ami           = "ami-0360c520857e3138f"
  instance_type = "t3.micro"
  key_name = "t1"


 }

 resource "aws_security_group" "demo-sgg" {
name = "my-sg"
description = "Allow ssh"



ingress {
    description = "shh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

   
 }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}


}
