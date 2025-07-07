provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "aws_profile" {
  default = "default"
}

variable "ami_id" {
  default = "ami-xxxxxxxxxxxxxxxxx"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

##############################
# ✅ AWS CONFIG LOGGING SETUP
##############################

resource "aws_s3_bucket" "config_logs_bucket" {
  bucket        = "config-logs-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name = "AWS-Config-Logs"
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_logs_bucket.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid      = "AWSConfigBucketPermissionsCheck",
        Effect   = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.config_logs_bucket.arn
      },
      {
        Sid      = "AWSConfigBucketDelivery",
        Effect   = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.config_logs_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "config_role" {
  name = "AWSConfigRole"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "config_inline_policy" {
  name = "AWSConfigPolicy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetBucketAcl"
        ],
        Resource = [
          aws_s3_bucket.config_logs_bucket.arn,
          "${aws_s3_bucket.config_logs_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "config:*",
          "s3:Get*",
          "s3:List*",
          "ec2:Describe*",
          "iam:Get*",
          "iam:List*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "default" {
  name     = "default"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "default" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config_logs_bucket.bucket

  depends_on = [
    aws_config_configuration_recorder.default,
    aws_s3_bucket_policy.config_bucket_policy
  ]
}

resource "aws_config_configuration_recorder_status" "start" {
  name       = aws_config_configuration_recorder.default.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.default]
}

resource "aws_config_config_rule" "s3_bucket_no_public_read" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.start]
}

########################################
# ✅ TEST BUCKET (Non-compliant)
########################################

resource "aws_s3_bucket" "non_compliant_bucket" {
  bucket        = "noncompliant-public-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name = "Test-NonCompliant"
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.non_compliant_bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.non_compliant_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "public_acl" {
  bucket = aws_s3_bucket.non_compliant_bucket.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_public_access_block.block,
    aws_s3_bucket_ownership_controls.ownership
  ]
}

########################################
# ✅ LAMBDA REMEDIATION FUNCTION
########################################

resource "aws_iam_role" "fix_s3_lambda_role" {
  name = "FixS3PublicAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "fix_s3_lambda_policy" {
  name = "FixS3PublicAccessPolicy"
  role = aws_iam_role.fix_s3_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "fix_s3_lambda" {
  filename         = "${path.module}/lambda/fix_s3_public_access.zip"
  function_name    = "FixS3PublicAccess"
  role             = aws_iam_role.fix_s3_lambda_role.arn
  handler          = "fix_s3_public_access.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/lambda/fix_s3_public_access.zip")
}

resource "aws_cloudwatch_event_rule" "trigger_fix_s3_lambda" {
  name        = "ConfigTriggerFixS3"
  description = "Trigger Lambda when AWS Config finds public-read violation"
  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "configRuleName": ["s3-bucket-public-read-prohibited"],
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_lambda" {
  rule      = aws_cloudwatch_event_rule.trigger_fix_s3_lambda.name
  target_id = "FixS3Lambda"
  arn       = aws_lambda_function.fix_s3_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fix_s3_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger_fix_s3_lambda.arn
}
