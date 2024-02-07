# vpc-endpoint

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.67 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.67 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_vpc_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_subnet.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_accept"></a> [auto\_accept](#input\_auto\_accept) | Accept the VPC endpoint (the VPC endpoint and service need to be in the same AWS account) | `bool` | `true` | no |
| <a name="input_dns_options"></a> [dns\_options](#input\_dns\_options) | The DNS options for the VPC endpoint | <pre>list(object({<br>    dns_record_ip_type                             = string<br>    private_dns_only_for_inbound_resolver_endpoint = bool<br>  }))</pre> | `[]` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `true` | no |
| <a name="input_ip_address_type"></a> [ip\_address\_type](#input\_ip\_address\_type) | The type of IP addresses to associate with the endpoint | `string` | `null` | no |
| <a name="input_policy"></a> [policy](#input\_policy) | The policy to apply to the endpoint | `string` | `null` | no |
| <a name="input_private_dns_enabled"></a> [private\_dns\_enabled](#input\_private\_dns\_enabled) | Whether or not to associate a private hosted zone with the specified VPC | `bool` | `true` | no |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | The IDs of the route tables | `list(string)` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | The IDs of the security groups | `list(string)` | `null` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | The service name | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The IDs of the subnets | `list(string)` | `null` | no |
| <a name="input_subnet_names"></a> [subnet\_names](#input\_subnet\_names) | The names of the subnets | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the VPC endpoint | `map(string)` | `{}` | no |
| <a name="input_vpc_endpoint_type"></a> [vpc\_endpoint\_type](#input\_vpc\_endpoint\_type) | The type of VPC endpoint | `string` | `"Interface"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC | `string` | `null` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The name of the VPC | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | The ID of the VPC endpoint |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
