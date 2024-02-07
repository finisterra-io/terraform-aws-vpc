resource "aws_vpc_endpoint" "this" {
  count               = var.enabled ? 1 : 0
  vpc_id              = var.vpc_name != null ? data.aws_vpc.default[0].id : var.vpc_id
  service_name        = var.service_name
  vpc_endpoint_type   = var.vpc_endpoint_type
  auto_accept         = var.auto_accept
  private_dns_enabled = var.private_dns_enabled
  policy              = var.policy
  ip_address_type     = var.ip_address_type
  route_table_ids     = var.route_table_ids
  security_group_ids  = var.security_group_ids
  subnet_ids          = var.subnet_names != null ? data.aws_subnet.default[*].id : var.subnet_ids
  tags                = var.tags

  dynamic "dns_options" {
    for_each = var.dns_options
    content {
      dns_record_ip_type                             = dns_options.value.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = dns_options.value.private_dns_only_for_inbound_resolver_endpoint

    }
  }
}
