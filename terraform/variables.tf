variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "allowed_account_ids" {
  description = "Fail fast if someone points this at the wrong AWS account"
  type        = list(string)
  default     = []      # supply your account id in terraform.tfvars
}

variable "geofence_collection_name" {
  description = "Name of the Amazon Location geofence collection"
  type        = string
  default     = "bet-regions"
}

variable "lambda_timeout_seconds" {
  description = "Execution timeout for the geofence Lambda"
  type        = number
  default     = 2
}
