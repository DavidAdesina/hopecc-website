# A separate, low-stakes S3 bucket where your brothers can freely create,
# overwrite, and delete objects to get hands-on practice — completely
# isolated from the real site's bucket, which they can only ever READ (via
# ReadOnlyAccess, attached to them in iam.tf).
resource "aws_s3_bucket" "sandbox" {
  bucket = "${var.project_name}-sandbox-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Sandbox bucket for learning/testing"
  }
}

resource "aws_s3_bucket_public_access_block" "sandbox" {
  bucket = aws_s3_bucket.sandbox.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Pure housekeeping: auto-deletes anything left in the sandbox after 30
# days. Nothing important should ever live here permanently, so this just
# stops forgotten test uploads from quietly accumulating over time.
resource "aws_s3_bucket_lifecycle_configuration" "sandbox" {
  bucket = aws_s3_bucket.sandbox.id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# Kept as two separate statements deliberately: s3:ListBucket is a
# bucket-level action (it applies to the bucket ARN itself), while
# Get/Put/DeleteObject are object-level actions (they apply to
# bucket-ARN/*). Combining these into one statement with both resource
# types is a common source of confusing "why can't they see their own
# files" bugs.
data "aws_iam_policy_document" "sandbox_access" {
  statement {
    sid       = "AllowListSandboxBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.sandbox.arn]
  }

  statement {
    sid    = "AllowReadWriteSandboxObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.sandbox.arn}/*"]
  }
}

# This policy grants nothing outside the sandbox bucket — full stop. Once
# combined (in iam.tf) with ReadOnlyAccess, which contains zero write
# actions anywhere in any service, the brothers end up able to write only
# inside this one bucket. That's not the result of anything explicitly
# blocking them elsewhere — it's simply that no policy ever grants them
# write access anywhere else. IAM denies by default; there's nothing here
# that could accidentally "leak" broader access.
resource "aws_iam_policy" "sandbox_access" {
  name        = "${var.project_name}-sandbox-access"
  description = "Read/write access scoped to the sandbox bucket only"
  policy      = data.aws_iam_policy_document.sandbox_access.json
}
