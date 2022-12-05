# set up the sqs resources
resource "aws_sqs_queue" "image_trimmer_dlq" {
  name                      = "image-trimmer-dlq-${var.stack_id}-${var.env}"
  sqs_managed_sse_enabled   = var.sqs_managed_sse_enabled
  message_retention_seconds = var.message_retention_seconds
}

resource "aws_lambda_function" "image_trimmer_lambda" {
  function_name = "${local.image_trimmer_lambda.name}-${var.stack_id}-${var.env}"
  description   = "Function to trim images."
  role          = data.aws_iam_role.dip_data_pipeline_role.arn
  handler       = local.image_trimmer_lambda.handler
  layers        = []
  memory_size   = local.image_trimmer_lambda.memory_size
  runtime       = var.python_version


  s3_bucket = data.aws_s3_object.lambda_archive.bucket
  s3_key    = data.aws_s3_object.lambda_archive.key


  tags = {
    "env"         = var.env
    "envName"     = var.env
    "environment" = var.env
    "monitor"     = var.monitor
  }
  timeout = local.image_trimmer_lambda.timeout

  environment {
    variables = {
      "ENV_NAME"                             = var.env
      "STACK_ID"                             = var.stack_id
      "CONFORMED_MEDIA_KAFKA_TOPIC_DLQ"      = var.conformed_media_kafka_topic_dlq
      "DIP_KAFKA_BOOTSTRAP_SERVERS"          = data.aws_msk_cluster.dip_msk_cluster.bootstrap_brokers
      "MEDIA_CONFORMED_FILES_S3_BUCKET_NAME" = "dip-media-conformed-files-${var.stack_id}-${var.env}-${local.account_id}"
      "MEDIA_RAW_FILES_S3_BUCKET_NAME"       = "dip-media-raw-files-${var.stack_id}-${var.env}-${local.account_id}"
      "IMAGE_RESIZE_PROCESSOR_QUEUE"         = var.image_resize_processor_queue_url
      "WRITE_LOG_DEBUG"                      = var.write_log_debug
      "WHITE_THRESHOLD"                      = var.white_threshold
      "PIXEL_THRESHOLD"                      = var.pixel_threshold
      "MAX_RESIZE_WIDTH"                     = var.max_resize_width
      "MAX_RESIZE_HEIGHT"                    = var.max_resize_height
      "MAX_SAVE_QUALITY_VALUE"               = var.image_save_quality_value
      "CROPPING_OFFSET_VALUE"                = var.cropping_offset_value
      "EXTENSIONS"                           = var.extensions
    }
  }

  vpc_config {
    subnet_ids = [
      data.aws_subnet.private_subnet_1.id,
      data.aws_subnet.private_subnet_2.id,
      data.aws_subnet.private_subnet_3.id,
      data.aws_subnet.private_subnet_4.id
    ]
    security_group_ids = [data.aws_security_group.nat_gateway_sg.id]
  }

  lifecycle {
    ignore_changes = [
      s3_object_version
    ]
  }
}

resource "aws_lambda_function_event_invoke_config" "image_trimmer_lambda_invoke" {
  function_name          = aws_lambda_function.image_trimmer_lambda.function_name
  maximum_retry_attempts = var.maximum_retry_attempts
  destination_config {
    on_failure {
      destination = aws_sqs_queue.image_trimmer_dlq.arn
    }
  }
}

# Set up logging for the lambda
resource "aws_cloudwatch_log_group" "image_trimmer_logs" {
  name              = "/aws/lambda/${local.image_trimmer_lambda.name}-${var.stack_id}-${var.env}"
  retention_in_days = local.image_trimmer_lambda.log_retention_in_days
  depends_on        = [aws_lambda_function.image_trimmer_lambda]
}

# Set up log subscription filters
resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_log_subscription_filter" {
  destination_arn = data.aws_lambda_function.logs_shipper_lambda.arn
  filter_pattern  = ""
  log_group_name  = "/aws/lambda/${local.image_trimmer_lambda.name}-${var.stack_id}-${var.env}"
  name            = "${local.image_trimmer_lambda.name}-subsr-filter-${var.stack_id}-${var.env}"
  depends_on      = [aws_cloudwatch_log_group.image_trimmer_logs]
}

# Set up event source mapping for triggering from Kafka media conformed stream
resource "aws_lambda_event_source_mapping" "image_trimmer_event_source" {
  function_name                      = "${local.image_trimmer_lambda.name}-${var.stack_id}-${var.env}"
  event_source_arn                   = data.aws_msk_cluster.dip_msk_cluster.arn
  enabled                            = var.image_trimmer_trigger_enabled
  batch_size                         = var.image_trimmer_batch_size
  maximum_batching_window_in_seconds = var.image_trimmer_max_batching_window
  topics                             = [var.conformed_media_kafka_topic]
  starting_position                  = var.kafka_trigger_starting_position
  depends_on                         = [aws_lambda_function.image_trimmer_lambda]
}

