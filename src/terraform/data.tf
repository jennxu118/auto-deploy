# Data source for the current AWS region
data "aws_region" "current_region" {}

# Data source for the current AWS caller identity
data "aws_caller_identity" "current_caller_identity" {}

# Logs shipper function lambda.
data "aws_lambda_function" "logs_shipper_lambda" {
  function_name = "dip-cloudwatch-logs-shipper-${var.stack_id}-${var.env}"
}

data "aws_iam_role" "dip_data_pipeline_role" {
  name = "dip-data-pipeline-${var.stack_id}-${var.env}"
}

data "aws_vpc" "default_vpc" {
  filter {
    name = "tag:aws:cloudformation:logical-id"
    values = [
      "vpc"
    ]
  }

  filter {
    name   = "tag:Name"
    values = ["vpc-${var.env}"]
  }
}

# Data source for the environment's NAT gateway security group
data "aws_security_group" "nat_gateway_sg" {
  vpc_id = data.aws_vpc.default_vpc.id

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["natGatewaySecurityGroup"]
  }

  filter {
    name   = "tag:vpc"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Data source for private subnet Ids
data "aws_subnet" "private_subnet_1" {
  vpc_id = data.aws_vpc.default_vpc.id

  filter {
    name = "tag:aws:cloudformation:logical-id"
    values = [
      "ec2PrivateSubnet1"
    ]
  }
}

data "aws_subnet" "private_subnet_2" {
  vpc_id = data.aws_vpc.default_vpc.id

  filter {
    name = "tag:aws:cloudformation:logical-id"
    values = [
      "ec2PrivateSubnet2"
    ]
  }
}

data "aws_subnet" "private_subnet_3" {
  vpc_id = data.aws_vpc.default_vpc.id

  filter {
    name = "tag:aws:cloudformation:logical-id"
    values = [
      "ec2PrivateSubnet3"
    ]
  }
}

data "aws_subnet" "private_subnet_4" {
  vpc_id = data.aws_vpc.default_vpc.id

  filter {
    name = "tag:aws:cloudformation:logical-id"
    values = [
      "ec2PrivateSubnet4"
    ]
  }
}

# Data source for the Lambda function
data "aws_s3_object" "lambda_archive" {
  bucket = "rh-lambda-deploy-${var.env}-${local.account_id}"
  key    = "${var.stack_id}/rh-dip-image-trimmer.zip"
}

data "aws_msk_cluster" "dip_msk_cluster" {
  cluster_name = var.dip_msk_cluster_name
}