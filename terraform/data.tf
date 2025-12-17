data "aws_ecrpublic_authorization_token" "token" {
  region = local.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}