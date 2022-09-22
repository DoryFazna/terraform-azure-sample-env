variable "host_os" {
  type = string
}

variable "subnets" {
  type = map(any)
  default = {
    "subnet_1" = {
      name             = "subnet_1"
      address_prefixes = ["10.123.1.0/24"]
    }
    "subnet_2" = {
      name             = "subnet_2"
      address_prefixes = ["10.123.2.0/24"]
    }
  }
}