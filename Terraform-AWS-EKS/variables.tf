variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/16"
}
variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24", "10.100.4.0/24"]
}
variable "private_subnets_cidr" {
  default = ["10.100.5.0/24", "10.100.6.0/24", "10.100.7.0/24", "10.100.8.0/24"]
}

variable "az" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}