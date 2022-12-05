locals {
  image_trimmer_lambda = {
    name                  = "dip-image-trimmer"
    handler               = var.rh_dip_image_trimmer_lambda_handler
    memory_size           = var.rh_dip_image_trimmer_memory_size
    timeout               = var.rh_dip_image_trimmer_timeout
    zip_file_name         = "rh-dip-image-trimmer.zip"
    log_retention_in_days = var.rh_dip_image_trimmer_log_retention_in_days
  }


  # AWS account id
  account_id = data.aws_caller_identity.current_caller_identity.account_id

  # AWS region
  region = data.aws_region.current_region.name

  # Indicates to monitor resources in "monitor" tags
  # Defaults to "true" on environments named "prod"
  monitor = var.env == "prod" || var.monitor

  default_tags = {
    "env"     = var.env
    "monitor" = local.monitor
  }
}