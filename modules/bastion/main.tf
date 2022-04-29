## =============== Get External IP Address ===============
data "external" "ipify" {
  program = ["curl", "-s", "https://api.ipify.org?format=json"]
}

## =============== Create Key ===============
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "generated_key" {
  provider   = aws.region
  key_name   = "${var.ec2_name}-${var.region}"
  public_key = tls_private_key.key.public_key_openssh
}

## =============== SSM Access Role ===============
resource "aws_iam_role" "ec2-role" {
  name               = "${var.ec2_name}-role"
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
             "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOF  
}

resource "aws_iam_policy_attachment" "attachment" {
  name       = "${var.ec2_name}-role-attachment"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.ec2_name}-profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_security_group" "security-group" {
  provider    = aws.region
  name        = "${var.ec2_name}-security-group-${var.region}"
  description = "Security Group for ${var.ec2_name}"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${data.external.ipify.result.ip}/32"]
    description = "SSH Ingress"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon-linux-2" {
  provider    = aws.region
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "ec2-instance" {
  provider      = aws.region
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.nano"
  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "standard"
  }
  subnet_id                   = var.subnet_ids[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.security-group.id]
  tags = {
    Name = var.ec2_name
  }
  user_data = local.userdata
}

output "public_ip" {
  value = aws_instance.ec2-instance.public_ip
}

output "private_key" {
  value = tls_private_key.key.private_key_pem
}

output "security_group" {
  value = aws_security_group.security-group.id
}
