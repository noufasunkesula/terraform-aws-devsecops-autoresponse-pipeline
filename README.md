## Terraform AWS DevSecOps ThreatResponse Pipeline 

An enterprise-grade, Terraform-powered DevSecOps framework for orchestrating real-time threat detection, policy enforcement, and automated remediation across AWS environments.

> Designed as a modular, event-driven SOAR-lite solution leveraging native AWS services, it enables scalable, auditable, and fully code-driven cloud security operations.

<p align="center">
  <img src="04-assets/terraform.jpg" alt="Terraform Logo" width="100"/>
  &nbsp;&nbsp;&nbsp;
  <img src="04-assets/aws-logo.png" alt="AWS Cloud Logo" width="130"/>
</p>


## Tech Stack & Security Focus
<!-- BADGES START -->
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-232F3E?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![DevSecOps](https://img.shields.io/badge/Security-DevSecOps-0B0?logo=datadog&logoColor=white)]()
[![SOAR](https://img.shields.io/badge/SOAR-Enabled-blueviolet)]()

[![EventBridge](https://img.shields.io/badge/Event%20Driven-EventBridge-purple?logo=amazon-aws)]()
[![GuardDuty](https://img.shields.io/badge/Threat%20Detection-GuardDuty-orange?logo=amazonaws)]()
[![AutoRemediation](https://img.shields.io/badge/Auto%20Response-Lambda%20%2B%20SNS-239B56)]()
<!-- BADGES END -->

## Services and AWS Tools Used
> Infrastructure-as-Code, Identity, Monitoring, Detection & Automated Response — all under one event-driven pipeline.</sup>

<table align="center">
<tr align="center">
  <td align="center">
    <img src="04-assets/terraform.jpg" width="50"/><br/>
    <sub><b>Terraform</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/iam-identity-center.png" width="50"/><br/>
    <sub><b>IAM</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/systems-manager.png" width="50"/><br/>
    <sub><b>SSM</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/virtual-private-cloud.png" width="50"/><br/>
    <sub><b>VPC</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/cloudshell.png" width="50"/><br/>
    <sub><b>CloudShell</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/aws-chatbot.jpg" width="50"/><br/>
    <sub><b>Chatbot</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/config.png" width="50"/><br/>
    <sub><b>Config</b></sub>
  </td>
</tr>

<tr align="center">
  <td align="center">
    <img src="04-assets/guardduty.png" width="50"/><br/>
    <sub><b>GuardDuty</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/inspector.png" width="50"/><br/>
    <sub><b>Inspector</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/lambda.png" width="50"/><br/>
    <sub><b>Lambda</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/eventbridge.png" width="50"/><br/>
    <sub><b>EventBridge</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/sns.png" width="50"/><br/>
    <sub><b>SNS</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/cloudwatch.png" width="50"/><br/>
    <sub><b>CloudWatch</b></sub>
  </td>
  <td align="center">
    <img src="04-assets/cloudtrail.png" width="50"/><br/>
    <sub><b>CloudTrail</b></sub>
  </td>
</tr>
</table>

## Architecture Overview

<p align="center">
  <img src="01-architecture/architecture-iac.jpg" width="90%" alt="AWS DevSecOps Terraform Architecture"/>
  <br/>
  <sub><i>Terraform-based SOAR-lite architecture: native AWS services for detection, alerting, and remediation.</i></sub>
</p>

## DevSecOps Execution Pipeline (Phase-wise Breakdown)

| Phase No. | Title                             | Implementation Steps                                                                                   |
|-----------|-----------------------------------|---------------------------------------------------------------------------------------------------------|
| Phase 1   | IAM Foundation                    | - Created IAM roles for Lambda, EC2 (SSM), and Inspector<br>- Applied scoped inline policies<br>- Enforced MFA via IAM policy<br>- Enabled IAM Access Analyzer to detect public access |
| Phase 2   | Secure Network Deployment         | - Provisioned custom VPC with public/private subnets<br>- Attached IGW and NAT Gateway<br>- Defined NACLs to block SSH/RDP<br>- Enabled VPC Flow Logs for traffic inspection |
| Phase 3   | Misconfiguration Detection & Remediation | - Enabled AWS Config with managed rule for S3PublicRead<br>- Created Lambda to delete public bucket policies<br>- Integrated GuardDuty and Inspector<br>- Automated remediation with Lambda functions |
| Phase 4   | Event-Driven SOAR-Lite            | - Configured EventBridge rules for GuardDuty and Inspector findings<br>- Linked each rule to corresponding Lambda handler<br>- Published alerts and actions to SNS topics |
| Phase 5   | Real-Time Alerts                  | - Set up SNS topics with email and Slack subscriptions<br>- Integrated AWS Chatbot with Slack workspace<br>- Pushed alerts from Lambda/EventBridge via SNS |
| Phase 6   | CloudWatch Intrusion Detection    | - Enabled CloudTrail logging<br>- Created Metric Filter for Unauthorized API calls<br>- Set CloudWatch Alarm for suspicious activity<br>- Triggered SNS alerts on alarm breach |

## Security Principles Applied

- **Least Privilege:** All IAM roles scoped to specific service actions.
- **Event-Driven Architecture:** Real-time response without polling.
- **Zero Trust Network:** No SSH/RDP access to EC2; VPC NACLs block direct ingress.
- **Auditable Remediation:** Config + Lambda logs all actions to CloudWatch.

## Repo Structure
<details>
  <summary><b>Repo Structure</b></summary>

```plaintext
terraform-aws-devsecops-autoresponse-pipeline/
├── 01-architecture/
│   └── architecture-iac.jpg
│
├── 02-scripts/
│   ├── phase-1-aws-config-s3-auto-remediation.tf
│   ├── phase-2-secure-vpc-private-ec2-ssm.tf
│   ├── phase-3-eventbridge-remediation-on-config.tf
│   ├── phase-4-6-soar-lite-gd-inspector-cloudwatch.tf
│   └── phase-5-chatbot-slack-alerts.txt
│
├── 03-screenshots/
│   ├── phase-1-aws-config-s3-auto-remediation/
│   ├── phase-2-secure-vpc-private-ec2-ssm/
│   ├── phase-3-eventbridge-remediation-on-config/
│   ├── phase-4-soar-lite-guardduty-inspector/
│   ├── phase-5-chatbot-slack-alerts/
│   └── phase-6-cloudwatch-unauthorized-api-alarms/
│
├── 04-assets/
│   ├── aws-chatbot.jpg
│   ├── cloudshell.png
│   ├── cloudtrail.png
│   ├── cloudwatch.png
│   ├── config.png
│   ├── eventbridge.png
│   ├── guardduty.png
│   ├── iam-identity-center.png
│   ├── inspector.png
│   ├── lambda.png
│   ├── sns.png
│   ├── systems-manager.png
│   ├── terraform.jpg
│   └── virtual-private-cloud.png

```
</details>

## Built By

Noufa Sunkesula

Email ID: noufasunkesula@gmail.com

Contact: +91 8106859686

Feel Free To Reach Out!
