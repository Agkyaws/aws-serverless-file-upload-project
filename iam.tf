# Assume role policy for Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Policy for pre-sign Lambda
data "aws_iam_policy_document" "lambda_presign_policy" {
  statement {
    sid    = "AllowS3GetPutOnRawBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.raw_uploads.arn}/*"
    ]
  }

  statement {
    sid    = "AllowLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

# Policy for processor Lambda
data "aws_iam_policy_document" "lambda_processor_policy" {
  statement {
    sid    = "AllowReadFromRawBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.raw_uploads.arn}/*"
    ]
  }

  statement {
    sid    = "AllowWriteToProcessedBucket"
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.processed.arn}/*"
    ]
  }

  statement {
    sid    = "AllowDynamoDBCrud"
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem"
    ]

    resources = [
      aws_dynamodb_table.file_metadata.arn
    ]
  }

  statement {
    sid    = "AllowLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

# IAM role for Lambda (pre-signed URL)
resource "aws_iam_role" "lambda_presign_role" {
  name = "${var.project_name}-lambda-presign-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_presign_policy" {
  name        = "${var.project_name}-lambda-presign-policy"
  description = "Allow Lambda to create pre-signed URLs and write logs"

  policy = data.aws_iam_policy_document.lambda_presign_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_presign_attach" {
  role       = aws_iam_role.lambda_presign_role.name
  policy_arn = aws_iam_policy.lambda_presign_policy.arn
}

# IAM role for Lambda (processor)
resource "aws_iam_role" "lambda_processor_role" {
  name = "${var.project_name}-lambda-processor-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_processor_policy" {
  name        = "${var.project_name}-lambda-processor-policy"
  description = "Allow Lambda to read from raw bucket, write to processed bucket, update DynamoDB, and write logs"

  policy = data.aws_iam_policy_document.lambda_processor_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_processor_attach" {
  role       = aws_iam_role.lambda_processor_role.name
  policy_arn = aws_iam_policy.lambda_processor_policy.arn
}