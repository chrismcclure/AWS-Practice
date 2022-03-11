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


locals {

    #Started with locals and realized it wans't worth the time on a small litte file like this.

    #S3 Bucket
    bucket_name = "challenge-private-bucket"
    private = "private"

    #Keypair
    ssh_key_name = "test_key_ssh"
    key_pair_name = "test_key_1"
    file_path_public = "C:/Users/chris/Desktop/K8sPlayground/AWS-Practice/${local.ssh_key_name}_pub.pem"
    file_path_private = "C:/Users/chris/Desktop/K8sPlayground/AWS-Practice/${local.ssh_key_name}.pem"
}

# Need to create a way to output the ssh file
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Need to create a key pair
# Wanted to try this in code, but as I test I might need to create it manully and add the public and use the private I downloaded
resource "aws_key_pair" "test_key" {
  key_name   = local.key_pair_name
  public_key = tls_private_key.ssh.public_key_openssh
}

#Not sure that I need this, but I'll leave it for now
resource "local_file" "pem_file_public" {
  #On Mac, where where I would put it:  filename = pathexpand("~/.ssh/${local.ssh_key_name}.pem")
  filename = pathexpand(local.file_path_public)
  file_permission = "600"
  directory_permission = "700"
  sensitive_content = tls_private_key.ssh.public_key_pem
}

#This is money and a big time saver
resource "local_file" "pem_file_private" {
  #On Mac, where where I would put it:  filename = pathexpand("~/.ssh/${local.ssh_key_name}.pem")
  filename = pathexpand(local.file_path_private)
  file_permission = "600"
  directory_permission = "700"
  sensitive_content = tls_private_key.ssh.private_key_pem
}

# Pretty simple, make a bucket
resource "aws_s3_bucket" "private" {
  bucket = local.bucket_name
  force_destroy = true //Destoy the bucket if it has stuff in it.
}

# Found this and seems to be the right stuff for making it private
# There is a property on the buckety it self that is private as well.
resource "aws_s3_bucket_public_access_block" "some_bucket_access" {
  bucket = aws_s3_bucket.private.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
}

# Seems that a way to add this to the ec2 instance is through a profile.
resource "aws_iam_instance_profile" "some_profile" {
  name = "some-profile"
  role = aws_iam_role.some_role.name
}

# this seems to be the place to put my role and policy together
resource "aws_iam_role_policy_attachment" "some_bucket_policy" {
  role       = aws_iam_role.some_role.name
  policy_arn = aws_iam_policy.bucket_policy.arn
}

#Create a role.
#Not a 100% sure if I need this?
resource "aws_iam_role" "some_role" {
  name = "made_up_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# What appears to be the correct policy for what I need
resource "aws_iam_policy" "bucket_policy" {
  name        = "my-bucket-policy"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
       {
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
      },
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::${local.bucket_name}/*",
          "arn:aws:s3:::${local.bucket_name}"
        ]
      }
    ]
  })
}

resource "aws_instance" "challenge_instance" {
  ami           = "ami-05803413c51f242b7"    #Which version of ubuntu is running
  instance_type = "t2.micro"
  key_name=  aws_key_pair.test_key.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile = aws_iam_instance_profile.some_profile.id

  connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(local.file_path_private)
      timeout     = "4m"
   }
}

output "shh_command" {  
  value = "ssh -i 'test_key_ssh.pem'  ubuntu@${aws_instance.challenge_instance.public_dns}"
} 

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "174.70.63.158/32" ]
     from_port        = 22
     to_port          = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     self             = false
     description      = ""
     security_groups  = []
  }
  ]
}