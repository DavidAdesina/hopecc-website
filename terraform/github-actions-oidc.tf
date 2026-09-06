# --------------------------------------------------------------------
# Lets GitHub Actions authenticate to AWS with short-lived, per-run
# credentials instead of a long-lived IAM access key stored as a repo
# secret. GitHub issues a signed OIDC token on every workflow run; AWS
# verifies it came from GitHub and, if the token's claims match this
# role's trust policy, hands back temporary credentials scoped to
# exactly the permissions below -- nothing persists between runs.
# --------------------------------------------------------------------

# Registers GitHub's OIDC issuer as a trusted identity provider in this
# AWS account. `sts.amazonaws.com` in client_id_list is the fixed
# audience value GitHub's own OIDC tokens are issued for when calling
# AWS -- not something specific to this project.
#
# NOTE ON thumbprint_list: deliberately omitted. AWS validates GitHub's
# OIDC certificate against its own library of trusted root CAs, not a
# manually-configured thumbprint (true since mid-2023; confirmed
# against current AWS provider docs). thumbprint_list is Optional in
# the AWS provider specifically for this reason -- there's no stale
# value here that would ever need rotating.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Trust policy: only a workflow run in THIS repo, on THIS branch, can
# assume this role. `sub` is GitHub's own claim identifying exactly
# which repo/ref issued the token -- scoping on it (rather than just
# trusting "any token from GitHub") is what makes this safe to attach
# real permissions to.
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Locked to pushes on main specifically -- matches the direct-push
    # workflow already used for both code and Decap CMS content. A PR
    # build or a push to any other branch presents a different `sub`
    # value and simply fails to assume this role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Exactly what the deploy workflow needs: sync the built site to the
# one S3 bucket, and invalidate the one CloudFront distribution.
# Nothing else -- not "any S3 bucket", not "any CloudFront
# distribution".
data "aws_iam_policy_document" "github_actions_deploy_permissions" {
  statement {
    sid    = "SyncBuiltSiteToS3"
    effect = "Allow"
    actions = [
      "s3:ListBucket",        # aws s3 sync lists existing objects to diff against
      "s3:GetBucketLocation", # avoids a region-resolution failure some CLI paths hit without it
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject", # needed for --delete, to remove files no longer in the build
    ]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*",
    ]
  }

  statement {
    sid       = "InvalidateCloudFrontCache"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.project_name}-github-actions-deploy"
  description = "Allows the GitHub Actions deploy workflow to sync the built site to S3 and invalidate CloudFront -- nothing else"
  policy      = data.aws_iam_policy_document.github_actions_deploy_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}
