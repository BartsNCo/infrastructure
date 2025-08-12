data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-instance-key"
  public_key = file("${path.module}/ec2/ec2-key.pub")
}

resource "aws_security_group" "ec2_ssh" {
  name        = "ec2-ssh-access"
  description = "Security group for EC2 SSH access"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-ssh-security-group"
  }
}

resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5a.xlarge"
  key_name      = aws_key_pair.ec2_key.key_name

  vpc_security_group_ids = [aws_security_group.ec2_ssh.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 60
    encrypted   = true
  }

  tags = {
    Name = "Ubuntu-EC2-Instance"
  }
}
