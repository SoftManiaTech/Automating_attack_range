variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "key_name" {
  type = string
}

variable "volume_size" {
  type    = number
  default = 50
}

variable "splunk_password" {
  type = string
}
