data "aws_vpc" "default" {
  count = var.enabled && var.vpc_name != null ? 1 : 0
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnet" "default" {
  count  = var.enabled && var.subnet_names != null ? length(var.subnet_names) : 0
  vpc_id = var.vpc_name != null ? data.aws_vpc.default[0].id : var.vpc_id
  filter {
    name   = "tag:Name"
    values = [var.subnet_names[count.index]]
  }
}
