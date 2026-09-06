# This is AWS's own documented pattern for enforcing MFA on an IAM user —
# IAM has no simple "require MFA" toggle, so this is the real mechanism:
# a policy that denies EVERYTHING except the handful of actions needed to
# set up MFA in the first place, and only while MFA isn't yet present on
# the session. The moment they've signed in WITH MFA, this policy simply
# has nothing left to deny, and their other policies (ReadOnlyAccess +
# the sandbox policy) take over normally.
data "aws_iam_policy_document" "require_mfa" {
  # Needed just to see that a virtual MFA device exists/can be listed —
  # AWS requires this be its own statement with Resource "*", it doesn't
  # support scoping this specific permission to "just my own device".
  statement {
    sid       = "AllowListActions"
    effect    = "Allow"
    actions   = ["iam:ListUsers", "iam:ListVirtualMFADevices"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowUserToCreateVirtualMFADevice"
    effect    = "Allow"
    actions   = ["iam:CreateVirtualMFADevice"]
    resources = ["arn:aws:iam::*:mfa/*"]
  }

  statement {
    sid    = "AllowUserToManageTheirOwnMFA"
    effect = "Allow"
    actions = [
      "iam:EnableMFADevice",
      "iam:GetMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice",
    ]
    # $${aws:username} (with the doubled $$) is deliberate — it tells
    # Terraform "output a literal ${aws:username}", which is AWS IAM's own
    # policy variable syntax, resolved by AWS at request time to whichever
    # user is actually making the call. Without the extra $, Terraform
    # would try to interpret this itself and fail.
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }

  # Deliberately requires MFA to already be present even to REMOVE MFA —
  # otherwise, someone who got hold of a valid but non-MFA session could
  # simply turn MFA off for themselves.
  statement {
    sid       = "AllowUserToDeactivateTheirOwnMFAOnlyWhenUsingMFA"
    effect    = "Allow"
    actions   = ["iam:DeactivateMFADevice"]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  # The actual enforcement: denies every action, on every AWS resource,
  # EXCEPT the small MFA-setup allowlist above — but only when MFA isn't
  # present on the current session. "BoolIfExists" (rather than plain
  # "Bool") matters: it makes sure this still catches a brand-new session
  # where the MFA context key doesn't exist yet at all, not just one where
  # it's explicitly set to false.
  statement {
    sid    = "BlockMostAccessUnlessSignedInWithMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ListUsers",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "require_mfa" {
  name        = "${var.project_name}-require-mfa"
  description = "Blocks all actions except MFA setup until the user has signed in with MFA"
  policy      = data.aws_iam_policy_document.require_mfa.json
}

# The two brothers' IAM identities. `for_each` over the variable means
# adding a third person later is just adding a name to variables.tf and
# re-applying — no new resource blocks needed.
resource "aws_iam_user" "brother" {
  for_each = toset(var.brother_usernames)
  name     = each.value

  tags = {
    Name = "Family sandbox/viewer account"
  }
}

# AWS's own managed policy: broad read (list/describe/get) permissions
# across virtually every AWS service, with zero ability to create, modify,
# or delete anything. This is what lets them see the whole picture — S3,
# CloudFront, even billing — without being able to change any of it.
resource "aws_iam_user_policy_attachment" "brother_readonly" {
  for_each   = aws_iam_user.brother
  user       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# The write/delete permission, scoped to the sandbox bucket only (defined
# in sandbox.tf).
resource "aws_iam_user_policy_attachment" "brother_sandbox" {
  for_each   = aws_iam_user.brother
  user       = each.value.name
  policy_arn = aws_iam_policy.sandbox_access.arn
}

resource "aws_iam_user_policy_attachment" "brother_require_mfa" {
  for_each   = aws_iam_user.brother
  user       = each.value.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
