terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  }

# https://aws.amazon.com/blogs/security/how-to-detect-and-automatically-revoke-unintended-iam-access-with-amazon-cloudwatch-events/
# Create an IAM policy that will deny access to any IAM API
resource "aws_iam_policy" "denyiam" {
  name        = "DenyIAMAccess"
  path        = "/"
  description = "Policy that will deny access to any IAM API"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:*",
        ]
        Effect   = "Deny"
        Resource = "*"
      },
    ]
  })
}

# https://aws.amazon.com/blogs/security/how-to-detect-and-automatically-revoke-unintended-iam-access-with-amazon-cloudwatch-events/
# Create an IAM role for the Lambda function
resource "aws_iam_role" "role" {
  name = "RoleThatAllowsIAMAndLogsForLambda"

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

resource "aws_iam_policy" "lambdapolicy" {
  name        = "AllowIAMForLambdaPolicy"
  description = "Allow Lambda to perform IAM actions while Lambda function is being executed"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iam:AttachUserPolicy",
        "iam:ListGroupsForUser",
        "iam:PutUserPolicy",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.lambdapolicy.arn
}

# https://aws.amazon.com/blogs/security/how-to-detect-and-automatically-revoke-unintended-iam-access-with-amazon-cloudwatch-events/
# Create the Lambda function
resource "aws_lambda_function" "logging" {
  filename      = "RevokeIAMAccess.zip"
  function_name = "RevokeIAMAccess"
  handler       = "exports.handler"
  role          = aws_iam_role.default.arn
  runtime       = "nodejs14.x"
}
