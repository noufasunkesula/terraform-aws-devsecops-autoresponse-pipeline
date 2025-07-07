# ✅ SNS Topic and Subscription for Alerts
resource "aws_sns_topic" "soar_alerts_topic" {
  name = "soar-alerts-topic-<unique-suffix>"
}

resource "aws_sns_topic_subscription" "soar_alerts_email" {
  topic_arn = aws_sns_topic.soar_alerts_topic.arn
  protocol  = "email"
  endpoint  = "<your-email@example.com>"
}

########################################
# ✅ IAM Role for GuardDuty Lambda
resource "aws_iam_role" "guardduty_soar_lambda_role" {
  name = "GuardDutySOARLambdaRole-<unique-suffix>"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ✅ IAM Policy for GuardDuty Lambda
resource "aws_iam_role_policy" "guardduty_soar_lambda_policy" {
  name = "GuardDutySOARLambdaPolicy-<unique-suffix>"
  role = aws_iam_role.guardduty_soar_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ec2:CreateTags", "ec2:DescribeInstances"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = aws_sns_topic.soar_alerts_topic.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# ✅ GuardDuty Lambda Function
resource "aws_lambda_function" "guardduty_soar_lambda" {
  filename         = "${path.module}/lambda_soar/tag_suspicious_ec2.zip"
  function_name    = "GuardDutySOARLambda-<unique-suffix>"
  role             = aws_iam_role.guardduty_soar_lambda_role.arn
  handler          = "tag_suspicious_ec2.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/lambda_soar/tag_suspicious_ec2.zip")
}

# ✅ EventBridge Rule and Target for GuardDuty
resource "aws_cloudwatch_event_rule" "gd_unauthorizedaccess_rule" {
  name        = "GD-UnauthorizedAccess-Rule-<unique-suffix>"
  description = "Triggers Lambda on GuardDuty UnauthorizedAccess finding"

  event_pattern = jsonencode({
    source       = ["aws.guardduty"],
    "detail-type"  = ["GuardDuty Finding"],
    detail       = {
      type = ["UnauthorizedAccess:EC2/MaliciousIPCaller.Custom"]
    }
  })
}

resource "aws_cloudwatch_event_target" "gd_unauthorizedaccess_target" {
  rule      = aws_cloudwatch_event_rule.gd_unauthorizedaccess_rule.name
  target_id = "GD-UnauthorizedAccess-Target-<unique-suffix>"
  arn       = aws_lambda_function.guardduty_soar_lambda.arn
}

resource "aws_lambda_permission" "gd_unauthorizedaccess_lambda_permission" {
  statement_id  = "AllowGDUnauthorizedAccessInvokeLambda-<unique-suffix>"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty_soar_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.gd_unauthorizedaccess_rule.arn
}

########################################
# ✅ IAM Role for Inspector Lambda
resource "aws_iam_role" "inspector_lambda_role" {
  name = "InspectorLambdaRole-<unique-suffix>"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [ {
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ✅ IAM Policy for Inspector Lambda
resource "aws_iam_role_policy" "inspector_lambda_policy" {
  name = "InspectorLambdaPolicy-<unique-suffix>"
  role = aws_iam_role.inspector_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = aws_sns_topic.soar_alerts_topic.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# ✅ Inspector Lambda Function
resource "aws_lambda_function" "inspector_soar_lambda" {
  filename         = "${path.module}/lambda_soar/inspector_response_handler.zip"
  function_name    = "InspectorResponseHandler-<unique-suffix>"
  role             = aws_iam_role.inspector_lambda_role.arn
  handler          = "inspector_response_handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/lambda_soar/inspector_response_handler.zip")
}

# ✅ EventBridge Rule and Target for Inspector Critical Findings
resource "aws_cloudwatch_event_rule" "inspector_critical_rule" {
  name        = "Inspector-Critical-Rule-<unique-suffix>"
  description = "Triggers Lambda on Inspector Critical finding"

  event_pattern = jsonencode({
    source       = ["aws.inspector2"],
    "detail-type"  = ["Inspector2 Finding"],
    detail       = {
      severity = ["CRITICAL"]
    }
  })
}

resource "aws_cloudwatch_event_target" "inspector_critical_target" {
  rule      = aws_cloudwatch_event_rule.inspector_critical_rule.name
  target_id = "Inspector-Critical-Target-<unique-suffix>"
  arn       = aws_lambda_function.inspector_soar_lambda.arn
}

resource "aws_lambda_permission" "inspector_critical_lambda_permission" {
  statement_id  = "AllowInspectorCriticalInvokeLambda-<unique-suffix>"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inspector_soar_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inspector_critical_rule.arn
}

########################################
# ✅ CloudWatch Metric Filter & Alarm for Unauthorized API Calls
########################################

resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls_filter" {
  name           = "UnauthorizedAPICallsFilter"
  log_group_name = "<your-cloudtrail-log-group-name>"

  pattern = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICallCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls_alarm" {
  alarm_name          = "UnauthorizedAPICallsAlarm"
  alarm_description   = "Triggers on unauthorized API calls detected by CloudTrail"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.unauthorized_api_calls_filter.metric_transformation[0].name
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"

  alarm_actions = [
    aws_sns_topic.soar_alerts_topic.arn
  ]
}
