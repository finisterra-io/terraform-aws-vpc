locals {
  # Only create flow log if user selected to create a VPC as well
  enable_flow_log = var.create_vpc && var.enable_flow_log

  create_flow_log_cloudwatch_iam_role  = local.enable_flow_log && var.flow_log_destination_type != "s3" && var.create_flow_log_cloudwatch_iam_role
  create_flow_log_cloudwatch_log_group = local.enable_flow_log && var.flow_log_destination_type != "s3" && var.create_flow_log_cloudwatch_log_group

  flow_log_destination_arn                  = local.create_flow_log_cloudwatch_log_group ? try(aws_cloudwatch_log_group.flow_log[0].arn, null) : var.flow_log_destination_arn
  flow_log_iam_role_arn                     = var.flow_log_destination_type != "s3" && local.create_flow_log_cloudwatch_iam_role ? try(aws_iam_role.vpc_flow_log_cloudwatch[0].arn, null) : var.flow_log_cloudwatch_iam_role_arn
  flow_log_cloudwatch_log_group_name_suffix = var.flow_log_cloudwatch_log_group_name_suffix == "" ? local.vpc_id : var.flow_log_cloudwatch_log_group_name_suffix
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

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.create_flow_log_cloudwatch_log_group ? 1 : 0

  name              = var.flow_log_cloudwatch_log_group_name
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
  kms_key_id        = var.flow_log_cloudwatch_log_group_kms_key_id

  tags = var.flow_log_cloudwatch_log_group_tags
}

resource "aws_iam_role" "vpc_flow_log_cloudwatch" {
  count = var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name                 = var.flow_aws_iam_role_name
  name_prefix          = var.flow_aws_iam_role_name_prefix
  assume_role_policy   = var.flow_aws_iam_role_assume_role_policy
  permissions_boundary = var.flow_aws_iam_role_permissions_boundary
  description          = var.flow_aws_iam_role_description
  path                 = var.flow_aws_iam_role_path

  tags = var.flow_aws_iam_role_tags
}

# data "aws_iam_policy_document" "flow_log_cloudwatch_assume_role" {
#   count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

#   statement {
#     sid = "AWSVPCFlowLogsAssumeRole"

#     principals {
#       type        = "Service"
#       identifiers = ["vpc-flow-logs.amazonaws.com"]
#     }

#     effect = "Allow"

#     actions = ["sts:AssumeRole"]
#   }
# }

resource "aws_iam_role_policy_attachment" "vpc_flow_log_cloudwatch" {
  count = var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  role       = aws_iam_role.vpc_flow_log_cloudwatch[0].name
  policy_arn = aws_iam_policy.vpc_flow_log_cloudwatch[0].arn
}

resource "aws_iam_policy" "vpc_flow_log_cloudwatch" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name        = var.flow_iam_policy_name
  name_prefix = var.flow_name_prefix
  description = var.flow_iam_policy_description
  policy      = var.flow_iam_policy_document
  path        = var.flow_iam_policy_path
  tags        = var.flow_policy_tags
}

# data "aws_iam_policy_document" "vpc_flow_log_cloudwatch" {
#   count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

#   statement {
#     sid = "AWSVPCFlowLogsPushToCloudWatch"

#     effect = "Allow"

#     actions = [
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogGroups",
#       "logs:DescribeLogStreams",
#     ]

#     resources = ["*"]
#   }
# }
