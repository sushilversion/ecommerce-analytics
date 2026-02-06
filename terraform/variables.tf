variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (update for your region)"
  type        = string
  # Ubuntu 22.04 LTS AMIs by region:
  # us-east-1: ami-0866a3c8686eaeeba
  # us-west-2: ami-05134c8ef96964280
  # ap-south-1: ami-0dee22c13ea7a9a67
  # eu-west-1: ami-0932440befd74cdba
  default     = "ami-0866a3c8686eaeeba"
}

variable "key_pair_name" {
  description = "Name of your existing EC2 key pair"
  type        = string
  # You must create this key pair in AWS Console first
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g., 203.0.113.0/32)"
  type        = string
  # Get your IP: curl ifconfig.me
}
