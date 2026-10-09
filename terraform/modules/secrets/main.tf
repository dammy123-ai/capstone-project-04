variable "env" { type = string }

# Creates the secret CONTAINERS only. Values are set via AWS CLI/script afterward,
# so they never enter Terraform state or Git.
resource "aws_secretsmanager_secret" "backend" {
  name                    = "zuri/${var.env}/backend"
  recovery_window_in_days = 0   # lets you destroy/recreate freely during the capstone
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "zuri/${var.env}/grafana"
  recovery_window_in_days = 0
}

output "secret_arns" { value = [aws_secretsmanager_secret.backend.arn, aws_secretsmanager_secret.grafana.arn] }