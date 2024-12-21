# main.tf

# 1. Resource Dependency Issue
resource "aws_instance" "app_server" {
  count = length(var.server_names)
  ami   = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.main[count.index % 2].id  # Subtle dependency issue

  tags = {
    Name = var.server_names[count.index]
  }

  user_data = templatefile("${path.module}/init.tpl", {
    app_port = var.app_port
  })

  # Looks good but can cause cycling of instances
  lifecycle {
    create_before_destroy = true
  }
}

# Dynamic subnet creation that can cause state file issues
resource "aws_subnet" "main" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Dangerous tag that can cause recreation
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${count.index + 1}-${timestamp()}"
    }
  )
}

# 2. State File Time Bomb
locals {
  # This looks innocent but can corrupt state
  subnet_config = jsondecode(file("${path.module}/network_config.json"))
  
  # Dangerous dynamic block that can grow state file
  instance_config = {
    for k, v in var.instances : k => merge(v, {
      unique_id = base64encode(jsonencode(v))
    })
  }
}

# 3. Count/For-each Gotcha
resource "aws_security_group" "app" {
  for_each = {
    for idx, port in var.app_ports : port => idx
  }

  name        = "app-${each.key}"
  description = "Security group for app port ${each.key}"
  vpc_id      = aws_vpc.main.id

  # This can cause constant updates
  tags = {
    LastUpdated = timestamp()
    Port        = each.key
  }
}

# 4. Variable Default Trap
variable "environment" {
  type    = string
  default = "development"  # Dangerous default
}

variable "instance_type" {
  type    = string
  default = "t3.micro"  # Could be expensive in production
}

# 5. Module Source Versioning Issue
module "network" {
  source = "terraform-aws-modules/vpc/aws"
  # Dangerous version constraint
  version = "~> 3.0"
}

# Database with subtle configuration issues
resource "aws_db_instance" "main" {
  identifier        = "app-${var.environment}"
  allocated_storage = var.environment == "production" ? 100 : 10
  engine           = "postgres"
  engine_version   = "13"  # Not explicitly versioned
  instance_class   = "db.t3.micro"

  # This can cause data loss
  backup_retention_period = var.environment == "production" ? 7 : 0
  skip_final_snapshot    = true

  # Performance issues waiting to happen
  max_connections = 100  # Static value regardless of instance size
}