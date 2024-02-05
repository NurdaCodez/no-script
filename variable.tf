variable "db_password" {
  default = "postgres"
  
}

variable "project" {
  
default = "playground-s-11-76fcabeb"
}

variable "promote_to_new_primary" {
  type = bool
  default = false # change to rename
}

variable "swap-region" {
  type = bool
  default = false
  
}