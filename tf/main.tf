provider "aws" {
  region = "eu-west-1"  # Change this to your desired region
}

resource "aws_dynamodb_table" "sample_table" {
  name             = "SampleTable"
  billing_mode     = "PROVISIONED"
  read_capacity    = 2
  write_capacity   = 2
  hash_key         = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "SampleAPI"
  description = "API Gateway for serverless functions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "resource_id" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "{id}"
}

resource "aws_lambda_function" "get_all_items_function" {
  filename         = "src/handlers/get_all_items.zip"
  function_name    = "GetAllItemsFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "src/handlers/get_all_items.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      SAMPLE_TABLE = aws_dynamodb_table.sample_table.name
    }
  }
}

resource "aws_api_gateway_method" "get_all_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_lambda_function" "create_item_function" {
  filename         = "src/handlers/create_item.zip"
  function_name    = "CreateItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "src/handlers/create_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      SAMPLE_TABLE = aws_dynamodb_table.sample_table.name
    }
  }
}

resource "aws_api_gateway_method" "create_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_lambda_function" "get_item_by_id_function" {
  filename         = "src/handlers/get_item_by_id.zip"
  function_name    = "GetItemByIdFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "src/handlers/get_item_by_id.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      SAMPLE_TABLE = aws_dynamodb_table.sample_table.name
    }
  }
}

resource "aws_api_gateway_method" "get_item_by_id_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_lambda_function" "delete_item_function" {
  filename         = "src/handlers/delete_item.zip"
  function_name    = "DeleteItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "src/handlers/delete_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      SAMPLE_TABLE = aws_dynamodb_table.sample_table.name
    }
  }
}

resource "aws_api_gateway_method" "delete_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_lambda_function" "update_item_function" {
  filename         = "src/handlers/update_item.zip"
  function_name    = "UpdateItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "src/handlers/update_item.handler"
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = 3

  environment {
    variables = {
      SAMPLE_TABLE = aws_dynamodb_table.sample_table.name
    }
  }
}

resource "aws_api_gateway_method" "update_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.resource_id.id
  http_method   = "PUT"
  authorization = "NONE"
}
