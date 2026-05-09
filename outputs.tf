output "s3_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = module.s3_bucket.bucket_id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}
