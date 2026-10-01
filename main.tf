terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#-------------------------
# S3 bucket for uploads
#-------------------------
resource "aws_s3_bucket" "raw_uploads" {
  bucket = "${var.project_name}-raw-uploads"

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "raw_uploads" {
  bucket = aws_s3_bucket.raw_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "raw_uploads" {
  bucket = aws_s3_bucket.raw_uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

#-------------------------
# S3 bucket for processed files
#-------------------------
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed"

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = "Enabled"
  }
}

#-------------------------
# DynamoDB table for metadata
#-------------------------
resource "aws_dynamodb_table" "file_metadata" {
  name         = "${var.project_name}-file-metadata"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "fileId"

  attribute {
    name = "fileId"
    type = "S"
  }

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

#-------------------------
# Lambda: Pre-signed URL generator
#-------------------------
resource "aws_lambda_function" "presign_url" {
  function_name = "${var.project_name}-presign-url"
  role          = aws_iam_role.lambda_presign_role.arn
  handler       = "presign.handler"
  runtime       = "python3.11"

  filename         = "lambda_presign.zip"
  source_code_hash = filebase64sha256("lambda_presign.zip")

  timeout = 10

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.raw_uploads.bucket
      URL_EXPIRY  = "900"
    }
  }

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

#-------------------------
# Lambda: S3 processor
#-------------------------
resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor"
  role          = aws_iam_role.lambda_processor_role.arn
  handler       = "processor.handler"
  runtime       = "python3.11"

  filename         = "lambda_processor.zip"
  source_code_hash = filebase64sha256("lambda_processor.zip")

  timeout = 60

  environment {
    variables = {
      RAW_BUCKET       = aws_s3_bucket.raw_uploads.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
      TABLE_NAME       = aws_dynamodb_table.file_metadata.name
    }
  }

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

#-------------------------
# S3 event notification -> Lambda processor
#-------------------------
resource "aws_lambda_permission" "allow_s3_invoke_processor" {
  statement_id  = "AllowS3InvokeProcessor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_uploads.arn
}

resource "aws_s3_bucket_notification" "raw_uploads_notification" {
  bucket = aws_s3_bucket.raw_uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke_processor
  ]
}

#-------------------------
# API Gateway HTTP API
#-------------------------
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "presign_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presign_url.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.presign_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke_presign" {
  statement_id  = "AllowAPIGWInvokePresign"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}