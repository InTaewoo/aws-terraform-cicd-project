locals {
  availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
