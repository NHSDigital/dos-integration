resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = var.waf_log_group_name
  retention_in_days = "30"
  kms_key_id        = aws_kms_key.signing_key.arn
}


resource "aws_wafv2_web_acl" "di_endpoint_waf" {
  count = var.waf_enabled ? 1 : 0
  #checkov:skip=CKV_AWS_192
  name        = var.waf_acl_name
  description = "WAF ACL for the DoS Integration API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = var.waf_ip_allow_list_rule_name
    priority = 1

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.di_endpoint_ip_set[0].arn
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_ip_allow_list_rule_name
      sampled_requests_enabled   = true
    }
  }

  rule {
    name = var.waf_rate_based_rule_name
    action {
      block {}
    }
    priority = 2

    statement {
      rate_based_statement {
        limit = 150000 # 500 requests per second
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_rate_based_rule_name
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = var.waf_custom_sqli_rule_name
    priority = 3

    action {
      count {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        sensitivity_level = "HIGH"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      metric_name                = var.waf_custom_sqli_rule_name
      cloudwatch_metrics_enabled = true
    }
  }

  rule {
    name     = var.waf_non_gb_rule_name
    priority = 4
    action {
      block {}
    }
    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["GB"]
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_non_gb_rule_name
      sampled_requests_enabled   = true
    }
  }



  rule {
    name     = var.waf_aws_known_bad_inputs_rule_name
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_aws_known_bad_inputs_rule_name
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = var.waf_aws_sqli_rule_name
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_aws_sqli_rule_name
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = var.waf_ip_reputation_list_rule_name
    priority = 7

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_ip_reputation_list_rule_name
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = var.waf_aws_common_rule_name
    priority = 8

    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "NoUserAgent_HEADER"
        }

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.waf_aws_common_rule_name
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.waf_acl_name
    sampled_requests_enabled   = true
  }

  depends_on = [
    aws_wafv2_ip_set.di_endpoint_ip_set[0]
  ]
}

resource "aws_wafv2_ip_set" "di_endpoint_ip_set" {
  count              = var.waf_enabled ? 1 : 0
  name               = var.waf_ip_set_name
  description        = "IP set for the DoS Integration API Gateway"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = toset(local.ip_addresses)
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_acl_logging_configuration" {
  count                   = var.waf_enabled ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.di_endpoint_waf[0].arn
}

resource "aws_wafv2_web_acl_association" "di_endpoint_waf_association" {
  count        = var.waf_enabled ? 1 : 0
  resource_arn = aws_api_gateway_stage.di_endpoint_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.di_endpoint_waf[0].arn
  depends_on = [
    aws_api_gateway_stage.di_endpoint_stage,
    aws_wafv2_web_acl.di_endpoint_waf[0]
  ]

}
