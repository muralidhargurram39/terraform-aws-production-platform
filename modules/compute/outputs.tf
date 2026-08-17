output "alb_id" {
  description = "Application Load Balancer ID."
  value       = aws_lb.app.id
}

output "alb_arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.app.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID associated with the ALB."
  value       = aws_lb.app.zone_id
}

output "target_group_arn" {
  description = "Application target group ARN."
  value       = aws_lb_target_group.app.arn
}

output "autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Application Launch Template ID."
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Latest Launch Template version."
  value       = aws_launch_template.app.latest_version
}
