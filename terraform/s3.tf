# Returns the AWS account ID Terraform is currently authenticated as.
# Used below to make the bucket name globally unique (S3 bucket names must be
# unique across ALL of AWS, not just your account) without resorting to a
# random suffix — your account ID is already guaranteed unique, and using it
# means the name is deterministic (same every time you run Terraform, easy
# to recognise in the console), unlike a random string would be.
data "aws_caller_identity" "current" {}

# The S3 bucket that holds the built site — i.e. the contents of `dist/`
# after `astro build`, uploaded by GitHub Actions (that upload step comes in
# Session 4). CloudFront is the ONLY thing that will ever read from this
# bucket; nobody browses to it directly, which is why it's fully private.
resource "aws_s3_bucket" "site" {
  bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Site content bucket"
  }
}

# Belt-and-braces: explicitly blocks every form of public access at the
# bucket level, enforced by Terraform on every apply. New AWS accounts
# already default to blocking public access, but this makes it impossible
# for the bucket to silently drift into being public later (e.g. if someone
# edits an ACL by hand in the console) — Terraform will flag and fix it on
# the next apply. This is the single most common cause of real-world S3
# data leaks, so it's worth being explicit rather than relying on defaults.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypts everything in the bucket at rest using S3's own managed keys
# (SSE-S3 / AES256). This is the simplest encryption option and is entirely
# sufficient here — the bucket only ever holds public website assets (HTML,
# CSS, JS, images), so there's no need for the added complexity/cost of a
# customer-managed KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Grants read-only access to the bucket, but ONLY to CloudFront, and ONLY to
# this specific distribution — not "any CloudFront distribution anywhere"
# and not any other AWS service. The `condition` block is what enforces
# that second, tighter restriction: it checks that the request is coming
# from THIS distribution's exact ARN, so even if someone in this AWS account
# created a completely different CloudFront distribution later, it couldn't
# use this policy to read your site's bucket.
data "aws_iam_policy_document" "site_cloudfront_access" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      "${aws_s3_bucket.site.arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

# Attaches the policy document above to the actual bucket. This is the
# resource that flips the bucket from "unreadable by anyone" to "readable,
# but only by this exact CloudFront distribution" — completing the chain:
# OAC (identifies CloudFront cryptographically) + this policy (authorizes
# that specific distribution) + public access block (still blocks everyone
# else, including direct public requests).
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_cloudfront_access.json
}
