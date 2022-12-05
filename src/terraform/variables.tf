# ========================================================================
# AWS
# ========================================================================

variable "aws_region" {
  description = "The AWS region to provision resources in"
  type        = string
  default     = "us-east-1"
}

# ========================================================================
# Module
# ========================================================================

variable "env" {
  description = "The environment of the module resources"
  type        = string
  default     = "sandbox"
}

variable "monitor" {
  description = "Indicates the resources should designated for monitoring (overridden with 'true' for environments named 'prod')"
  type        = bool
  default     = false
}

# ========================================================================
# Lambda variables
# ========================================================================

variable "rh_dip_image_trimmer_lambda_handler" {
  description = "The name of the lambda handler for the functions"
  type        = string
  default     = "src.applications.image_trimmer.invoke.handler"
}

variable "rh_dip_image_trimmer_memory_size" {
  description = "The memory size of the lambda"
  type        = number
  default     = 2048
}

variable "rh_dip_image_trimmer_timeout" {
  description = "The maximum invocation timeout limit"
  type        = number
  default     = 900
}

variable "rh_dip_image_trimmer_log_retention_in_days" {
  description = "The log retention"
  type        = number
  default     = 7
}

variable "python_version" {
  description = "The Python version of the Lambda code"
  type        = string
  default     = "python3.8"
}

variable "stack_id" {
  description = "Stack ID"
  type        = string
  default     = "int"
}

variable "white_threshold" {
  description = "he threshold for white border. Value as 240 from elm-media legacy code"
  type        = number
  default     = 240
}

variable "pixel_threshold" {
  description = "The threshold for image comparison"
  type        = number
  default     = 10
}
variable "max_resize_width" {
  description = "The width of resized image. Used the max dimensions allowed for zillow images as reference"
  type        = number
  default     = 2048
}

variable "max_resize_height" {
  description = "The height of resized image. Used the max dimensions allowed for zillow images as reference"
  type        = number
  default     = 1536
}

variable "cropping_offset_value" {
  description = "Add offset to the image when adding two images."
  type        = number
  default     = -35
}

variable "image_save_quality_value" {
  description = "JPEG images can be compressed and saved in different qualities. The quality can be any number between 1 (worst) and 95 (best)."
  type        = number
  default     = 85
}

variable "extensions" {
  description = "Allowed image file extensions"
  type        = string
  default     = ".jpg,.jpeg,.png,.webp"
}

# ========================================================================
# Kafka variables
# ========================================================================

variable "conformed_media_kafka_topic" {
  description = "Topic for conformed media in Kafka"
  type        = string
  default     = "rh.rhdc.conformedmlspipeline.utility.media.0"
}

variable "conformed_media_kafka_topic_dlq" {
  description = "DLQ topic for conformed media in Kafka"
  type        = string
  default     = "rh.rhdc.conformedmlspipeline.utility.media.0-dead-letter"
}


variable "dip_msk_cluster_name" {
  description = "Name of msk cluster for DIP."
  type        = string
}

# ========================================================================
# Kafka trigger variables
# ========================================================================
variable "image_trimmer_trigger_enabled" {
  description = "Sets the Kafka conformed media trigger to enabled/disabled"
  type        = bool
  default     = true
}

variable "image_trimmer_batch_size" {
  description = "Sets the batch size for the image trimmer trigger"
  type        = number
  default     = 250
}

variable "image_trimmer_max_batching_window" {
  description = "Sets the maximum_batching_window_in_seconds"
  type        = number
  default     = 1
}

variable "kafka_trigger_starting_position" {
  description = "The position in a stream from which to start reading"
  type        = string
  default     = "LATEST"

  validation {
    condition     = contains(["LATEST", "TRIM_HORIZON"], var.kafka_trigger_starting_position)
    error_message = "The kafka starting position must be 'LATEST', 'TRIM_HORIZON'."
  }
}

# ========================================================================
# SQS variables
# ========================================================================
variable "image_resize_processor_queue_url" {
  description = "Sets the SQS image resize processor queue url"
  type        = string
}

variable "write_log_debug" {
  description = "Turn on or off write logs"
  type        = bool
  default     = false
}

variable "maximum_retry_attempts" {
  description = "The maximum number of times to retry when the function returns an error."
  type        = number
  default     = 2
}

variable "message_retention_seconds" {
  description = "How long messages will be keep in the queue"
  type        = number
  default     = 1209600
}

variable "sqs_managed_sse_enabled" {
  description = "Flag for SSE-SQS encryption"
  type        = bool
  default     = false
}

