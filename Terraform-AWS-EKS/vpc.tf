# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "myvpc"
  }
}

# Create IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "maingw"
  }
}

# Create an Elastic IP for each NAT gateway
resource "aws_eip" "pip" {
  count  = length(var.az) # One EIP per availability zone (az)
  domain = "vpc"
}

# Create a NAT gateway for each AZ (using corresponding EIP and subnet)
resource "aws_nat_gateway" "nat-gw" {
  count         = length(var.az) # One NAT gateway per AZ
  allocation_id = aws_eip.pip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # Use public subnet in the same AZ

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name                              = "public-${count.index + 1}"
    "kubernetes.io/role/elb"          = "1" # Tag for public subnets
    "kubernetes.io/cluster/mycluster" = "shared"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name                              = "private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1" # Tag for private subnets
    "kubernetes.io/cluster/mycluster" = "shared"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "public-route-table"
  }
}

# Create a separate route table for each private subnet
resource "aws_route_table" "private" {
  count  = length(var.private_subnets_cidr) # One route table per private subnet
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table-${count.index + 1}"
  }
}

# Create a Route for Public Subnets
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Create routes for each private subnet to the corresponding NAT gateway
resource "aws_route" "private" {
  count                  = length(var.private_subnets_cidr)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat-gw[count.index % length(var.az)].id # Use the corresponding NAT gateway based on availability zone
}

# Attach Route Table to Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Attach Route Table to Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
