data "aws_ssm_parameter" "dbpwd" {
  name = var.ssm_pwd
}

resource "aws_db_parameter_group" "parameter-group" {
  provider = aws.region
  name     = "${var.name}-parameter-group-${var.region}"
  family   = "postgres13"
  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "rds.force_ssl"
    value        = "0"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "wal_sender_timeout"
    value        = "0"
    apply_method = "pending-reboot"
  }

}

resource "aws_db_subnet_group" "rds-subnet-group" {
  provider   = aws.region
  name       = "${var.name}-rds-subnet-group-${var.region}"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds-security-group" {
  provider    = aws.region
  name        = "${var.name}-rds-security-group-${var.region}"
  description = "RDS Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "TCP"
    security_groups = [var.ec2_security_group_id]
    description     = "Access from Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds" {
  provider                            = aws.region
  identifier                          = "${var.name}-${var.region}"
  iam_database_authentication_enabled = true
  skip_final_snapshot                 = true
  deletion_protection                 = false
  allocated_storage                   = 20
  storage_type                        = "gp2"
  engine                              = "postgres"
  engine_version                      = "13.4"
  instance_class                      = "db.t4g.micro"
  db_name                             = replace(var.name, "-", "")
  username                            = replace(var.name, "-", "")
  password                            = data.aws_ssm_parameter.dbpwd.value
  db_subnet_group_name                = aws_db_subnet_group.rds-subnet-group.name
  vpc_security_group_ids              = [aws_security_group.rds-security-group.id]
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  depends_on                          = [aws_cloudwatch_log_group.log-group]
  parameter_group_name                = aws_db_parameter_group.parameter-group.id
}

resource "aws_cloudwatch_log_group" "log-group" {
  provider          = aws.region
  name              = "/aws/rds/instance/${var.name}-${var.region}/postgresql"
  retention_in_days = 7
}

output "psqlEndpoint" {
  value = aws_db_instance.rds.address
}
output "rdsSecurityGroup" {
  value = aws_security_group.rds-security-group.id
}


###################################### RDS PROXY ###########################################
resource "aws_secretsmanager_secret" "secrets-manager" {
  name = "kempy/rds"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.secrets-manager.id
  secret_string = <<-EOF
    {
      "username": "${replace(var.name, "-", "")}",
      "password": "${data.aws_ssm_parameter.dbpwd.value}",
      "engine": "postgres",
      "host": "${aws_db_instance.rds.address}",
      "port": ${aws_db_instance.rds.port},
      "dbname": "${replace(var.name, "-", "")}"
      "dbInstanceIdentifier": "${aws_db_instance.rds.identifier}"
    }
  EOF
}

resource "aws_db_proxy" "proxy" {
  name                   = "${var.name}-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = false
  role_arn               = aws_iam_role.kempy-rds-proxy-role.arn
  vpc_security_group_ids = [aws_security_group.rds-security-group.id]
  vpc_subnet_ids         = var.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "RDS Username/Password"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.secrets-manager.arn
  }
}

resource "aws_db_proxy_default_target_group" "target_group" {
  db_proxy_name = aws_db_proxy.proxy.name
  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "target" {
  db_instance_identifier = aws_db_instance.rds.id
  db_proxy_name          = aws_db_proxy.proxy.name
  target_group_name      = aws_db_proxy_default_target_group.target_group.name
}

resource "aws_iam_role" "kempy-rds-proxy-role" {
  name               = "kempy-rds-proxy-role"
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "rds.amazonaws.com"
        },
        "Effect": "Allow"
      }]
    }
  EOF
  inline_policy {
    name   = "kempy-fargate-role-policy"
    policy = <<-EOF
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "GetSecretValue",
            "Action": [
              "secretsmanager:GetSecretValue"
            ],
            "Effect": "Allow",
            "Resource": [
              "${aws_secretsmanager_secret.secrets-manager.arn}"
            ]
          },
          {
            "Sid": "DecryptSecretValue",
            "Action": [
              "kms:Decrypt"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:kms:us-west-2:847068433460:key/727ee28f-ed78-4b3c-9e95-acbf04a4458b"
            ],
            "Condition": {
              "StringEquals": {
                "kms:ViaService": "secretsmanager.us-west-2.amazonaws.com"
              }
            }
          }
        ]
      }    
    EOF
  }

}
