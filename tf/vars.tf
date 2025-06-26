variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "env" {
  type        = string
  default     = "objectlambda-dev-lambda-s3-data-example"
}

variable "data_bucket_name" {
  type        = string
  default     = "objectlambda-dev-s3-data"
}

variable "logs_retention_in_days" {
  type        = number
  default     = 1
}

variable "lambda_ram" {
  type        = number
  default     = 256
}

variable "lambda_storage" {
  type        = number
  default     = 512
}