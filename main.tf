resource "aws_prometheus_workspace" "this" {
  count = var.enable_managed_prometheus ? 1 : 0

  alias = local.name
  tags  = var.tags
}

resource "aws_prometheus_alert_manager_definition" "this" {
  count = var.enable_alertmanager ? 1 : 0

  workspace_id = local.amp_ws_id

  definition = <<EOF
alertmanager_config: |
    route:
      receiver: 'default'
    receivers:
      - name: 'default'
EOF
}

provider "grafana" {
  url  = local.amg_ws_endpoint
  auth = var.grafana_api_key
}

resource "grafana_data_source" "amp" {
  count      = var.create_prometheus_data_source ? 1 : 0
  type       = "prometheus"
  name       = local.name
  is_default = true
  url        = local.amp_ws_endpoint
  json_data {
    http_method     = "GET"
    sigv4_auth      = true
    sigv4_auth_type = "workspace-iam-role"
    sigv4_region    = local.amp_ws_region
  }
}

# dashboards
resource "grafana_folder" "this" {
  count = var.create_dashboard_folder ? 1 : 0
  title = "Observability Accelerator Dashboards"
}

resource "aws_grafana_workspace" "this" {
  count = var.create && var.create_workspace ? 1 : 0

  name        = var.name
  description = var.description

  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers
  permission_type          = var.permission_type

  grafana_version           = var.grafana_version
  configuration             = var.configuration
  data_sources              = var.data_sources
  notification_destinations = var.notification_destinations
  organization_role_name    = var.organization_role_name
  organizational_units      = var.organizational_units
  role_arn                  = var.create_iam_role ? aws_iam_role.this[0].arn : var.iam_role_arn
  stack_set_name            = coalesce(var.stack_set_name, var.name)

  dynamic "vpc_configuration" {
    for_each = length(var.vpc_configuration) > 0 ? [var.vpc_configuration] : []

    content {
      security_group_ids = var.create_security_group ? flatten(concat([aws_security_group.this[0].id], try(vpc_configuration.value.security_group_ids, []))) : vpc_configuration.value.security_group_ids
      subnet_ids         = vpc_configuration.value.subnet_ids
    }
  }

  tags = var.tags
}
