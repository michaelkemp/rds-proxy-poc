############## ECR ##############
locals {
  repo         = var.repo
  ecrUrl       = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  docker_image = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.repo}"
}

data "aws_ecr_repository" "kempy-fargate-repo" {
  provider = aws.region
  name     = local.repo
}

resource "aws_ecr_lifecycle_policy" "kempy-fargate-repo" {
  provider   = aws.region
  repository = data.aws_ecr_repository.kempy-fargate-repo.name
  policy     = <<-EOF
    {
      "rules": [
        {
          "rulePriority": 1,
          "description": "Keep last 5 images",
          "selection": {
            "tagStatus": "any",
            "countType": "imageCountMoreThan",
            "countNumber": 5
          },
          "action": {
            "type": "expire"
          }
        }
      ]
    }
  EOF
}

data "aws_ecr_image" "kempy-fargate" {
  provider        = aws.region
  repository_name = local.repo
  image_tag       = "latest"
}

############## ECS ##############

resource "aws_ecs_cluster" "kempy-fargate-cluster" {
  provider = aws.region
  name     = "kempy-fargate-${var.region}"
}

resource "aws_ecs_service" "kempy-fargate-ecs" {
  provider             = aws.region
  name                 = "kempy-fargate-ecs-${var.region}"
  cluster              = aws_ecs_cluster.kempy-fargate-cluster.id
  task_definition      = aws_ecs_task_definition.kempy-fargate-task.arn
  desired_count        = var.desired_count
  launch_type          = "FARGATE"
  force_new_deployment = true

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.kempy-fargate-sg.id]
    subnets          = tolist(var.private_subnet_ids)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kempy-fargate-targetgroup.arn
    container_name   = "kempy-fargate-${var.region}"
    container_port   = "8080"
  }
}

resource "aws_cloudwatch_log_group" "kempy-fargate-cloudwatch" {
  provider = aws.region
  name     = "/ecs/kempy-fargate-ecs-${var.region}"
}

locals {
  name  = "kempy-fargate-${var.region}"
  image = "${local.docker_image}:latest@${data.aws_ecr_image.kempy-fargate.image_digest}"
  secrets = [
    for key in keys(var.container_secrets) :
    {
      name      = key
      valueFrom = "${lookup(var.container_secrets, key)}"
    }
  ]
  ulimits = [
    for limit in var.ulimits :
    {
      name      = limit.name
      hardLimit = tonumber(limit.hardLimit)
      softLimit = tonumber(limit.softLimit)
    }
  ]
  portMappings = [
    {
      "containerPort" : 8080
    }
  ]
  logConfiguration = {
    "logDriver" : "awslogs",
    "options" : {
      "awslogs-region" : "${var.region}",
      "awslogs-group" : "/ecs/kempy-fargate-ecs-${var.region}",
      "awslogs-stream-prefix" : "ecs"
    }
  }

  container_definition = {
    name             = local.name
    image            = local.image
    secrets          = local.secrets
    ulimits          = local.ulimits
    portMappings     = local.portMappings
    logConfiguration = local.logConfiguration
  }

  container_definition_json = format("[%s]", jsonencode(local.container_definition))
}

resource "aws_ecs_task_definition" "kempy-fargate-task" {
  provider                 = aws.region
  family                   = "kempy-fargate-${var.region}"
  execution_role_arn       = aws_iam_role.kempy-fargate-execution-role.arn
  task_role_arn            = aws_iam_role.kempy-fargate-task-role.arn
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  container_definitions    = local.container_definition_json
}

resource "aws_iam_role" "kempy-fargate-execution-role" {
  name               = "kempy-fargate-execution-role-${var.region}"
  assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [{
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
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
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
          },
          {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameters",
              "ssm:GetParameter",
              "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
          } 
        ]
      }
    EOF
  }

}

resource "aws_iam_role_policy_attachment" "kempy-fargate-execution-policy" {
  role       = aws_iam_role.kempy-fargate-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "kempy-fargate-task-role" {
  name               = "kempy-fargate-task-role-${var.region}"
  assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [{
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Effect": "Allow"
        }]
    }
  EOF
  inline_policy {
    name   = "kempy-fargate-task-role-policy"
    policy = <<-EOF
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
          },
          {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameters",
              "ssm:GetParameter",
              "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
          } 
        ]
      }
    EOF
  }
}

resource "aws_security_group" "kempy-fargate-sg" {
  provider    = aws.region
  name        = "kempy-fargate-sg-${var.region}"
  description = "kempy-fargate-sg-${var.region}"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = var.cidr_blocks
    description = "8080 Ingress - Managed by Terraform"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kempy-fargate-sg.id
  description              = "Access from Fargate Security Group"
  security_group_id        = var.rds_security_group
}

############## ALB ##############

resource "aws_lb" "kempy-fargate-alb" {
  provider           = aws.region
  name               = "kempy-fargate-alb-${var.region}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kempy-fargate-alb-sg.id]
  subnets            = tolist(var.public_subnet_ids)
}

resource "aws_lb_target_group" "kempy-fargate-targetgroup" {
  provider    = aws.region
  name        = "kempy-fargate-tg-${var.region}"
  port        = "8080"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

resource "aws_lb_listener" "kempy-fargate-listener" {
  provider          = aws.region
  load_balancer_arn = aws_lb.kempy-fargate-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kempy-fargate-targetgroup.arn
  }
}

resource "aws_security_group" "kempy-fargate-alb-sg" {
  provider    = aws.region
  name        = "kempy-fargate-alb-sg-${var.region}"
  description = "kempy-fargate-alb-sg-${var.region}"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH Ingress - Managed by Terraform"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}