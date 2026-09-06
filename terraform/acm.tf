# Requests a TLS certificate from AWS Certificate Manager, covering both
# hopecc.org.uk (the primary/canonical domain) and www.hopecc.org.uk (which
# currently redirects to the apex — but still needs a valid cert on that
# hostname before the redirect can happen over HTTPS).
#
# `provider = aws.us_east_1` sends this request specifically to the aliased
# us-east-1 provider from providers.tf — a hard CloudFront requirement, not
# a choice, regardless of where the rest of your infrastructure lives.
#
# validation_method = "DNS" means AWS proves you own the domain by asking
# you to create a specific CNAME record. That's more reliable and more
# automatable than the email-based alternative, but since your DNS is
# managed manually in NetNerd rather than through Route53, YOU'LL be the one
# adding that record by hand (Terraform can't do it directly), based on the
# output this file produces.
resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  # This tells Terraform: if this certificate is ever replaced (e.g. you add
  # another domain to it later), build the new one successfully BEFORE
  # tearing down the old one. Without this, CloudFront could briefly be left
  # with no valid certificate at all during a change — not a concern today,
  # but a good default for anything CloudFront depends on.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Primary site certificate"
  }
}

# This resource does nothing to AWS itself — it simply waits and repeatedly
# checks whether AWS can see the DNS records you added in NetNerd, then
# confirms once the certificate's status flips from PENDING_VALIDATION to
# ISSUED. Terraform will show "still creating..." while this happens, which
# is normal — it's polling, not stuck. If it takes more than a few minutes,
# that's usually just DNS propagation catching up, not a problem with the
# records themselves.
resource "aws_acm_certificate_validation" "site" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.site.arn

  validation_record_fqdns = [
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.resource_record_name
  ]
}
