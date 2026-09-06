# --- Default provider ---
# Used for most resources: S3, IAM users/policies, the billing alarm, etc.
# eu-west-2 (London) is the sensible home region given the church and its
# current hosting are both UK-based.
provider "aws" {
  region  = "eu-west-2"
  profile = "default" # matches the profile you set up with `aws configure`

  # default_tags apply automatically to every resource this provider creates.
  # Handy later for cost tracking in the AWS Billing console, and for telling
  # Terraform-managed resources apart from anything created by hand.
  default_tags {
    tags = {
      Project     = "hopecc-website"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

# --- us-east-1 provider (aliased) ---
# AWS hard-requires ACM certificates used with CloudFront to be requested in
# us-east-1, no matter what region everything else lives in. This isn't a
# preference or best practice — CloudFront literally will not accept a
# certificate issued anywhere else. This second provider block exists purely
# so the ACM certificate resource (added in a later step) can point at it
# explicitly with `provider = aws.us_east_1`, while everything else keeps
# using the default eu-west-2 provider above.
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "default"

  default_tags {
    tags = {
      Project     = "hopecc-website"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}
