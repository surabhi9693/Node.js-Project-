provider "aws" {
  region = "us-west-2"
}

resource "aws_ecs_cluster" "hello_world" {
  name = "hello-world-cluster"
}

variable "docker_image" {
  description = "The Docker image to deploy"
  type        = string
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoletestrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task-1"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "hello-world"
      image     = "339713100600.dkr.ecr.us-west-2.amazonaws.com/hello-world:v1.0.0"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service-test"
  cluster         = aws_ecs_cluster.hello_world.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    security_groups  = ["sg-07c6caad7f69dd320"]
    subnets          = ["subnet-0f7bf31dcfe3ad564", "subnet-030f6062c36d7a4f2"]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.hello_world_tg.arn
    container_name   = "hello-world"
    container_port   = 3000
  }
}

resource "aws_alb" "hello_world_alb" {
  name               = "hello-world-alb-6"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-07c6caad7f69dd320"]
  subnets            = ["subnet-0f7bf31dcfe3ad564", "subnet-030f6062c36d7a4f2"]

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "hello_world_tg" {
  name     = "hello-world-tg-6"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "vpc-07eff38e2a44c08ca"
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.hello_world_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.hello_world_tg.arn
}
}
