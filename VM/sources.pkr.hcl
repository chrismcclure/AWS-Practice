packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "learn-packer-linux-aws"
  instance_type = "t2.micro"
  region        = "us-east-2"
  source_ami_filter {
    filters = {
    name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}


build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "ansible" {
      playbook_file = "./playbook.yml"
      user = "ubuntu"
    }

  provisioner "file" {
    source = "awscli.sh"
    destination = "~/awscli.sh"
    }

  provisioner "shell" {
    remote_folder = "~"
    inline = [
       "sudo bash ~/awscli.sh",
       "rm ~/awscli.sh"
    ]
  }
}
