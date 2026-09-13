# --- DNS hosting migration: NetNerd -> Route 53 ---
#
# NetNerd's Zone Editor only offers A / AAAA / CAA / CNAME / HTTPS / SVCB /
# MX / SRV / TXT record types (confirmed by inspecting its own "Add Record"
# dropdown on 2026-09-13) -- no ALIAS or ANAME. Since the zone APEX
# (hopecc.org.uk, with no subdomain) can never be a plain CNAME per the DNS
# spec, and CloudFront is only reachable by hostname
# (d3jmbi4qqbxnbe.cloudfront.net), NetNerd has no way to point the bare
# domain at CloudFront at all. Route 53's own ALIAS record type exists
# specifically to solve this for AWS resources like CloudFront, so DNS
# hosting for hopecc.org.uk is moving here.
#
# IMPORTANT: applying this file only CREATES the new zone and its records
# in Route 53 -- it does nothing to live traffic. hopecc.org.uk keeps
# resolving via NetNerd (ns1/ns2.netnerd.com) until the nameservers are
# changed at the domain's REGISTRAR, which is Fasthosts Internet Ltd, not
# NetNerd (confirmed via Nominet's RDAP lookup on 2026-09-13 -- NetNerd
# hosts DNS/hosting for this domain but isn't who it's registered with).
# That NS change is a separate, later step, done by hand at Fasthosts using
# the four nameservers this file's `route53_nameservers` output prints.
# Perfectly safe to apply well ahead of that -- it costs about $0.50/month
# and affects nothing until the NS records actually move.

resource "aws_route53_zone" "site" {
  name    = var.domain_name
  comment = "Hope Community Church -- replacing NetNerd DNS ahead of the hopecc.org.uk cutover"
}

# --- Website: apex + www -> CloudFront ---
#
# A Route 53 ALIAS record (the `alias {}` block below -- not a real DNS
# record type of its own) is what makes pointing the bare apex at
# CloudFront possible: it's resolved server-side by Route 53 itself, so
# it's legal at the zone apex where a real CNAME wouldn't be. Both A and
# AAAA are created for both names because the distribution has
# is_ipv6_enabled = true (cloudfront.tf) -- an IPv6-only visitor needs the
# AAAA to resolve.
#
# www no longer being a CNAME to the apex (as it was on NetNerd) is
# deliberate: pointing it straight at CloudFront, the same way as the
# apex, avoids an extra DNS hop and stops it silently inheriting whatever
# the apex happens to do.

resource "aws_route53_record" "apex_a" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_aaaa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_a" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_aaaa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "www.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- Webmail / mail client access ---
#
# On NetNerd, mail.hopecc.org.uk was a CNAME to the bare apex -- which only
# worked because the apex happened to point at the same cPanel box
# (185.229.21.118) that mail lives on. The moment the apex points at
# CloudFront instead, that CNAME would silently start resolving
# mail.hopecc.org.uk to CloudFront too, breaking webmail login and any
# email client configured with mail.hopecc.org.uk as its server. Pointing
# it directly at the cPanel server's own IP keeps it working regardless of
# what the apex does.

resource "aws_route53_record" "mail" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "mail.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = ["185.229.21.118"]
}

# --- Mail delivery (MX + SPF) ---
#
# All three MX hosts are SpamExperts' inbound filtering gateway -- entirely
# external to hopecc.org.uk, so replicated unchanged from NetNerd. Nothing
# about the website cutover touches mail delivery: it never looks at the
# apex A/ALIAS record above.

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = [
    "10 mx.spamexperts.com",
    "20 fallbackmx.spamexperts.eu",
    "30 lastmx.spamexperts.net",
  ]
}

# SPF, replicated unchanged. Note the "+a" mechanism will start referring
# to whatever the apex resolves to -- CloudFront, after cutover -- instead
# of the real mail-sending server. That's harmless here only because
# 185.229.21.118 is ALSO listed explicitly via "ip4:", so outbound mail
# keeps passing SPF regardless of what "+a" ends up meaning. Worth tidying
# "+a" out of this record eventually since it becomes misleading, not
# broken -- a wind-down item, not urgent.

resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 ip4:185.229.21.118 +a +mx ip4:185.229.22.199 ~all"]
}

# --- DKIM ---
#
# Confirmed via cPanel's own "Edit" view (not the list view, which wraps
# the value in a way that looks like it could be one string with a space
# in it -- it isn't). This is genuinely two separate quoted TXT strings:
# the DNS spec caps any single quoted string in a TXT record at 255 bytes,
# and the first of these two is exactly 255 characters long -- confirming
# this split is the protocol's own length limit doing its job, not an
# arbitrary line-wrap. Route 53 (and DNS generally) concatenates the two
# quoted strings directly, with no space between them, when a resolver
# reads the record -- represented below as one record value containing
# two quoted segments, which is the correct way to give Terraform/Route 53
# a TXT value longer than 255 characters.

resource "aws_route53_record" "dkim" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "default._domainkey.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  # NOTE: no leading/trailing quote here on purpose -- the AWS provider
  # adds one wrapping pair of quotes to every TXT records[] element itself
  # before sending it to Route 53. Adding our own outer quotes on top (the
  # first attempt) produced a doubled '""..."..."""' that Route 53 rejected
  # with InvalidCharacterString. The embedded \" \" in the middle is still
  # needed -- that's the genuine boundary between the two DKIM chunks --
  # just not one at each end.
  records = [
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyrSJG/lXaiR5mbAPdMIwnMPObjI4PT+xA27YE08byxWVgi9bPXBCEMX0dBpibuLKbW0MHHdF/8uHhFpwiXhUL48Bmm63Bm+WpyQE+FRQUpYHFmiAcpMfj4PcLyRxU7RTK54YGFvwqXkIFiUkeTwGqbDe0DX2oN/8gX5kh9lnpcEgo6mtSNhRyFdSZlZYfUVwd\" \"yYngpS8KPULEJw9K61yQIro9SM/CGYMBLcZWLxNfGzXE4ln8FxBYxWVE09UdFanzTlelNmEor2ETGVRoIVnmR028pDzkHqmVszAxf6TmhBL6dc2DhZddsHcosxfwEtn9nJInyzjuYdFwGf+EBfW3wIDAQAB;"
  ]
}

# --- ACM certificate validation ---
#
# These are the same CNAME records you'd otherwise have to keep adding by
# hand in NetNerd (see the comment in acm.tf) -- generated directly from
# the certificate resource itself rather than retyped from what's visible
# in NetNerd's zone, so there's no risk of a transcription error. AWS
# checks these periodically to auto-renew the certificate; keeping them in
# the new zone is what lets that keep happening after cutover.

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

# --- Deliberately not replicated ---
#
# These NetNerd records exist only to support the OLD cPanel/Sitejet
# hosting directly, and have no purpose once public DNS stops pointing
# there:
#   - localhost.hopecc.org.uk (A, 127.0.0.1) -- cPanel boilerplate
#   - _cpanel-dcv-test-record.hopecc.org.uk (TXT) -- a one-off cPanel
#     domain-control-validation artifact
#   - _acme-challenge.hopecc.org.uk / .www / .cpanel / .cpcalendars (TXT)
#     -- cPanel AutoSSL's Let's Encrypt renewal tokens for the OLD site's
#     own certificates
#
# ftp.hopecc.org.uk (A, 185.229.21.118) was also left out -- add it back
# if FTP access to the old cPanel account is still needed during the
# post-cutover observation window (see the handoff's wind-down list).
