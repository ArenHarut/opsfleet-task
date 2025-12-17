locals = {
    aws_region = us-east-1
    aws_account_id = "11111"
    resource_name_prefix = "opsfleet-test"
    
    region = "eu-west-1"

    vpc_cidr = "10.0.0.0/16"
    azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}