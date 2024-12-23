variable "environment" {
  type = string
  description = "Environment (dev/staging/prod)"
}

variable "db_password" {
  type = string
  description = "RDS database password"
  sensitive = true
}

variable "aws_access_key" {
  type = string
  description = "AWS access key"
  sensitive = true
}

variable "aws_secret_key" {
  type = string
  description = "AWS secret key"
  sensitive = true
}