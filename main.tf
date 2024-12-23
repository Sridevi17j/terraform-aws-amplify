# VPC and Network Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "${var.environment}-${timestamp()}"  # Common mistake: triggers recreation
  }
}

# Security Group 
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Application security group"
  vpc_id      = aws_vpc.main.id

  # Overly permissive ingress - common under pressure
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier        = "app-db"
  engine           = "postgres"
  engine_version   = "13"  # Not explicitly versioned
  instance_class   = "db.t3.micro"
  allocated_storage = 20

  username = "admin"
  password = var.db_password  # Not marked as sensitive

  
  backup_retention_period = 0
  skip_final_snapshot    = true  # Risky for production

  # Performance insights
  performance_insights_enabled = true
  # Missing performance_insights_kms_key_id
  
  publicly_accessible = true  # Often enabled for testing
}

# S3 Bucket
resource "aws_s3_bucket" "app_data" {
  bucket = "app-data-${var.environment}"
  
  # Missing versioning
  # Missing encryption
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  
  block_public_acls       = false  # Often disabled for "temporary" public access
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami           = "ami-12345678"  # Hardcoded AMI
  instance_type = "t3.xlarge"     # Oversized for testing

  root_block_device {
    encrypted = false  # Often overlooked
  }

  # Missing IMDSv2 requirement
  # metadata_options {
  #   http_tokens = "required"
  # }

  user_data = <<-EOF
              #!/bin/bash
              export DB_PASSWORD=${var.db_password}  # Exposing sensitive data in user data
              export AWS_ACCESS_KEY_ID=${var.aws_access_key}
              export AWS_SECRET_ACCESS_KEY=${var.aws_secret_key}
              EOF

  tags = {
    Environment = var.environment
    # Missing crucial tags like Owner, CostCenter
  }
}

# CloudWatch Log Group 
resource "aws_cloudwatch_log_group" "app_logs" {
  name = "/app/logs"
  # Missing retention_in_days
  # Missing KMS encryption
}

# IAM Role
resource "aws_iam_role" "app_role" {
  name = "app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_policy" {
  name = "app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "*"  # Overly permissive for quick testing
        ]
        Resource = "*"
      }
    ]
  })
}