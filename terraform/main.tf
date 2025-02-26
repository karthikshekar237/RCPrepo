terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.76"
    }
  }
  # Optional: Configure remote state backend (update with your bucket details)
  backend "s3" {
    bucket         = "terraformstateforrcp"
    key            = "rcp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraformrcplocktable"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_organizations_organization" "org" {
  feature_set          = "ALL"
  enabled_policy_types = [
    "AISERVICES_OPT_OUT_POLICY",
    "SERVICE_CONTROL_POLICY",
    "RESOURCE_CONTROL_POLICY",
  ]
}

data "aws_iam_policy_document" "rcp1" {
  statement {
    effect = "Deny"

    actions = [
      "s3:*",
      "sqs:*",
      "kms:*",
      "secretsmanager:*",
      "sts:*",
    ]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEqualsIfExists"
      variable = "aws:SourceOrgID"
      values   = [aws_organizations_organization.org.id]
    }

    condition {
      test     = "Null"
      variable = "aws:SourceAccount"
      values   = ["false"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["true"]
    }
  }
}

resource "aws_organizations_policy" "rcp1" {
  name    = "rcp1"
  content = data.aws_iam_policy_document.rcp1.minified_json
  type    = "RESOURCE_CONTROL_POLICY"
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "dev"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "rcp1_dev" {
  policy_id = aws_organizations_policy.rcp1.id
  target_id = aws_organizations_organizational_unit.dev.id
}
