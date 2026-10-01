variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "serverless-file-api"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}