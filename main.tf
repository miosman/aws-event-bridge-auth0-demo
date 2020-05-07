provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eventbridge-log-publishing-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/*:*"]

    principals {
      identifiers = ["events.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_group" "user-events-log-group" {
  name = "/aws/events/auth0-user-events"
}

resource "aws_dynamodb_table" "users-table" {
  name         = "users-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_iam_role" "update-user-function-role" {
  name = "update-user-function-role"
  path = "/service-role/"

  assume_role_policy = file("${path.root}/iam/update-user-function-role.json")
}

resource "aws_iam_policy" "update-user-function-policy" {
  name   = "update-user-function-policy"
  policy = templatefile("${path.root}/iam/update-user-function-policy.json",{aws_region = var.aws_region, aws_account_id = data.aws_caller_identity.current.account_id, table_name = aws_dynamodb_table.users-table.name})
}

resource "aws_iam_role_policy_attachment" "policy-attachment" {
  role       = aws_iam_role.update-user-function-role.name
  policy_arn = aws_iam_policy.update-user-function-policy.arn
}

resource "aws_lambda_function" "update-user-function" {
  filename      = "lambda/update-user-function/update_user.zip"
  function_name = "update-user-function"
  role          = aws_iam_role.update-user-function-role.arn
  handler       = "update_user.handler"

  source_code_hash = filebase64sha256("lambda/update-user-function/update_user.zip")

  runtime = "python3.8"

  depends_on = [aws_iam_role_policy_attachment.policy-attachment]
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge-log-publishing-policy" {
  policy_document = data.aws_iam_policy_document.eventbridge-log-publishing-policy.json
  policy_name     = "eventbridge-log-publishing-policy"
}

resource "aws_cloudformation_stack" "user-events-rule" {
  name = "user-events-rule"

  parameters = {
    EventBusName           = var.auth0_event_bus
    UpdateUserFunctionArn  = aws_lambda_function.update-user-function.arn
    UpdateUserFunctionName = aws_lambda_function.update-user-function.id
    UserEventsLogGroupArn  = aws_cloudwatch_log_group.user-events-log-group.arn
  }

  template_body = file("${path.root}/cloudformation/auth0-event-rule.yaml")
}

