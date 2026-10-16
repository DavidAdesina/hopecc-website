# Outputs are Terraform's way of printing computed values back to you after
# apply, rather than making you dig for them in the AWS console. This one
# prints the CNAME record(s) AWS uses to prove you own hopecc.org.uk and
# www.hopecc.org.uk — one record per domain, so expect two entries here.
# Since the move to Route 53, route53.tf creates these records
# automatically; this output is now just for reference.
output "acm_validation_records" {
  description = "ACM certificate DNS validation records (created automatically by route53.tf)"
  value = [
    for dvo in aws_acm_certificate.site.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

# CloudFront's own default domain (something like d111111abcdef8.cloudfront.net).
# Used to verify the site BEFORE the live hopecc.org.uk DNS was cut over to
# it (13 Sept 2026). Still handy for checking CloudFront directly. Note:
# the CMS login deliberately refuses this address — use hopecc.org.uk/admin.
output "cloudfront_domain_name" {
  description = "CloudFront's default domain (the site is also served here, alongside hopecc.org.uk)"
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

output "github_actions_deploy_role_arn" {
  description = "Role ARN for the GitHub Actions workflow's role-to-assume input (OIDC deploy auth)"
  value       = aws_iam_role.github_actions_deploy.arn
}

# The four nameservers Route 53 assigns this zone. These replaced
# ns1.netnerd.com / ns2.netnerd.com at the domain's registrar (Fasthosts
# Internet Ltd -- confirmed via Nominet's RDAP lookup, not NetNerd itself)
# at the DNS cutover on 13 Sept 2026, and are what Fasthosts should still
# show. To roll back DNS, set ns1/ns2.netnerd.com there instead.
output "route53_nameservers" {
  description = "Route 53 nameservers -- set at Fasthosts (the registrar) since 13 Sept 2026"
  value       = aws_route53_zone.site.name_servers
}