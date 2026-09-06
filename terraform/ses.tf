# The contact form (built out through the rest of this session) needs an
# AWS-verified email identity before SES will let it send anything at all
# -- this is AWS's own anti-spam safeguard, not something specific to this
# project.
#
# This verifies a single EMAIL ADDRESS rather than the whole domain -- the
# simpler of SES's two verification methods, with no extra DNS records to
# add in NetNerd. That's enough here because info@hopecc.org.uk is the
# only address this will ever send from or to: the Lambda function (added
# later this session) will use it as both the "Source" and the
# "Destination".
resource "aws_ses_email_identity" "contact_form" {
  email = var.contact_form_email
}

# MANUAL STEP REQUIRED -- same shape as the ACM DNS validation back in
# Session 1: right after `terraform apply`, AWS emails a verification
# link to info@hopecc.org.uk. Someone with access to that inbox needs to
# open the email and click the link -- Terraform can't do that part for
# you. `terraform apply` will still finish successfully without it;
# nothing that uses this identity (the Lambda function, added later this
# session) will actually be able to send email until the link is
# clicked, though.
