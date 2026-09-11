# Origin Access Control (OAC) is AWS's current, recommended way for
# CloudFront to securely read from a private S3 bucket — it replaces the
# older "Origin Access Identity" (OAI) approach. It works by having
# CloudFront sign every request to S3 using AWS's own SigV4 request-signing
# scheme, so S3 can verify the request came from THIS specific distribution
# — not just "some CloudFront distribution somewhere" (which is all the
# older OAI method could prove).
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS ships a set of pre-built, optimized cache policies so you don't have to
# hand-write cache header rules. "Managed-CachingOptimized" is the standard
# pick for a static site like this: it caches aggressively and enables
# compression, while ignoring query strings/cookies/headers a static Astro
# build has no use for anyway.
#
# This looks the policy up by name from your actual AWS account rather than
# pasting in its ID from memory — consistent with the project's "verify
# rather than assume" rule, and it means Terraform will error clearly if the
# name is ever wrong, rather than silently using a bad hardcoded ID.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# The contact form's /api/* path is the opposite case: every response is
# specific to that one submission and must never be cached or reused for a
# different visitor. "Managed-CachingDisabled" is AWS's own policy for
# exactly that -- it sets all TTLs to zero.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Controls which of the VIEWER's original headers get passed through to
# the /api/* origin (separate from caching -- this is about what the
# origin receives, not what gets cached). "AllViewerExceptHostHeader" is
# AWS's own policy built specifically for API Gateway and Lambda Function
# URL origins: they expect to see THEIR OWN domain name in the Host
# header, not the CloudFront distribution's. Forwarding the viewer's real
# Host header (which "AllViewer" would do) causes API Gateway to reject
# the request with a 403 -- this policy is the documented fix.
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host_header" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Hope Community Church website"

  # PriceClass_100 = edge locations in North America and Europe only, the
  # cheapest tier. Since your visitors are overwhelmingly UK-based, the
  # extra edge locations in the pricier tiers (Asia, Africa, South America)
  # wouldn't be serving anyone — no reason to pay for them.
  price_class = "PriceClass_100"

  aliases = [
    var.domain_name,
    "www.${var.domain_name}",
  ]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # The contact form's second origin. Unlike the S3 origin above, this is
  # a "custom origin" -- a plain HTTPS endpoint rather than an S3 bucket --
  # so it uses custom_origin_config instead of origin_access_control_id.
  # trimprefix() strips the "https://" that api_endpoint includes, since
  # CloudFront wants just the bare hostname here.
  origin {
    domain_name = trimprefix(aws_apigatewayv2_api.contact_form.api_endpoint, "https://")
    origin_id   = "api-contact-form"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_clean_urls.arn
    }
  }

  # Anything under /api/ goes to API Gateway instead of S3. This is what
  # makes contact.astro's fetch('/api/contact') actually reach the Lambda
  # once the live domain is pointed at this distribution -- same origin as
  # far as the browser's concerned, so no CORS involved at all.
  ordered_cache_behavior {
    path_pattern              = "/api/*"
    # CloudFront only accepts three exact method combinations for this field
    # -- [GET, HEAD], [GET, HEAD, OPTIONS], or all seven methods together --
    # not arbitrary subsets. Since POST is needed, the seven-method set is
    # the only valid option that includes it. API Gateway's own routing
    # still only accepts POST /api/contact regardless -- this just controls
    # what CloudFront is willing to forward, not what the origin will act on.
    allowed_methods           = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods            = ["GET", "HEAD"]
    target_origin_id          = "api-contact-form"
    viewer_protocol_policy    = "redirect-to-https"
    compress                  = true
    cache_policy_id           = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id  = data.aws_cloudfront_origin_request_policy.all_viewer_except_host_header.id
  }

  # S3 returns a 403 (not a 404) for a missing object, because the bucket
  # policy denies listing to everyone except CloudFront itself — S3 can't
  # tell "this file doesn't exist" from "you're not allowed to know if it
  # exists", so it defaults to the more restrictive answer. Without this
  # block, a mistyped URL would show a raw AWS XML error page instead of an
  # actual "page not found" page.
  #
  # This assumes the Astro build produces a /404.html. If there isn't a
  # custom 404 page in the project yet (src/pages/404.astro), that's worth
  # adding before this goes live — flagging it now so it doesn't get missed.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Referencing the VALIDATION resource's certificate_arn (rather than the
  # certificate resource directly) means Terraform always treats "the
  # certificate is actually validated" as a prerequisite for CloudFront
  # using it — not just "the certificate was requested".
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "Site CDN"
  }
}

# Fixes a real, confirmed problem: this bucket has no S3 "static website
# hosting" mode, so there's no built-in resolution of a directory path to
# its index.html. CloudFront's own default_root_object only covers the
# distribution's literal root ("/"), not subdirectories -- so every other
# page (e.g. "/admin", "/contact/") requests a literal S3 object key that
# doesn't exist, and gets a masked 403 instead of a real 404.
#
# This runs on every viewer request. A path that already ends in "/" gets
# "index.html" appended before reaching S3 (a silent rewrite -- safe,
# since the browser's address bar already reflects a directory). A path
# with no trailing slash and no file extension gets a real 301 redirect
# to the same path plus "/" instead, so the address bar updates too --
# needed because some pages (Decap CMS's admin screen) fetch further
# resources relative to what the browser thinks its own location is.
resource "aws_cloudfront_function" "rewrite_clean_urls" {
  name    = "${var.project_name}-rewrite-clean-urls"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrites directory-style paths to their real index.html object key"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      if (uri.endsWith('/')) {
        // Already a directory-style URL -- safe to serve its index.html
        // directly. The browser's address bar already ends in "/", so
        // any relative links/fetches on the page still resolve correctly.
        request.uri += 'index.html';
        return request;
      }

      if (!uri.includes('.')) {
        // No trailing slash and no file extension -- a directory path
        // requested without its slash (e.g. "/admin", "/contact"). This
        // must be a real redirect, not a silent rewrite: some pages
        // (Decap CMS's admin screen, notably) fetch further resources
        // using paths relative to what the browser's address bar shows.
        // Silently serving the directory's index.html under the
        // slash-less URL leaves the browser believing "admin" is a
        // file, so a relative fetch for "config.yml" resolves to the
        // site root instead of "/admin/config.yml" -- exactly the 403
        // seen when this was first tested. Redirecting fixes the
        // address bar first, so relative requests made afterward
        // resolve correctly.
        //
        // Any query string (e.g. "/contact?enquiry=room-hire") must be
        // carried over onto the redirect target -- CloudFront otherwise
        // drops it silently, which is what broke the Room Hire link.
        var qs = [];
        for (var key in request.querystring) {
          if (request.querystring[key].multiValue) {
            request.querystring[key].multiValue.forEach(function (mv) {
              qs.push(key + '=' + mv.value);
            });
          } else {
            qs.push(key + '=' + request.querystring[key].value);
          }
        }
        var newLocation = uri + '/' + (qs.length ? '?' + qs.join('&') : '');

        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: { value: newLocation }
          }
        };
      }

      return request;
    }
  EOT
}