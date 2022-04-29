
module "bastion-oregon" {
  source = "../../modules/bastion"
  providers = {
    aws.region = aws.us-west-2
  }
  region     = "us-west-2"
  ec2_name   = "kempy-bastion"
  vpc_id     = data.aws_vpc.vpc_oregon.id
  subnet_ids = tolist(data.aws_subnets.public_oregon.ids)
}

resource "local_file" "write-key-oregon" {
  content  = module.bastion-oregon.private_key
  filename = "${path.module}/bastion-key-oregon.pem"
}

output "connect" {
  value = <<-EOF
    chmod 400 bastion-key-oregon.pem
    # Oregon
    ssh -i bastion-key-oregon.pem ec2-user@${module.bastion-oregon.public_ip}
    ssh -i bastion-key-oregon.pem ec2-user@${module.bastion-oregon.public_ip} -N -L 15432:<psqlEndpoint>:5432
  EOF
}


resource "random_string" "random" {
  length  = 64
  special = false
}

resource "aws_ssm_parameter" "dbpwd" {
  provider  = aws.us-west-2
  name      = "/kempy/dbpwd"
  value     = random_string.random.result
  type      = "String"
  overwrite = true
}

module "rds-oregon" {
  source = "../../modules/rds"
  providers = {
    aws.region = aws.us-west-2
  }
  name                  = "kempy-psql"
  ssm_pwd               = aws_ssm_parameter.dbpwd.name
  region                = "us-west-2"
  vpc_id                = data.aws_vpc.vpc_oregon.id
  subnet_ids            = tolist(data.aws_subnets.private_oregon.ids)
  ec2_security_group_id = module.bastion-oregon.security_group
  depends_on = [
    aws_ssm_parameter.dbpwd
  ]
}

output "rds" {
  value = <<-EOF
    # psqlEndpoint: ${module.rds-oregon.psqlEndpoint}
  EOF
}



# terraform taint random_string.random
# resource "random_string" "random" {
#   length           = 64
#   special          = true
#   override_special = "/@£$"
# }

# resource "aws_ssm_parameter" "myenv" {
#   provider  = aws.us-west-2
#   name      = "/myenv/kempy"
#   value     = "my-value1:${random_string.random.result}"
#   type      = "String"
#   overwrite = true
# }

# resource "aws_ssm_parameter" "myenv2" {
#   provider  = aws.us-west-2
#   name      = "/myenv2/kempy"
#   value     = "my-value2:${random_string.random.result}"
#   type      = "String"
#   overwrite = true
# }

# resource "aws_ecr_repository" "fargate-oregon" {
#   provider             = aws.us-west-2
#   name                 = "kempy-fargate-repo-us-west-2"
#   image_tag_mutability = "MUTABLE"
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }

# # MAKE SURE DOCKER is RUNNING: sudo service docker start
# resource "null_resource" "upload-docker" {
#   triggers = {
#     run = 2
#   }
#   provisioner "local-exec" {
#     command = "../../modules/fargate/upload.sh"
#   }
# }

# # Roll ECS
# # aws ecs update-service --service kempy-fargate-ecs-us-west-2 --cluster kempy-fargate-us-west-2 --force-new-deployment --region us-west-2 --profile sandbox

# # == The ECR must exist and an image must be uploaded [set count to 1 once image is in ECR]
# module "fargate-oregon" {
#   count                = 0
#   source               = "../../modules/fargate"
#   permissions_boundary = local.permissions_boundary
#   providers = {
#     aws.region = aws.us-west-2
#   }
#   region             = "us-west-2"
#   repo               = aws_ecr_repository.fargate-oregon.name
#   account_id         = var.account_id
#   public_subnet_ids  = tolist(data.aws_subnets.public_oregon.ids)
#   private_subnet_ids = tolist(data.aws_subnets.private_oregon.ids)
#   vpc_id             = data.aws_vpc.vpc_oregon.id
#   cidr_blocks        = [data.aws_vpc.vpc_oregon.cidr_block]

#   container_secrets = {
#     MYENV  = aws_ssm_parameter.myenv.arn
#     MYENV2 = aws_ssm_parameter.myenv2.arn
#   }

#   ulimits = [
#     { "name" = "nofile", "softLimit" = "1024", "hardLimit" = "4096" },
#     { "name" = "core", "softLimit" = "1", "hardLimit" = "1" }
#   ]

#   desired_count = 1

# }
