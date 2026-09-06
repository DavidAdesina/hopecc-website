variable "project_name" {
  description = "Short name used as a prefix for resource names and tags"
  type        = string
  default     = "hopecc-website"
}

variable "domain_name" {
  description = "The site's primary domain name"
  type        = string
  default     = "hopecc.org.uk"
}

variable "brother_usernames" {
  description = "IAM usernames for the two brothers' read-only + sandbox accounts."
  type        = list(string)
  default     = ["joel.adesina", "paul.adesina"]
}

variable "billing_alert_emails" {
  description = "Email addresses to receive billing alerts. EDIT THESE to your real emails before applying."
  type        = list(string)
  default     = ["david.adesinauk@gmail.com", "jaleenadesina@yahoo.com", "gozman00@yahoo.co.uk"]
}

variable "monthly_budget_usd" {
  description = "Monthly AWS spend threshold in USD. AWS Budgets always operates in USD regardless of your billing currency (GBP). $10/month gives generous headroom above the near-zero cost expected at Hope's traffic level, while still catching a genuine misconfiguration early. Adjust if you'd prefer a different threshold."
  type        = string
  default     = "10"
}

variable "contact_form_email" {
  description = "The address the contact form sends notifications to, and sends them from. Must already be a working mailbox — AWS will email a one-time verification link to it."
  type        = string
  default     = "info@hopecc.org.uk"
}