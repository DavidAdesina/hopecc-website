# AWS Budgets — not the older CloudWatch billing-metric approach. This is
# fully manageable through Terraform with zero manual console steps
# required. The older approach needs you to manually tick "Receive
# CloudWatch Billing Alerts" in Billing preferences first (and wait ~15
# minutes for it to take effect), lives only in us-east-1, and needs an SNS
# topic with an email subscription you'd have to manually confirm via a
# link sent to your inbox. AWS Budgets skips all of that — it can email you
# directly, with nothing to enable or click beforehand.
#
# Three notifications, giving three different kinds of warning:
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # An early, low-stakes heads-up — nothing to worry about yet, just a
  # signal something's using more than the usual trickle.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.billing_alert_emails
  }

  # Warns as soon as AWS *predicts* (based on spend so far this month) that
  # you'll cross the full budget by month's end. This can fire earlier than
  # the ACTUAL alert below, since it's a forecast rather than a fact —
  # useful for catching a problem while it's still trending, not after.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.billing_alert_emails
  }

  # The hard line: you've genuinely spent the full budgeted amount this
  # month, for real, not just predicted.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.billing_alert_emails
  }
}
