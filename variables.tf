variable "project_name" {
  type        = string
  description = "The name of the project in TitleCase."
}

variable "app_name" {
  type        = string
  description = "The name of the project in kebab-case."
}

variable "domain" {
  type        = string
  description = "The domain of the hosted zone."
}

variable "url" {
  type        = string
  description = "The url of the application. Ex: projectname.fhtl.org"
}

variable "api_url" {
  type        = string
  description = "The custom url for your api. Ex: api.projectname.fhtl-dev.org"
}

variable "api_gateway_integration_type" {
  description = "The integration type for API Gateway"
  type        = string
  default     = "AWS_PROXY"
}

variable "image_tag" {
  type        = string
  description = "The image tag for the Docker image (the timestamp)."
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repository"
  type        = string
}

variable "lambda_environment_variables" {
  type        = map(string)
  description = "The environment variables to set on the Lambda functions."
  default     = {}
}

variable "lambda_endpoint_definitions" {
  type = list(object({
    path_part       = string
    allowed_headers = list(string)

    method_definitions = list(object({
      http_method = string
      command     = optional(list(string))
      timeout     = number
      memory_size = number
    }))
  }))
  description = "The definitions for each lambda function."
}

variable "function_policies" {
  type        = list(string)
  description = "List of IAM Policy ARNs to attach to the task execution policy."
  default     = []
}

variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the Lambda Role to be attached to the Lambda function."
}
