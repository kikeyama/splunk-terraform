variable "signalfx_token" {
  type = string
}

variable "signalfx_realm" {
  type = string
}

provider "signalfx" {
  auth_token = var.signalfx_token
  api_url = "https://api.${var.signalfx_realm}.signalfx.com"
}
