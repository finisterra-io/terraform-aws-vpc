locals {
  # Only create flow log if user selected to create a VPC as well
  enable_flow_log = var.create_vpc && var.enable_flow_log

  create_flow_log_cloudwatch_iam_role = local.enable_flow_log && var.flow_log_destination_type != "s3" && var.create_flow_log_cloudwatch_iam_role
}

################################################################################
# Flow Log
################################################################################

resource "aws_flow_log" "this" {
  for_each = { for k, v in var.aws_flow_logs : k => v }

  log_destination_type     = lookup(each.value, "log_destination_type", null)
  log_destination          = lookup(each.value, "log_destination", null)
  log_format               = lookup(each.value, "log_format", null)
  iam_role_arn             = lookup(each.value, "iam_role_arn", null)
  traffic_type             = lookup(each.value, "traffic_type", null)
  vpc_id                   = local.vpc_id
  max_aggregation_interval = lookup(each.value, "max_aggregation_interval", null)

  dynamic "destination_options" {
    for_each = lookup(each.value, "destination_options", [])

    content {
      file_format                = destination_options.value["file_format"]
      hive_compatible_partitions = destination_options.value["hive_compatible_partitions"]
      per_hour_partition         = destination_options.value["per_hour_partition"]
    }
  }

  tags = try(each.value.tags, {})
}

################################################################################
# Flow Log CloudWatch
################################################################################

# resource "aws_cloudwatch_log_group" "flow_log" {
#   count = var.create_flow_log_cloudwatch_log_group ? 1 : 0

#   name              = var.flow_log_cloudwatch_log_group_name
#   retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
#   kms_key_id        = var.flow_log_cloudwatch_log_group_kms_key_id

#   tags = var.flow_log_cloudwatch_log_group_tags
# }
