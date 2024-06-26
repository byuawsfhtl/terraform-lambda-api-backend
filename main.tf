terraform {
  required_version = ">= 1.8.4"
  required_providers {
    aws = ">= 5.51.1"
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  endpoint_map = {
    for def in var.lambda_endpoint_definitions : "${var.app_name}_${def.path_part}" => {
      path_part          = def.path_part
      allowed_headers    = def.allowed_headers
      method_definitions = def.method_definitions
    }
  }

  method_map = {
    for def in flatten([for endpoint in var.lambda_endpoint_definitions : [
      for method in endpoint.method_definitions : {
        path_part  = endpoint.path_part
        http_method = method.http_method
        command     = method.command
        timeout     = method.timeout
        memory_size = method.memory_size
      }
    ]]) : "${var.app_name}_${def.path_part}_${def.http_method}" => def
  }

  http_methods        = [for def in flatten([for endpoint in var.lambda_endpoint_definitions : endpoint.method_definitions]) : def.http_method]
  http_methods_string = join(",", local.http_methods)
}

# ========== ECR Repository ==========
resource "aws_ecr_repository" "ecr_repo" {
  name = "${var.app_name}-repo"
}

# ========== Lambda Policies ==========
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-lambda-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "lambda.amazonaws.com"
        }
        Effect : "Allow",
        Sid : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attachments" {
  count      = length(var.function_policies)
  policy_arn = element(var.function_policies, count.index)
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name = "${var.project_name}-cloudwatch"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-cloudwatch-policy-attachment" {
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# ========== API Endpoints ==========
resource "aws_api_gateway_rest_api" "api_gateway" {
  name = var.project_name
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "${var.app_name}-stage"
}

resource "aws_api_gateway_stage" "api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "${var.app_name}-stage"
}

# ========== API Gateway ==========
# ----- Endpoint -----
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = var.api_gateway.id
  parent_id   = var.api_gateway.root_resource_id
  path_part   = var.path_part
}

# ----- Options Method -----
resource "aws_api_gateway_method" "api_options_method" {
  rest_api_id   = var.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_options_integration" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration_response" "api_options_integration_response" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  status_code = aws_api_gateway_method_response.api_options_method_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = var.allowed_headers != null ? "'Content-Type,${var.allowed_headers}'" : "'Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'${local.http_methods_string},OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.url}'",
  }
}

resource "aws_api_gateway_method_response" "api_options_method_response" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  status_code = 200
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ========== Custom API URL ==========
data "aws_route53_zone" "domain_zone" {
  name = var.domain
}

resource "aws_api_gateway_domain_name" "api_gateway_domain_name" {
  depends_on = [aws_acm_certificate_validation.api_gateway_cert_validation]

  domain_name     = var.api_url
  certificate_arn = aws_acm_certificate.api_gateway_cert.arn
}

resource "aws_route53_record" "api_gateway_subdomain_A" {
  name    = var.api_url
  type    = "A"
  zone_id = data.aws_route53_zone.domain_zone.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_gateway_subdomain_AAAA" {
  name    = var.api_url
  type    = "AAAA"
  zone_id = data.aws_route53_zone.domain_zone.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_base_path_mapping" "api_gateway_base_path_mapping" {
  api_id      = aws_api_gateway.id
  stage_name  = aws_api_gateway_stage.api_gateway_stage.stage_name
  domain_name = aws_api_gateway_domain_name.api_gateway_domain_name.domain_name
}

# api-gateway / cloudfront certificates need to use the us-east-1 region
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

resource "aws_acm_certificate" "api_gateway_cert" {
  # api-gateway / cloudfront certificates need to use the us-east-1 region
  provider          = aws.virginia
  domain_name       = var.api_url
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "api_gateway_cert_validation" {
  # api-gateway / cloudfront certificates need to use the us-east-1 region
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.api_gateway_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.api_gateway_cert_validation : record.fqdn]
}

resource "aws_route53_record" "api_gateway_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_gateway_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  name    = each.value.name
  records = [each.value.record]
  type    = each.value.type

  zone_id = data.aws_route53_zone.domain_zone.zone_id
  ttl     = 60
}

# ========== Lambda ==========
# ----- Function -----
resource "aws_lambda_function" "lambda_function" {
  for_each = local.method_map

  function_name = each.key
  role          = var.lambda_role_arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.ecr_repo.repository_url}:${var.app_name}-${var.image_tag}"
  timeout       = each.value.timeout
  memory_size   = each.value.memory_size
  image_config {
    command = each.value.command
  }
  environment {
    variables = var.lambda_environment_variables
  }
}

resource "aws_lambda_permission" "lambda-permission" {
  for_each = local.endpoint_map

  statement_id  = "Allow${var.project_name}${each.value.path_part}Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway.execution_arn}/*"
}

# ========== API Gateway ==========
# ----- Method -----
resource "aws_api_gateway_method" "api_method" {
  for_each = local.method_map

  rest_api_id   = var.api_gateway.id
  resource_id   = var.api_resource_id
  http_method   = each.value.http_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_integration" {
  for_each = local.method_map

  rest_api_id             = var.api_gateway.id
  resource_id             = var.api_resource_id
  http_method             = aws_api_gateway_method.api_method[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function[each.key].invoke_arn
}

# ========== Cloudwatch ==========
resource "aws_cloudwatch_log_group" "LambdaFunctionLogGroup" {
  for_each = local.method_map

  name              = "/aws/lambda/${aws_lambda_function[each.key].function_name}"
  retention_in_days = 7
}
