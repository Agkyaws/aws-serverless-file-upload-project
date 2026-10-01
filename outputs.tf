output "api_endpoint" {
  description = "HTTP API endpoint URL"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "raw_bucket_name" {
  description = "Raw uploads S3 bucket name"
  value       = aws_s3_bucket.raw_uploads.bucket
}

output "processed_bucket_name" {
  description = "Processed S3 bucket name"
  value       = aws_s3_bucket.processed.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for file metadata"
  value       = aws_dynamodb_table.file_metadata.name
}