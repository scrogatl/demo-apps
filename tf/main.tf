provider "aws" {
  region = var.region
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda_exec_policy"
  description = "IAM policy for Lambda execution role"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_exec.name
}

resource "aws_dynamodb_table" "ruby_lambda_dynamodb_table" {
  name             = "ruby-lambda-dynamodb-table"
  billing_mode     = "PROVISIONED"
  read_capacity    = 2
  write_capacity   = 2
  hash_key         = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_api_gateway_rest_api" "ruby_lambda_api_gateway" {
  name        = "ruby-lambda-api-gateway"
  description = "API Gateway for serverless functions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "resource_id" {
  rest_api_id = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.root_resource_id
  path_part   = "{id}"
}

data "archive_file" "get_all_items_zip" {
  type        = "zip"
  source_file = "../web/handlers/get_all_items.rb"
  output_path = "../web/handlers/get_all_items.zip"
}

resource "aws_lambda_function" "get_all_items_function" {
  filename         = "../web/handlers/get_all_items.zip"
  function_name    = "GetAllItemsFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "../web/handlers/get_all_items.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      RUBY_LAMBDA_TABLE = aws_dynamodb_table.ruby_lambda_dynamodb_table.name
    }
  }

  depends_on = [ data.archive_file.get_all_items_zip ]
}

resource "aws_api_gateway_method" "get_all_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  resource_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

data "archive_file" "create_item_zip" {
  type        = "zip"
  source_file = "../web/handlers/create_item.rb"
  output_path = "../web/handlers/create_item.zip"
}

resource "aws_lambda_function" "create_item_function" {
  filename         = "../web/handlers/create_item.zip"
  function_name    = "CreateItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "../web/handlers/create_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      RUBY_LAMBDA_TABLE = aws_dynamodb_table.ruby_lambda_dynamodb_table.name
    }
  }

  depends_on = [ data.archive_file.create_item_zip ]
}

resource "aws_api_gateway_method" "create_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  resource_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

data "archive_file" "get_item_by_id_zip" {
  type        = "zip"
  source_file = "../web/handlers/get_item_by_id.rb"
  output_path = "../web/handlers/get_item_by_id.zip"
}

resource "aws_lambda_function" "get_item_by_id_function" {
  filename         = "../web/handlers/get_item_by_id.zip"
  function_name    = "GetItemByIdFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "../web/handlers/get_item_by_id.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      RUBY_LAMBDA_TABLE = aws_dynamodb_table.ruby_lambda_dynamodb_table.name
    }
  }

  depends_on = [ data.archive_file.get_item_by_id_zip ]
}

resource "aws_api_gateway_method" "get_item_by_id_method" {
  rest_api_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "GET"
  authorization = "NONE"
}

data "archive_file" "delete_item_zip" {
  type        = "zip"
  source_file = "../web/handlers/delete_item.rb"
  output_path = "../web/handlers/delete_item.zip"
}

resource "aws_lambda_function" "delete_item_function" {
  filename         = "../web/handlers/delete_item.zip"
  function_name    = "DeleteItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "../web/handlers/delete_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      RUBY_LAMBDA_TABLE = aws_dynamodb_table.ruby_lambda_dynamodb_table.name
    }
  }

  depends_on = [ data.archive_file.delete_item_zip ]
}

resource "aws_api_gateway_method" "delete_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

data "archive_file" "update_item_zip" {
  type        = "zip"
  source_file = "../web/handlers/update_item.rb"
  output_path = "../web/handlers/update_item.zip"
}

resource "aws_lambda_function" "update_item_function" {
  filename         = "../web/handlers/update_item.zip"
  function_name    = "UpdateItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "../web/handlers/update_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      RUBY_LAMBDA_TABLE = aws_dynamodb_table.ruby_lambda_dynamodb_table.name
    }
  }

  depends_on = [ data.archive_file.update_item_zip ]
}

resource "aws_api_gateway_method" "update_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.ruby_lambda_api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "PUT"
  authorization = "NONE"
}
