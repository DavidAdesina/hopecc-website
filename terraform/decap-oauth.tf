# --------------------------------------------------------------------
# Decap CMS's /admin login: a small OAuth proxy standing in for the
# service Netlify would normally provide. Same overall shape as the
# contact form (Lambda + a route on the existing API Gateway), but this
# implements a specific popup/postMessage handshake Decap's frontend
# expects -- verified against Decap's actual client-side listener code
# and the most widely-used community reference implementation, since
# Decap's own docs don't publish this protocol directly (they just link
# to community projects).
#
# Flow: Decap opens a popup at GET /auth -> that redirects to GitHub's
# authorize screen -> GitHub redirects back to GET /callback?code=... ->
# the Lambda exchanges the code + client secret for an access token
# server-side -> the callback response is an HTML page whose script
# hands that token to the opener window via postMessage.
# --------------------------------------------------------------------

# Re-uses the same Lambda trust policy already defined in lambda.tf --
# it's generic ("lambda.amazonaws.com can assume this role"), not
# specific to the contact form, so there's no reason to duplicate it.
resource "aws_iam_role" "decap_oauth_lambda" {
  name               = "${var.project_name}-decap-oauth-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Scoped to exactly one parameter -- not "any SSM parameter in the
# account". SecureString parameters are encrypted with a KMS key (the
# no-cost AWS-managed "aws/ssm" key here, since none was specified when
# creating it); ssm:GetParameter alone isn't enough to decrypt one, so
# kms:Decrypt is also needed. Scoping that by "called via the SSM
# service" (rather than a specific key ARN) avoids a fragile dependency
# on a key AWS creates lazily and that this project doesn't manage.
data "aws_iam_policy_document" "lambda_ssm_read_github_secret" {
  statement {
    sid       = "AllowReadGithubClientSecretOnly"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter${var.github_oauth_client_secret_parameter_name}"]
  }

  statement {
    sid       = "AllowDecryptViaSSM"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.eu-west-2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_ssm_read_github_secret" {
  name        = "${var.project_name}-decap-oauth-ssm-read"
  description = "Allows the Decap OAuth Lambda to read and decrypt only the GitHub client secret parameter"
  policy      = data.aws_iam_policy_document.lambda_ssm_read_github_secret.json
}

resource "aws_iam_role_policy_attachment" "decap_oauth_ssm_read" {
  role       = aws_iam_role.decap_oauth_lambda.name
  policy_arn = aws_iam_policy.lambda_ssm_read_github_secret.arn
}

resource "aws_iam_role_policy_attachment" "decap_oauth_basic_execution" {
  role       = aws_iam_role.decap_oauth_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "decap_oauth_lambda" {
  name              = "/aws/lambda/${var.project_name}-decap-oauth"
  retention_in_days = 30
}

# MANUAL STEP REQUIRED: same as the contact form Lambda -- run `npm
# install` inside terraform/lambda/decap-oauth/ once before this will
# zip correctly (needs node_modules/ to exist).
data "archive_file" "decap_oauth_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/decap-oauth"
  output_path = "${path.module}/build/decap-oauth-lambda.zip"
}

resource "aws_lambda_function" "decap_oauth" {
  function_name    = "${var.project_name}-decap-oauth"
  role             = aws_iam_role.decap_oauth_lambda.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.decap_oauth_lambda.output_path
  source_code_hash = data.archive_file.decap_oauth_lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      GITHUB_CLIENT_ID                = var.github_oauth_client_id
      GITHUB_CLIENT_SECRET_PARAM_NAME = var.github_oauth_client_secret_parameter_name
      # Computed from the API's own endpoint rather than hardcoded, so
      # it can never drift from what's actually registered with GitHub.
      REDIRECT_URI                    = "${aws_apigatewayv2_api.contact_form.api_endpoint}/callback"
    }
  }

  depends_on = [aws_cloudwatch_log_group.decap_oauth_lambda]
}

# Same HTTP API as the contact form (b5emulwcc6). The resource is still
# named `contact_form` from Session 2 -- a bit of a misnomer now that it
# serves two unrelated things, but renaming it would make Terraform
# destroy and recreate the whole API (new resource address = new
# resource, per the Session 1 lesson on needless-destroy risk). Left
# as-is deliberately; this comment is the fix.
resource "aws_apigatewayv2_integration" "decap_oauth_lambda" {
  api_id                 = aws_apigatewayv2_api.contact_form.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.decap_oauth.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "decap_auth" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "GET /auth"
  target    = "integrations/${aws_apigatewayv2_integration.decap_oauth_lambda.id}"
}

resource "aws_apigatewayv2_route" "decap_callback" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "GET /callback"
  target    = "integrations/${aws_apigatewayv2_integration.decap_oauth_lambda.id}"
}

# $default stage already has auto_deploy = true (set up for the contact
# form), so these new routes go live with no stage changes needed.

resource "aws_lambda_permission" "apigw_invoke_decap_oauth" {
  statement_id  = "AllowAPIGatewayInvokeDecapOauth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.decap_oauth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_form.execution_arn}/*/*"
}
