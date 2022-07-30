variable "key_name" {
  type    = string
}

variable "ami_id_master" {
  type    = string
} 

variable "region"{
  type   = string
}

locals {
  common_tags= {
    Owner= "DevOps Team"
    service= "backend"
  }
}

#amazon linux 2 map;
variable "ami_id_managed" {
  type = map(string)
  default = {
    "us-east-1" = "ami-0cff7528ff583bf9a"
    "us-east-2" = "ami-02d1e544b84bf7502"
    "us-west-1" = "ami-0d9858aa3c6322f73"    
    "us-west-2" = "ami-098e42ae54c764c35"
    "ca_central"= "ami-00f881f027a6d74a0"
  }
}