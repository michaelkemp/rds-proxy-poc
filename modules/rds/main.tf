data "aws_ssm_parameter" "dbpwd" {
  name = var.ssm_pwd
}

resource "aws_db_parameter_group" "parameter-group" {
  provider = aws.region
  name     = "${var.name}-parameter-group-${var.region}"
  family   = "postgres14"
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
  engine_version                      = "14.1"
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
