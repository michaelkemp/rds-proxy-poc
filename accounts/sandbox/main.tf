locals {
  key_name = "bastion-key-oregon.pem"
}

resource "random_string" "testdb" {
  length  = 16
  special = false
}

resource "aws_ssm_parameter" "testdb" {
  provider  = aws.us-west-2
  name      = "/kempy/testdb"
  value     = random_string.testdb.result
  type      = "String"
  overwrite = true
}

module "bastion-oregon" {
  source = "../../modules/bastion"
  providers = {
    aws.region = aws.us-west-2
  }
  region     = "us-west-2"
  ec2_name   = "kempy-bastion"
  vpc_id     = data.aws_vpc.vpc_oregon.id
  subnet_ids = tolist(data.aws_subnets.public_oregon.ids)
  testdb_pwd = random_string.testdb.result
}

resource "local_file" "write-key-oregon" {
  content  = module.bastion-oregon.private_key
  filename = "${path.module}/${local.key_name}"
}

resource "local_file" "run-on-bastion" {
  content  = <<-EOF
    #!/bin/bash
    PGPASSWORD=${random_string.main.result} psql -h ${module.rds-oregon.psqlEndpoint} -U kempypsql -f create-db.sql
    PGPASSWORD=${random_string.testdb.result} psql -h ${module.rds-oregon.psqlEndpoint} -d testdb -U testuser -f create-table.sql
  EOF
  filename = "${path.module}/run-on-bastion.sh"
}

resource "random_string" "main" {
  length  = 16
  special = false
}

resource "aws_ssm_parameter" "main" {
  provider  = aws.us-west-2
  name      = "/kempy/main"
  value     = random_string.main.result
  type      = "String"
  overwrite = true
}

module "rds-oregon" {
  source = "../../modules/rds"
  providers = {
    aws.region = aws.us-west-2
  }
  name                  = "kempy-psql"
  ssm_pwd               = aws_ssm_parameter.main.name
  region                = "us-west-2"
  vpc_id                = data.aws_vpc.vpc_oregon.id
  subnet_ids            = tolist(data.aws_subnets.private_oregon.ids)
  ec2_security_group_id = module.bastion-oregon.security_group
  depends_on = [
    aws_ssm_parameter.main
  ]
}

output "connect" {
  value = <<-EOF
    chmod 400 ${local.key_name}
    # Oregon
    ssh -i ${local.key_name} ec2-user@${module.bastion-oregon.public_ip}
    # Tunnel to Postgres RDS
    ssh -i ${local.key_name} ec2-user@${module.bastion-oregon.public_ip} -N -L 15432:${module.rds-oregon.psqlEndpoint}:5432
  EOF
}


resource "aws_ssm_parameter" "DBHOST" {
  provider  = aws.us-west-2
  name      = "/kempy/DBHOST"
  value     = module.rds-oregon.psqlEndpoint
  type      = "String"
  overwrite = true
}
resource "aws_ssm_parameter" "DBNAME" {
  provider  = aws.us-west-2
  name      = "/kempy/DBNAME"
  value     = "testdb"
  type      = "String"
  overwrite = true
}
resource "aws_ssm_parameter" "DBUSER" {
  provider  = aws.us-west-2
  name      = "/kempy/DBUSER"
  value     = "testuser"
  type      = "String"
  overwrite = true
}
resource "aws_ssm_parameter" "DBPASS" {
  provider  = aws.us-west-2
  name      = "/kempy/DBPASS"
  value     = random_string.testdb.result
  type      = "String"
  overwrite = true
}


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
#     run = timestamp()
#   }
#   provisioner "local-exec" {
#     command = "../../modules/fargate/upload.sh"
#   }
# }

# # Roll ECS
# # aws ecs update-service --service kempy-fargate-ecs-us-west-2 --cluster kempy-fargate-us-west-2 --force-new-deployment --region us-west-2 --profile sandbox

# # == The ECR must exist and an image must be uploaded [set count to 1 once image is in ECR]
# module "fargate-oregon" {
#   count  = 1
#   source = "../../modules/fargate"
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
#   rds_security_group = module.rds-oregon.rdsSecurityGroup

#   container_secrets = {
#     DBHOST = aws_ssm_parameter.DBHOST.arn
#     DBNAME = aws_ssm_parameter.DBNAME.arn
#     DBUSER = aws_ssm_parameter.DBUSER.arn
#     DBPASS = aws_ssm_parameter.DBPASS.arn
#   }

#   ulimits = [
#     { "name" = "nofile", "softLimit" = "1024", "hardLimit" = "4096" },
#     { "name" = "core", "softLimit" = "1", "hardLimit" = "1" }
#   ]

#   desired_count = 1
# }
