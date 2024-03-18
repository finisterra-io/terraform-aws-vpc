locals {
  len_public_subnets  = max(length(var.public_subnets), length(var.public_subnet_ipv6_prefixes))
  len_private_subnets = max(length(var.private_subnets), length(var.private_subnet_ipv6_prefixes))

  max_subnet_length = max(
    local.len_private_subnets,
    local.len_public_subnets,
  )

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  create_vpc = var.create_vpc
}

################################################################################
# VPC
################################################################################

#already defined in aws_flow_log
#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block          = var.use_ipam_pool ? null : var.cidr
  ipv4_ipam_pool_id   = var.ipv4_ipam_pool_id
  ipv4_netmask_length = var.ipv4_netmask_length

  assign_generated_ipv6_cidr_block     = var.enable_ipv6 && !var.use_ipam_pool ? true : null
  ipv6_cidr_block                      = var.ipv6_cidr
  ipv6_ipam_pool_id                    = var.ipv6_ipam_pool_id
  ipv6_netmask_length                  = var.ipv6_netmask_length
  ipv6_cidr_block_network_border_group = var.ipv6_cidr_block_network_border_group

  instance_tenancy                     = var.instance_tenancy
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = var.enable_dns_support
  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = var.tags
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = local.create_vpc && var.create_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = var.dhcp_options_tags
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = local.create_vpc && var.enable_dhcp_options_association ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = var.create_dhcp_options ? aws_vpc_dhcp_options.this[0].id : var.dhcp_options_id
}

################################################################################
# Publiс Subnets
################################################################################

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  assign_ipv6_address_on_creation                = each.value.assign_ipv6_address_on_creation
  cidr_block                                     = each.key
  availability_zone                              = each.value.az
  enable_dns64                                   = each.value.enable_dns64
  enable_resource_name_dns_aaaa_record_on_launch = each.value.enable_resource_name_dns_aaaa_record_on_launch
  enable_resource_name_dns_a_record_on_launch    = each.value.enable_resource_name_dns_a_record_on_launch
  ipv6_cidr_block                                = each.value.ipv6_cidr_block != "" ? each.value.ipv6_cidr_block : null
  ipv6_native                                    = each.value.ipv6_native
  map_public_ip_on_launch                        = each.value.map_public_ip_on_launch
  private_dns_hostname_type_on_launch            = each.value.private_dns_hostname_type_on_launch
  vpc_id                                         = local.vpc_id

  tags = each.value.tags
}

resource "aws_route_table" "public" {
  for_each = var.public_route_tables
  vpc_id   = local.vpc_id

  tags = try(each.value.tags, null)
}

locals {
  flattened_public_route_table_associations = merge([
    for rt_name, rt_details in var.public_route_tables : {
      for subnet_cidr, assoc in rt_details.associations : "${subnet_cidr}-${rt_name}" => {
        subnet_cidr = subnet_cidr
        route_table = rt_name
      }
    }
  ]...)
}

resource "aws_route_table_association" "public" {
  for_each = local.flattened_public_route_table_associations

  subnet_id      = aws_subnet.public[each.value.subnet_cidr].id
  route_table_id = aws_route_table.public[each.value.route_table].id
}

locals {
  flattened_public_route_table_routes = merge([
    for rt_name, rt_details in var.public_route_tables : {
      for route_name, route in rt_details.routes : route_name => {
        destination_cidr_block      = try(route.destination_cidr_block, null)
        destination_ipv6_cidr_block = try(route.destination_ipv6_cidr_block, null)
        igw                         = try(route.igw, null)
        route_table                 = rt_name
      }
    }
  ]...)
}

resource "aws_route" "public" {
  for_each = local.flattened_public_route_table_routes

  route_table_id              = aws_route_table.public[each.value.route_table].id
  destination_cidr_block      = each.value.destination_cidr_block != "" ? each.value.destination_cidr_block : null
  destination_ipv6_cidr_block = each.value.destination_ipv6_cidr_block != "" ? each.value.destination_ipv6_cidr_block : null
  gateway_id                  = lookup(each.value, "igw", null) != null ? aws_internet_gateway.this[0].id : null

}

locals {

  ingress_rules = flatten([
    for acl, details in var.aws_network_acls :
    [for k, v in details.ingress_rules : {
      acl_key     = acl,
      rule_key    = k,
      rule_values = v
    }]
  ])

  egress_rules = flatten([
    for acl, details in var.aws_network_acls :
    [for k, v in details.egress_rules : {
      acl_key     = acl,
      rule_key    = k,
      rule_values = v
    }]
  ])
}

resource "aws_network_acl" "this" {
  for_each = var.aws_network_acls

  vpc_id     = local.vpc_id
  subnet_ids = [for cidr in each.value.subnet_ids : (try(aws_subnet.private[cidr].id, aws_subnet.public[cidr].id))]
  tags       = each.value.tags
}

resource "aws_network_acl_rule" "ingress" {
  for_each = { for rule in local.ingress_rules : "${rule.acl_key}_${rule.rule_key}" => rule }

  network_acl_id = aws_network_acl.this[each.value.acl_key].id

  egress      = false
  rule_number = each.value.rule_values.rule_number
  rule_action = each.value.rule_values.rule_action
  from_port   = lookup(each.value.rule_values, "from_port", null)
  to_port     = lookup(each.value.rule_values, "to_port", null)
  protocol    = each.value.rule_values.protocol
  cidr_block  = lookup(each.value.rule_values, "cidr_block", null)
}

resource "aws_network_acl_rule" "egress" {
  for_each = { for rule in local.egress_rules : "${rule.acl_key}_${rule.rule_key}" => rule }

  network_acl_id = aws_network_acl.this[each.value.acl_key].id

  egress      = true
  rule_number = each.value.rule_values.rule_number
  rule_action = each.value.rule_values.rule_action
  from_port   = lookup(each.value.rule_values, "from_port", null)
  to_port     = lookup(each.value.rule_values, "to_port", null)
  protocol    = each.value.rule_values.protocol
  cidr_block  = lookup(each.value.rule_values, "cidr_block", null)
}

################################################################################
# Private Subnets
################################################################################

locals {
  create_private_subnets = local.create_vpc && local.len_private_subnets > 0
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  assign_ipv6_address_on_creation                = each.value.assign_ipv6_address_on_creation
  cidr_block                                     = each.key
  availability_zone                              = each.value.az
  enable_dns64                                   = each.value.enable_dns64
  enable_resource_name_dns_aaaa_record_on_launch = each.value.enable_resource_name_dns_aaaa_record_on_launch
  enable_resource_name_dns_a_record_on_launch    = each.value.enable_resource_name_dns_a_record_on_launch
  ipv6_cidr_block                                = each.value.ipv6_cidr_block != "" ? each.value.ipv6_cidr_block : null
  ipv6_native                                    = each.value.ipv6_native
  private_dns_hostname_type_on_launch            = each.value.private_dns_hostname_type_on_launch
  map_public_ip_on_launch                        = each.value.map_public_ip_on_launch
  vpc_id                                         = local.vpc_id

  tags = each.value.tags
}

resource "aws_route_table" "private" {
  for_each = var.private_route_tables
  vpc_id   = local.vpc_id

  tags = try(each.value.tags, null)
}

locals {
  flattened_private_route_table_associations = merge([
    for rt_name, rt_details in var.private_route_tables : {
      for subnet_cidr, assoc in rt_details.associations : "${subnet_cidr}-${rt_name}" => {
        subnet_cidr = subnet_cidr
        route_table = rt_name
      }
    }
  ]...)
}

resource "aws_route_table_association" "private" {
  for_each = local.flattened_private_route_table_associations

  subnet_id      = aws_subnet.private[each.value.subnet_cidr].id
  route_table_id = aws_route_table.private[each.value.route_table].id
}

locals {
  flattened_private_route_table_routes = merge([
    for rt_name, rt_details in var.private_route_tables : {
      for route_name, route in rt_details.routes : route_name => {
        destination_cidr_block      = try(route.destination_cidr_block, null)
        destination_ipv6_cidr_block = try(route.destination_ipv6_cidr_block, null)
        nat_gateway_name            = try(route.nat_gateway_name, null)
        route_table                 = rt_name
      }
    }
  ]...)
}

resource "aws_route" "private" {
  for_each = local.flattened_private_route_table_routes

  route_table_id              = aws_route_table.private[each.value.route_table].id
  destination_cidr_block      = lookup(each.value, "destination_cidr_block", null) != null ? each.value.destination_cidr_block : null
  destination_ipv6_cidr_block = lookup(each.value, "destination_ipv6_cidr_block", null) != null ? each.value.destination_ipv6_cidr_block : null
  nat_gateway_id              = lookup(each.value, "nat_gateway_name", null) != null ? aws_nat_gateway.this[each.value.nat_gateway_name].id : null
}


################################################################################
# Private Network ACLs
################################################################################

locals {
  create_private_network_acl = local.create_private_subnets && var.private_dedicated_network_acl
}

resource "aws_network_acl" "private" {
  count = local.create_private_network_acl ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.private[*].id

  tags = var.private_acl_tags
}

resource "aws_network_acl_rule" "private_inbound" {
  count = local.create_private_network_acl ? length(var.private_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = false
  rule_number     = var.private_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "private_outbound" {
  count = local.create_private_network_acl ? length(var.private_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = true
  rule_number     = var.private_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}


################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = var.create_igw ? 1 : 0

  vpc_id = local.vpc_id

  tags = var.igw_tags
}

resource "aws_egress_only_internet_gateway" "this" {
  count = local.create_vpc && var.create_egress_only_igw && var.enable_ipv6 && local.max_subnet_length > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = var.igw_tags
}

################################################################################
# NAT Gateway
################################################################################
resource "aws_nat_gateway" "this" {
  for_each = var.nat_gateways

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.value.subnet_cidr].id
  tags          = each.value.tags

  depends_on = [aws_internet_gateway.this]
}

resource "aws_eip" "nat" {
  for_each = var.nat_gateways

  domain = "vpc"
  tags   = each.value.eip_tags

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Default VPC
################################################################################

resource "aws_default_security_group" "this" {
  count = local.create_vpc && var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self             = lookup(ingress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", 0)
      to_port          = lookup(ingress.value, "to_port", 0)
      protocol         = lookup(ingress.value, "protocol", "-1")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self             = lookup(egress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
      description      = lookup(egress.value, "description", null)
      from_port        = lookup(egress.value, "from_port", 0)
      to_port          = lookup(egress.value, "to_port", 0)
      protocol         = lookup(egress.value, "protocol", "-1")
    }
  }

  tags = var.default_security_group_tags
}

################################################################################
# Default Network ACLs
################################################################################

resource "aws_default_network_acl" "this" {
  count = local.create_vpc && var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = aws_vpc.this[0].default_network_acl_id

  # subnet_ids is using lifecycle ignore_changes, so it is not necessary to list
  subnet_ids = null

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = var.default_network_acl_tags

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

################################################################################
# Default Route
################################################################################

resource "aws_default_route_table" "default" {
  count = local.create_vpc && var.manage_default_route_table ? 1 : 0

  default_route_table_id = aws_vpc.this[0].default_route_table_id
  propagating_vgws       = var.default_route_table_propagating_vgws

  dynamic "route" {
    for_each = var.default_route_table_routes
    content {
      # One of the following destinations must be provided
      cidr_block                 = lookup(route.value, "cidr_block", null)
      ipv6_cidr_block            = lookup(route.value, "ipv6_cidr_block", null)
      destination_prefix_list_id = lookup(route.value, "destination_prefix_list_id", null)

      # One of the following targets must be provided
      # # egress_only_gateway_id    = lookup(route.value, "egress_only_gateway_id", null)
      gateway_id                = lookup(route.value, "gateway_id", null)
      instance_id               = lookup(route.value, "instance_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = var.default_route_table_tags
}
