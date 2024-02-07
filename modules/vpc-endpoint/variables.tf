variable "enabled" {
  type        = bool
  description = "Set to false to prevent the module from creating any resources"
  default     = true
}
variable "vpc_name" {
  type        = string
  description = "The name of the VPC"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
  default     = null
}

variable "subnet_names" {
  type        = list(string)
  description = "The names of the subnets"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "The IDs of the subnets"
  default     = null
}

variable "service_name" {
  type        = string
  description = "The service name"
}

variable "vpc_endpoint_type" {
  type        = string
  description = "The type of VPC endpoint"
  default     = "Interface"
}

variable "auto_accept" {
  type        = bool
  description = "Accept the VPC endpoint (the VPC endpoint and service need to be in the same AWS account)"
  default     = true
}

variable "private_dns_enabled" {
  type        = bool
  description = "Whether or not to associate a private hosted zone with the specified VPC"
  default     = true
}

variable "policy" {
  type        = string
  description = "The policy to apply to the endpoint"
  default     = null
}

variable "ip_address_type" {
  type        = string
  description = "The type of IP addresses to associate with the endpoint"
  default     = null
}

variable "route_table_ids" {
  type        = list(string)
  description = "The IDs of the route tables"
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "The IDs of the security groups"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the VPC endpoint"
  default     = {}
}

variable "dns_options" {
  type = list(object({
    dns_record_ip_type                             = string
    private_dns_only_for_inbound_resolver_endpoint = bool
  }))
  description = "The DNS options for the VPC endpoint"
  default     = []
}
