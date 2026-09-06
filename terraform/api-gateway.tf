# The HTTP API itself -- API Gateway's simpler, cheaper option compared
# to a full REST API. All this needs is one route, so REST API's extra
# features (usage plans, request validators, etc.) would just be unused
# complexity here.
resource "aws_apigatewayv2_api" "contact_form" {
  name          = "${var.project_name}-contact-form"
  protocol_type = "HTTP"
}

# Wires the API to the Lambda function. AWS_PROXY means API Gateway hands
# the whole request through to the Lambda as-is (headers, body, method,
# etc.) rather than requiring a mapping template -- the Lambda's own code
# does all the parsing.
resource "aws_apigatewayv2_integration" "contact_form_lambda" {
  api_id                 = aws_apigatewayv2_api.contact_form.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact_form.invoke_arn
  payload_format_version = "2.0"
}

# The actual route. This path is deliberately "/api/contact", matching
# exactly what contact.astro's fetch() call already requests -- once
# CloudFront is updated (next step) to forward /api/* straight through
# to this API unchanged, the paths line up with no rewriting needed
# anywhere.
resource "aws_apigatewayv2_route" "contact_form" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "POST /api/contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_form_lambda.id}"
}

# $default is HTTP API's special stage name: auto-deploys every change
# immediately, and -- importantly for the CloudFront plan -- serves at
# the root of the API's URL with no /prod or /dev prefix to account for.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.contact_form.id
  name        = "$default"
  auto_deploy = true
}

# By default, nothing is allowed to invoke the Lambda -- not even the API
# Gateway route pointing at it. This is the resource-based permission
# that actually grants that, scoped specifically to requests coming
# through THIS API (not "any API Gateway anywhere").
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_form.execution_arn}/*/*"
}
