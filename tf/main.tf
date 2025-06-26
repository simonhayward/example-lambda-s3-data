
terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      env   = var.env
    }
  }
}

resource "aws_s3_bucket" "data" {
  bucket = var.data_bucket_name
  force_destroy = true
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "ObjectLambdaDev" {
  name               = "ObjectLambdaDev"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "AmazonS3ObjectLambdaExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonS3ObjectLambdaExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ObjectLambdaDev" {
  policy_arn = data.aws_iam_policy.AmazonS3ObjectLambdaExecutionRolePolicy.arn
  role       = aws_iam_role.ObjectLambdaDev.id
}

locals {
  lambda_dir =  "../lambda"
  binary_dir = "../lambda/bin/"
  binary_path  = "bin/bootstrap"
  src          = "../lambda/main.go"
  archive_path = "../lambda/objectlambda.zip"
}

resource "null_resource" "objectlambda_bin" {
  triggers = {
    src = md5(file(local.src))
  }
  provisioner "local-exec" {
    command = "CGO_ENABLED=1 go build -C ${local.lambda_dir} -o ${local.binary_path} main.go"
  }
}

data "archive_file" "objectlambda_zip" {
  depends_on  = [null_resource.objectlambda_bin]
  type        = "zip"
  source_dir = local.binary_dir
  output_path = local.archive_path
}

resource "aws_lambda_function" "ObjectLambdaDev" {
  function_name    = "ObjectLambdaDev"
  role             = aws_iam_role.ObjectLambdaDev.arn
  handler          = "main"
  filename         = data.archive_file.objectlambda_zip.output_path
  architectures    = ["arm64"]
  runtime          = "provided.al2023"  # OS-only Runtime
  memory_size      = var.lambda_ram
  timeout          = 60
  source_code_hash = data.archive_file.objectlambda_zip.output_base64sha256
  
  ephemeral_storage {
    size = var.lambda_storage
  }

  environment {
    variables = {
      HOME = "/tmp"
    }
  }
}

resource "aws_cloudwatch_log_group" "ObjectLambdaDev" {
  name              = "/aws/lambda/${aws_lambda_function.ObjectLambdaDev.function_name}"
  retention_in_days = var.logs_retention_in_days
}

resource "aws_s3_access_point" "LambdaObjectAccessPoint" {
  bucket = aws_s3_bucket.data.id
  name   = "objectlambdadev"
}

resource "aws_s3control_object_lambda_access_point" "ObjectLambdaDev" {
  name = "objectlambdadev"

  configuration {
    supporting_access_point = aws_s3_access_point.LambdaObjectAccessPoint.arn

    transformation_configuration {
      actions = ["GetObject"]

      content_transformation {
        aws_lambda {
          function_arn = aws_lambda_function.ObjectLambdaDev.arn
        }
      }
    }
  }

}