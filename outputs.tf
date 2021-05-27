output "name" {
  description = "Name of pipeline"
  value       = aws_codepipeline.this[0].name
}

output "arn" {
  description = "ARN of pipeline"
  value       = aws_codepipeline.this[0].arn
}

output "role_arn" {
  description = "ARN of the IAM role that the pipeline will assume"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "artifact_bucket_id" {
  description = "S3 bucket that will store the pipeline artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 bucket that will store the pipeline artifacts"
  value       = aws_s3_bucket.artifacts.arn
}