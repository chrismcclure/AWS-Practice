terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.3.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region     = "us-east-2"
}

#Begin Variables

#End Variables


#Begin Locals

locals {
    #S3 Bucket
    bucket_name = "challenge-private-bucket"
    private = "private"


    #EC2


    #Keypair
    key_pair_name = "test_key_1"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkTN8p1M4K4BSd6sDYVfvGRRk1IFU7lLrip/sZxE+ECLW32tNCUqhqPwT82iohpSVoBABghiYME6oQgoQ5n/7zlG5e23Lsf4holYr6HUivAj4yG0G4/XN13TK2eWSFP+QtceGTI2u+lKFYFpnnM6vSM5F4qf0FPxISSHCZ2mojifrZi8Bty+HB/DWzI6cv3gp2NVC7yupYZeFIFlxptFlOmXBVGxSTd5DLqKjfTDztj7NwtB/7GEl09RPsYNdsDugxO24l+1mmyVsJR50n/4Osq0XYmicgCKqBVbe5KXlQy78cO+YLwBVCjzTsTCMdCEQ80kyjmFPFY0zIvgL2mwhB"
}


#End Locals


#Begin Data


#End Data


#Begin Resources

resource "aws_key_pair" "test_key" {
  key_name   = local.key_pair_name
  #Terraform doc had email at the end
  #https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws
  #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
  public_key = local.public_key
}

resource "aws_s3_bucket" "private" {
  bucket = local.bucket_name

#TODO, get rid of this if I dont' need it
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "private" {
  bucket = aws_s3_bucket.private.id
  acl    = local.private
}

resource "aws_instance" "challenge_instance" {
    #Found the ami in the wizard for type and region
  ami           = "ami-05803413c51f242b7" #Wasn't sure which to use
  instance_type = "t2.micro"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id = "vpc-19efe07e" #Where do I get this

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.210.84.220/32"]
  }

#   egress = [ {
#     cidr_blocks = [ "value" ]
#     description = "value"
#     from_port = 1
#     ipv6_cidr_blocks = [ "value" ]
#     prefix_list_ids = [ "value" ]
#     protocol = "value"
#     security_groups = [ "value" ]
#     self = false
#     to_port = 1
#   } ]
}

#End Resources