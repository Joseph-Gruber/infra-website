locals {
  domain_name = data.terraform_remote_state.dns.outputs.domain_name
  zone_id     = data.terraform_remote_state.dns.outputs.zone_id
}

# =================================================================================
## S3 Bucket for Website Content
## =================================================================================
module "s3_bucket" { #trivy:ignore:AVD-AWS-0090 # Versioning not required
  source = "git::ssh://git@github.com/blue-marble-consulting/aws-s3-bucket.git?ref=2.3.0"

  bucket_prefix      = "${local.domain_name}-"
  versioning_enabled = false
}

resource "aws_s3_bucket_policy" "this" {
  bucket = module.s3_bucket.bucket_id
  policy = data.aws_iam_policy_document.s3_bucket.json
}

resource "aws_ssm_parameter" "s3" {
  name  = "/website/bucket-name"
  type  = "String"
  value = module.s3_bucket.bucket_id
}

## =================================================================================
## Cloudfront Distribution for Website
## =================================================================================
#trivy:ignore:AVD-AWS-0010 # No logging required
#trivy:ignore:AVD-AWS-0011 # No WAF required
resource "aws_cloudfront_distribution" "this" {
  aliases             = [local.domain_name, "www.${local.domain_name}"]
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  wait_for_deployment = false

  origin {
    domain_name              = module.s3_bucket.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = module.s3_bucket.bucket_id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.cache_policy.id
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = module.s3_bucket.bucket_id
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = module.s3_bucket.bucket_domain_name
  description                       = "-"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_ssm_parameter" "cloudfront" {
  name  = "/website/cloudfront-distribution"
  type  = "String"
  value = aws_cloudfront_distribution.this.id
}

## =================================================================================
## Certificate Manager for Cloudfront Distribution
## =================================================================================
resource "aws_acm_certificate" "this" {
  domain_name               = local.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["www.${local.domain_name}"]

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_cert_validation : record.fqdn]
}

resource "aws_route53_record" "acm_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = local.zone_id
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

## =================================================================================
## Route 53 DNS Records
## =================================================================================
resource "aws_route53_record" "root" {
  zone_id = local.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
