# Outputs are Terraform's way of printing computed values back to you after
# apply, rather than making you dig for them in the AWS console. This one
# prints the exact CNAME record(s) AWS needs to see in NetNerd's DNS zone to
# prove you own hopecc.org.uk and www.hopecc.org.uk — one record per domain,
# so expect to see two entries here.
output "acm_validation_records" {
  description = "DNS records to add in NetNerd to validate the ACM certificate"
  value = [
    for dvo in aws_acm_certificate.site.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

# CloudFront's own default domain (something like d111111abcdef8.cloudfront.net).
# This is what lets you verify the site actually works BEFORE cutting the
# live hopecc.org.uk DNS over to it — per the safety-net plan, we test
# against this URL first, and only point the real domain at CloudFront once
# it's confirmed working.
output "cloudfront_domain_name" {
  description = "CloudFront's default domain — use this to verify the site before DNS cutover"
  value       = aws_cloudfront_distribution.site.domain_name
}

# IAM users (unlike the root account) can't sign in through AWS's main
# sign-in page — they need this account-specific URL instead. Worth having
# on hand for whenever you set up your brothers' console passwords and want
# to send them their login link.
output "iam_user_signin_url" {
  description = "Sign-in URL for IAM users in this account (not the root account sign-in page)"
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "contact_form_api_url" {
  description = "Direct URL to test the contact form endpoint, before CloudFront routing exists"
  value       = "${aws_apigatewayv2_api.contact_form.api_endpoint}/api/contact"
}

output "decap_oauth_base_url" {
  description = "base_url value for config.yml's backend section (Decap CMS OAuth) -- should read https://b5emulwcc6.execute-api.eu-west-2.amazonaws.com"
  value       = aws_apigatewayv2_api.contact_form.api_endpoint
}