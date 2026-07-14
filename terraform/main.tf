# DynamoDB Table
resource "aws_dynamodb_table" "books" {
  name         = "BookInventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "book_id"

  attribute {
    name = "book_id"
    type = "S"
  }
}

# IAM Role for Lambda 
resource "aws_iam_role" "lambda_role" {
  name = "book-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Zip Archive of your Python Code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../lambda.zip"
}

# Lambda Function
resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "BookInventoryHandler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambdafunc.handler"
  runtime          = "python3.11"

  environment {
    variables = {
      DYNAMODB_TABLE   = aws_dynamodb_table.books.name
      AWS_ENDPOINT_URL = "http://localhost:4566"
    }
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "BookInventoryAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "books_collection_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /books"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "books_item_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /books/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

output "http_api_id" {
  description = "The randomized ID of the local API Gateway"
  value       = aws_apigatewayv2_api.http_api.id
}