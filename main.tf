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
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkTN8p1M4K4BSd6sDYVfvGRRk1IFU7lLrip/sZxE+ECLW32tNCUqhqPwT82iohpSVoBABghiYME6oQgoQ5n/7zlG5e23Lsf4holYr6HUivAj4yG0G4/XN13TK2eWSFP+QtceGTI2u+lKFYFpnnM6vSM5F4qf0FPxISSHCZ2mojifrZi8Bty+HB/DWzI6cv3gp2NVC7yupYZeFIFlxptFlOmXBVGxSTd5DLqKjfTDztj7NwtB/7GEl09RPsYNdsDugxO24l+1mmyVsJR50n/4Osq0XYmicgCKqBVbe5KXlQy78cO+YLwBVCjzTsTCMdCEQ80kyjmFPFY0zIvgL2mwhB"
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

  #Terraform doc for public key had email at the end
  #https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws
  #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "pem_file" {
  #On Mac, where where I would put it:  filename = pathexpand("~/.ssh/${local.ssh_key_name}.pem")
  filename = pathexpand("C:/Users/chris/Desktop/K8sPlayground/AWS-Practice/${local.ssh_key_name}.pem")
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
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          #I don't think I need put or delete, but I'll leave them there when I test
          #https://aws.amazon.com/premiumsupport/knowledge-center/ec2-instance-access-s3-bucket/
          #"s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          #"s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::${local.bucket_name}"
        ]
      }
    ]
  })
}

# Got most of the security group right I think. 
# Still need to figure out the proper values for Engress
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/24"] //Dont use 0.0.0.0
  }

  #Figure out what goes in here
  # egress {
  #   from_port       = 0
  #   to_port         = 0
  #   protocol        = "-1"
  #   prefix_list_ids = [aws_vpc_endpoint.my_endpoint.prefix_list_id]
  # }
}

# Finally put i all together with the EC2 Instance. 
resource "aws_instance" "challenge_instance" {
  ami           = "ami-05803413c51f242b7"  # Found the ami in the wizard for type and region.  This appeared to be the cheapest
  instance_type = "t2.micro"
  key_name=  aws_key_pair.test_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  iam_instance_profile = aws_iam_instance_profile.some_profile.id
}