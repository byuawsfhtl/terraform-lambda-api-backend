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

variable "ecr_repo" {
  type = object({
    name           = string,
    repository_url = string
  })
  description = "The ECR repository that contains the image for the lambda functions."
}

variable "image_tag" {
  type        = string
  description = "The image tag for the Docker image (the timestamp)."
}

variable "lambda_environment_variables" {
  type        = map(string)
  description = "The environment variables to set on the Lambda functions."
}

variable "lambda_endpoint_definitions" {
  type = list(object({
    path_part       = string
    allowed_headers = optional(string)

    method_definitions = list(object({
      http_method = string
      command     = list(string)
      timeout     = optional(number)
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

variable "path_part" {
  type        = string
  description = "The URL path to invoke the method."
}

variable "allowed_headers" {
  type        = string
  description = "The custom headers the endpoint should allow. Provided as a string with each header key separated by a comma."
}

variable "method_definitions" {
  type = list(object({
    http_method = string
    command     = list(string)
    timeout     = optional(number)
    memory_size = optional(number)
  }))
  description = "The definitions for each method of the endpoint."
}

variable "api_gateway" {
  type = object({
    name             = string
    id               = string
    root_resource_id = string
    execution_arn    = string
  })
  description = "The API Gateway for the enpoints."
}

variable "command" {
  type        = list(string)
  description = "The lambda handlers for each method of the endpoint. The syntax is file_name.function_name"
}

variable "timeout" {
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds."
}

variable "memory_size" {
  type        = number
  description = "The amount of memory, in MB, your Lambda Function is given. Valid values are from 128 to 10,240. Default is 128. 1,769 is equivalent to 1 vCPU."
}

variable "api_gateway" {
  type = object({
    name             = string
    id               = string
    root_resource_id = string
    execution_arn    = string
  })
  description = "The API Gateway for the enpoints."
}

variable "api_resource_id" {
  type        = string
  description = "The ID for the API Resource for this endpoint."
}
