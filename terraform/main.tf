###############################################################################
# main.tf – all runtime resources: Location, IAM, Lambda, API Gateway v2
###############################################################################

########################
# 1. Geofence collection
########################
resource "aws_location_geofence_collection" "bet_regions" {
  collection_name = var.geofence_collection_name
  description     = "Jurisdictions where betting is legal (POC)"
  # Tags help you find resources quickly (Cost Explorer, grafana dashboards…)
  tags = { Project = "geofence-poc" }
}

########################
# 2. IAM for Lambda
########################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_geo_role" {
  name               = "geofence-poc-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = { Project = "geofence-poc" }
}

resource "aws_iam_role_policy" "lambda_geo_policy" {
  name = "geofence-poc-policy"
  role = aws_iam_role.lambda_geo_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # allow calls to BatchEvaluateGeofences on *this* collection only
      {
        Effect   = "Allow",
        Action   = ["geo:BatchEvaluateGeofences"],
        Resource = aws_location_geofence_collection.bet_regions.collection_arn
      },
      # CloudWatch Logs for debugging
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

########################
# 3. Lambda function
########################
# Built by ./lambda/build.sh → lambda/geo.zip
resource "aws_lambda_function" "geofence_checker" {
  function_name = "geofence-checker"
  role          = aws_iam_role.lambda_geo_role.arn
  handler       = "main"
  runtime       = "go1.x"
  filename      = "${path.module}/../lambda/geo.zip"
  timeout       = var.lambda_timeout_seconds
  memory_size   = 128

  environment {
    variables = {
      COLLECTION_NAME = aws_location_geofence_collection.bet_regions.collection_name
    }
  }

  lifecycle {
    ignore_changes = [filename] # So you can redeploy code via CI without tf plan noise
  }

  tags = { Project = "geofence-poc" }
}

########################
# 4. HTTP API Gateway v2
########################
resource "aws_apigatewayv2_api" "geo_api" {
  name          = "geofence-poc-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]  # tighten later
  }
  tags = { Project = "geofence-poc" }
}

resource "aws_apigatewayv2_integration" "geo_lambda" {
  api_id                 = aws_apigatewayv2_api.geo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.geofence_checker.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "geo_route" {
  api_id    = aws_apigatewayv2_api.geo_api.id
  route_key = "POST /check"
  target    = "integrations/${aws_apigatewayv2_integration.geo_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.geo_api.id
  name        = "$default"
  auto_deploy = true
  tags        = { Project = "geofence-poc" }
}

########################
# 5. Lambda × API permissions
########################
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geofence_checker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.geo_api.execution_arn}/*/*"
}
