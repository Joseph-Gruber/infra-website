data "aws_caller_identity" "account" {}

data "aws_cloudfront_cache_policy" "cache_policy" {
  name = "Managed-CachingOptimized"
}

data "aws_iam_policy_document" "s3_bucket" {
  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${module.s3_bucket.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

data "terraform_remote_state" "dns" {
  backend = "s3"

  config = {
    bucket = "tf-state-20251003143634666300000001"
    key    = "dns/terraform.tfstate"
    region = "us-east-1"
  }
}
