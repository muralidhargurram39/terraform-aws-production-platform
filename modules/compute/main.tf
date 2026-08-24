data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  count = var.ami_id == "" ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  selected_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.amazon_linux_2023_ami[0].value

  common_tags = merge(
    var.tags,
    {
      Module = "compute"
    }
  )
}

resource "aws_launch_template" "app" {
  name_prefix = "${var.name}-app-"

  image_id = local.selected_ami_id

  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  vpc_security_group_ids = [
    var.app_security_group_id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.name}-app"
        Tier = "application"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.name}-app-root-volume"
        Tier = "application"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-app-launch-template"
    }
  )
}
resource "aws_lb" "app" {
  #checkov:skip=CKV2_AWS_76:AWSManagedRulesKnownBadInputsRuleSet is enabled on the associated WAFv2 Web ACL and provides Log4j/Log4JRCE protection.
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.alb_security_group_id
  ]

  subnets = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true

  enable_http2 = true

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []

    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      enabled = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb"
      Tier = "edge"
    }
  )
}

resource "aws_lb_target_group" "app" {
  name = "${var.name}-app-tg"

  port     = var.application_port
  protocol = "HTTP"

  target_type = "instance"

  vpc_id = var.vpc_id

  health_check {
    enabled = true

    protocol = "HTTP"
    path     = var.health_check_path

    port = "traffic-port"

    healthy_threshold   = 2
    unhealthy_threshold = 3

    timeout  = 5
    interval = 30

    matcher = "200-399"
  }

  deregistration_delay = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-app-target-group"
      Tier = "application"
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-http-listener"
    }
  )
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn

  port            = 443
  protocol        = "HTTPS"
  certificate_arn = var.certificate_arn

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app.arn
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-https-listener"
    }
  )
}

resource "aws_autoscaling_group" "app" {
  name = "${var.name}-app-asg"

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  vpc_zone_identifier = var.private_subnet_ids

  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = lookup(local.common_tags, "Project", var.name)
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = lookup(local.common_tags, "Environment", "unknown")
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "application"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name = "${var.name}-cpu-target-tracking"

  autoscaling_group_name = aws_autoscaling_group.app.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_value

    disable_scale_in = false
  }
}

