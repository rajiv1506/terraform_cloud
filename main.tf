variable "example_map" {
  type = map(list(string))
  default = {
    "elb" = ["10.0.0.0/24", "10.1.0.0/24"],
    "k8" = ["10.1.0.0/24"],
    "main" = ["10.2.0.0/24"],
  }
}

data "aws_route_tables" "example" {
  vpc_id = "vpc-0eb87f4bc98e08216"
  for_each = var.example_map

  filter {
    name   = "tag:role"
    values = [each.key]
  }

}

data "aws_vpc" "example" {
  id = "vpc-0eb87f4bc98e08216"
}




locals {
  
 # testing = {for k,v in data.aws_vpc.example : k => v.main_route_table_id}
  
  route_table_ids_map = { for k, v in data.aws_route_tables.example :  k => v.ids }

  testing = merge(local.route_table_ids_map, {main = [data.aws_vpc.example.main_route_table_id]})

  merged_list = {
    for k, v in var.example_map :
    k => {
      for id in local.testing[k] :
      id => v
    }
  }
}

output "testing456" {
  value = local.testing
}

output "testing678" {
  value = data.aws_vpc.example.main_route_table_id
}

locals {
  routes = {
    for k, v in local.merged_list :
    k => [
      for id, cidrs in v :
      [
        for cidr in cidrs :
        {
          route_table_id = id
          cidr_block     = cidr
        }
      ]
    ]
  }
}



/*resource "aws_route" "example" {
  for_each = [for k,v in local.routes: v]

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.cidr_block 
  vpc_peering_connection_id = "pcx-0e8db41d404064c3c"
}*/

locals {
  route_table_cidrs = flatten([
    for k, v in local.routes : [
      for cidr_set in v :
        [
          for cidr in cidr_set :
            {
              route_table_id = cidr.route_table_id
              cidr_block     = cidr.cidr_block
            }
        ]
    ]
  ])
}




  
resource "aws_route" "example" {
  for_each = {
    for rt_cidr in local.route_table_cidrs :
      "${rt_cidr.route_table_id}_${rt_cidr.cidr_block}" => {
        route_table_id         = rt_cidr.route_table_id
        destination_cidr_block = rt_cidr.cidr_block
       
      }
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  vpc_peering_connection_id = "pcx-0e8db41d404064c3c"
}


