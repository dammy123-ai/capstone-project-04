variable "env" { type = string }

# Creates the secret CONTAINER only. The value is set via AWS CLI afterward,
# so it never enters Terraform state or Git.
resource "aws_secretsmanager_secret" "backend" {
  name                    = "zuri/${var.env}/backend"
  recovery_window_in_days = 0   # lets you destroy/recreate freely during the capstone
}

output "secret_arns" { value = [aws_secretsmanager_secret.backend.arn] }