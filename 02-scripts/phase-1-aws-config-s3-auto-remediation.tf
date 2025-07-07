provider "aws" {
  region  = var.aws_region          # Define in variables.tf or tfvars
  profile = var.aws_profile         # Define in variables.tf or tfvars
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "aws_profile" {
  default = "your-aws-profile"
}

variable "bucket_prefix" {
  default = "your-bucket-prefix"
}

variable "lambda_zip_file" {
  default = "fix_s3_public_access.zip"
}

# Random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# ✅ S3 bucket to store AWS Config logs
resource "aws_s3_bucket" "config_logs_bucket" {
  bucket        = "${var.bucket_prefix}-config-logs-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name = "AWS-Config-Logs"
  }
}

# ✅ Bucket policy for AWS Config to write logs
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

# ✅ IAM Role for AWS Config
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

# ✅ Inline policy for AWS Config permissions
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

resource "aws_s3_bucket" "non_compliant_bucket" {
  bucket        = "${var.bucket_prefix}-noncompliant-public-${random_string.suffix.result}"
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

resource "aws_iam_role" "lambda_role" {
  name = "FixS3PublicAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_lambda_function" "fix_s3_public_access" {
  function_name = "FixS3PublicAccess"
  role          = aws_iam_role.lambda_role.arn
  handler       = "fix_s3_public_access.lambda_handler"
  runtime       = "python3.9"

  filename         = "${path.module}/${var.lambda_zip_file}"
  source_code_hash = filebase64sha256("${path.module}/${var.lambda_zip_file}")
}

resource "aws_config_remediation_configuration" "fix_s3_public_access" {
  config_rule_name = aws_config_config_rule.s3_bucket_no_public_read.name
  target_type      = "AWS::Lambda::Function"
  target_id        = aws_lambda_function.fix_s3_public_access.arn
  resource_type    = "AWS::S3::Bucket"
  automatic        = true

  depends_on = [
    aws_lambda_function.fix_s3_public_access,
    aws_config_config_rule.s3_bucket_no_public_read
  ]
}
