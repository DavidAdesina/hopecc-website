# --------------------------------------------------------------------
# IAM: the identity the Lambda function runs as, and what it's allowed
# to do. See ses.tf for the SES identity this policy is scoped to.
# --------------------------------------------------------------------

# The Lambda function (below) needs its own identity in AWS -- something
# it can "be", so IAM knows what it's allowed to do. This is that
# identity: a role only Lambda itself is allowed to use (the trust
# policy below), paired with exactly two permissions -- nothing else.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "contact_form_lambda" {
  name               = "${var.project_name}-contact-form-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permission 1: send email, but ONLY using the one verified identity from
# ses.tf -- not "any SES identity in the account". There's only one right
# now, but referencing it by ARN (rather than "*") keeps this narrow even
# if that ever changes.
data "aws_iam_policy_document" "lambda_ses_send" {
  statement {
    sid       = "AllowSendFromContactFormIdentityOnly"
    effect    = "Allow"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [aws_ses_email_identity.contact_form.arn]
  }
}

resource "aws_iam_policy" "lambda_ses_send" {
  name        = "${var.project_name}-contact-form-ses-send"
  description = "Allows the contact form Lambda to send email, scoped to the one verified identity"
  policy      = data.aws_iam_policy_document.lambda_ses_send.json
}

resource "aws_iam_role_policy_attachment" "lambda_ses_send" {
  role       = aws_iam_role.contact_form_lambda.name
  policy_arn = aws_iam_policy.lambda_ses_send.arn
}

# Permission 2: write its own logs to CloudWatch. This is AWS's own
# standard managed policy for exactly this purpose -- every Lambda needs
# it to log anything at all, and there's no narrower official alternative
# since the log group doesn't exist yet at the point IAM needs to allow
# creating it.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.contact_form_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------------------------------------------------
# THE FUNCTION ITSELF
# --------------------------------------------------------------------

# Explicitly managing the log group (rather than letting Lambda create
# one automatically on first invocation) means we control retention --
# without this, AWS defaults to keeping logs forever. 30 days is plenty
# for debugging a contact form; nothing here needs a permanent record.
resource "aws_cloudwatch_log_group" "contact_form_lambda" {
  name              = "/aws/lambda/${var.project_name}-contact-form"
  retention_in_days = 30
}

# Zips up the function's source code (index.mjs, package.json, and
# node_modules) into the deployment package Lambda actually runs.
#
# MANUAL STEP REQUIRED: before this will zip correctly, run `npm install`
# inside terraform/lambda/contact-form/ once, so that folder actually
# contains a node_modules directory for this to pick up.
data "archive_file" "contact_form_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/contact-form"
  output_path = "${path.module}/build/contact-form-lambda.zip"
}

resource "aws_lambda_function" "contact_form" {
  function_name    = "${var.project_name}-contact-form"
  role             = aws_iam_role.contact_form_lambda.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.contact_form_lambda.output_path
  source_code_hash = data.archive_file.contact_form_lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      CONTACT_FORM_EMAIL = var.contact_form_email
    }
  }

  depends_on = [aws_cloudwatch_log_group.contact_form_lambda]
}
