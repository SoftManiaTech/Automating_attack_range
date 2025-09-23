terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "random_id" "suffix" {
  byte_length = 4
}

# --- Get Latest Ubuntu 24.04 AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical official

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "attack_range" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  key_name               = var.key_name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = "attack-range-server"
  }
}

resource "aws_security_group" "attack_range_sg" {
  name        = "attack-range-sg-${random_id.suffix.hex}"
  description = "Security group for attack-range-server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 9999
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

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.attack_range_sg.id
  network_interface_id = aws_instance.attack_range.primary_network_interface_id
}

output "attack_range_public_ip" {
  value = aws_instance.attack_range.public_ip
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<EOT
[attack_range]
${aws_instance.attack_range.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file="/home/ubuntu/Automating_attack_range/keys/${var.key_name}.pem" ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT
}

# --- CREATE group_vars/all.yml dynamically ---
resource "local_file" "ansible_all_yml" {
  filename = "${path.module}/group_vars/all.yml"

  content = <<EOT
terraform_url: "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip"
terraform_zip: "/tmp/terraform.zip"
awscli_url: "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
awscliv2_zip: "/tmp/awscliv2.zip"

aws_access_key: "${var.aws_access_key}"
aws_secret_key: "${var.aws_secret_key}"
aws_region: "${var.aws_region}"

splunk_password: "${var.splunk_password}"
attack_range_password: "${var.attack_range_password}"
attack_range_key_name: "${var.key_name}"
EOT
}

