variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Key/value pairs for default tags to add to resources"
  type        = map(string)
  default = {
    ManagedBy = "OpenTofu"
  }
}
