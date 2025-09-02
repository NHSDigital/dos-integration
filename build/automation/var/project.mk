ORG_NAME = NHSDigital
PROGRAMME = uec
PROJECT_GROUP = uec/dos
PROJECT_GROUP_SHORT = uec-dos
PROJECT_NAME = integration
PROJECT_NAME_SHORT = int
PROJECT_DISPLAY_NAME = DoS Integration
PROJECT_ID = $(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)
TEAM_ID = dos-integration

ROLE_PREFIX = UECDoSInt
PROJECT_TAG = $(PROJECT_NAME)
SERVICE_TAG = $(PROJECT_GROUP_SHORT)
SERVICE_TAG_COMMON = texas

PROJECT_TECH_STACK_LIST = python,terraform
PROJECT_LAMBDAS_LIST = $(CHANGE_EVENT_DLQ_HANDLER),$(DOS_DB_HANDLER),$(DOS_DB_UPDATE_DLQ_HANDLER),$(EVENT_REPLAY),$(INGEST_CHANGE_EVENT),$(SEND_EMAIL),$(SERVICE_MATCHER),$(SERVICE_SYNC),$(SLACK_MESSENGER),$(QUALITY_CHECKER)

AWS_VPC_NAME = lk8s-$(AWS_ACCOUNT_NAME).texasplatform.uk
TF_VAR_aws_vpc_name = $(AWS_VPC_NAME)
SLS_AWS_MONITORING_FREQUENCY = 500
TF_VAR_service_name = $(PROJECT_ID)
TF_VAR_team_id = $(TEAM_ID)
TF_VAR_programme = $(PROGRAMME)
TF_VAR_environment = $(ENVIRONMENT)
TF_VAR_aws_account_name = $(AWS_ACCOUNT_NAME)
TF_VAR_deployment_secrets = $(DEPLOYMENT_SECRETS)
PROJECT_DEPLOYMENT_SECRETS = $(DEPLOYMENT_SECRETS)
TF_VAR_github_owner = NHSDigital
TF_VAR_github_repo = dos-integration
PARALLEL_TEST_COUNT := $(or $(PARALLEL_TEST_COUNT), auto)

UNACCEPTABLE_VULNERABILITY_LEVELS = CRITICAL,HIGH,MEDIUM

BLUE_GREEN_ENVIRONMENT := $(or $(BLUE_GREEN_ENVIRONMENT), $(ENVIRONMENT))
SHARED_ENVIRONMENT := $(or $(SHARED_ENVIRONMENT), $(ENVIRONMENT))
TF_VAR_blue_green_environment := $(BLUE_GREEN_ENVIRONMENT)
TF_VAR_shared_environment := $(SHARED_ENVIRONMENT)

# Development and Deployment Tools
TF_VAR_cicd_blue_green_deployment_pipeline_artefact_bucket := $(PROJECT_ID)-$(ENVIRONMENT)-cicd-blue-green-deployment-artefacts
TF_VAR_cicd_shared_resoures_deployment_pipeline_artefact_bucket := $(PROJECT_ID)-$(ENVIRONMENT)-cicd-shared-resources-deployment-artefacts
TF_VAR_development_pipeline_branch_name := develop
TF_VAR_cicd_blue_green_deployment_pipeline_name := $(PROJECT_ID)-$(ENVIRONMENT)-cicd-blue-green-deployment-pipeline
TF_VAR_cicd_shared_resources_deployment_pipeline_name := $(PROJECT_ID)-$(ENVIRONMENT)-cicd-shared-resources-deployment-pipeline
TF_VAR_blue_green_deployment_new_version_parameter_name := $(PROJECT_ID)-$(ENVIRONMENT)-blue-green-deployment-new-version
TF_VAR_development_tools_encryption_key_alias := $(PROJECT_ID)-$(ENVIRONMENT)-development-tools-encryption-key
TF_VAR_github_url := https://github.com/NHSDigital/dos-integration.git
TF_VAR_pipeline_topic_name := $(PROJECT_ID)-$(ENVIRONMENT)-pipeline-topic
TF_VAR_pipeline_notification_name := $(PROJECT_ID)-$(ENVIRONMENT)-pipeline-notification
TF_VAR_cicd_blue_green_deployment_pipeline_nofitication_name := $(PROJECT_ID)-$(ENVIRONMENT)-blue-green-pipeline-notification
TF_VAR_cicd_shared_resources_deployment_pipeline_nofitication_name := $(PROJECT_ID)-$(ENVIRONMENT)-shared-resources-pipeline-notification
TF_VAR_cicd_blue_green_deployment_pipeline_eventbridge_rule_name := $(PROJECT_ID)-$(ENVIRONMENT)-trigger-blue-green-pipeline
TF_VAR_cicd_shared_resources_deployment_pipeline_eventbridge_rule_name := $(PROJECT_ID)-$(ENVIRONMENT)-trigger-shared-resources-pipeline
TF_VAR_pipeline_chatbot_channel := $(PROJECT_ID)-cicd-slk-channel
TF_VAR_nightly_rule_name := $(PROJECT_ID)-$(ENVIRONMENT)-performance-pipeline-nightly-rule

# ==============================================================================
# Infrastructure variables (Terraform, etc)
# -------------------------------
# Common variables for all environments

# General
TF_VAR_docker_registry := $(DOCKER_REGISTRY)

# Tags
SERVICE_CATEGORY_KEY := DI_SERVICE_CATEGORY
DATA_CLASSIFICATION_KEY := DI_DATA_CLASSIFICATION
DISTRIBUTION_LIST_KEY := DI_DISTRIBUTION_LIST

# Global region
TF_VAR_route53_health_check_alarm_region = us-east-1

# Kinisis Firehose (Splunk Logs)
TF_VAR_dos_integration_firehose := $(PROJECT_ID)-cw-logs-firehose
TF_VAR_di_firehose_role := $(PROJECT_ID)_cw_firehose_access_role
TF_VAR_dos_firehose := dos-cw-logs-firehose
TF_VAR_dos_firehose_role := dos_cw_firehose_access_role

CHANGE_EVENT_DLQ_HANDLER := change-event-dlq-handler
DOS_DB_HANDLER := dos-db-handler
DOS_DB_UPDATE_DLQ_HANDLER := dos-db-update-dlq-handler
EVENT_REPLAY := event-replay
INGEST_CHANGE_EVENT := ingest-change-event
SEND_EMAIL := send-email
SERVICE_MATCHER := service-matcher
SERVICE_SYNC := service-sync
SLACK_MESSENGER := slack-messenger
QUALITY_CHECKER := quality-checker

# -------------------------------
# SHARED ENVIRONMENT VARIABLES

# DI Endpoint API Gateway API Keys
TF_VAR_api_gateway_api_key_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-api-key
TF_VAR_nhs_uk_api_key_key := NHS_UK_API_KEY
API_KEY_SECRET := $(TF_VAR_api_gateway_api_key_name)
NHS_UK_API_KEY := $(TF_VAR_nhs_uk_api_key_key)

# DI Endpoint API Gateway Route53 & SQS
TF_VAR_dos_integration_sub_domain_name := $(PROGRAMME)-$(TEAM_ID)-$(SHARED_ENVIRONMENT)
DOS_INTEGRATION_URL = $(TF_VAR_dos_integration_sub_domain_name).$(TEXAS_HOSTED_ZONE)/v1/change-event
HTTPS_DOS_INTEGRATION_URL = https://$(DOS_INTEGRATION_URL)
TF_VAR_di_endpoint_api_gateway_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-di-endpoint
TF_VAR_di_endpoint_api_gateway_stage := $(SHARED_ENVIRONMENT)

# SQS Queues
TF_VAR_change_event_queue := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-change-event-queue.fifo
TF_VAR_change_event_dlq := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-change-event-dead-letter-queue.fifo

# Dynamodb
TF_VAR_change_events_table_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-change-events
DYNAMO_DB_TABLE := $(TF_VAR_change_events_table_name)
TF_VAR_ddb_delete_protection :=$(DDB_DELETE_PROTECTION)

# Log Group Filters for Firehose
TF_VAR_change_event_gateway_subscription_filter_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-change-event-api-gateway-cw-logs-firehose-subscription

# KMS
TF_VAR_signing_key_alias := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-signing-key-alias
TF_VAR_route53_health_check_alarm_region_signing_key_alias := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-alarm-region-signing-key-alias

# S3
SEND_EMAIL_BUCKET_NAME := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-send-email-bucket
TF_VAR_send_email_bucket_name := $(SEND_EMAIL_BUCKET_NAME)
TF_VAR_logs_bucket_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-logs-bucket

# Cloudwatch monitoring dashboard
TF_VAR_shared_resources_sns_topic_app_alerts_for_slack_default_region := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-shared-resources-topic-app-alerts-for-slack-default-region
TF_VAR_shared_resources_sns_topic_app_alerts_for_slack_route53_health_check_alarm_region := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-shared-resources-topic-app-alerts-for-slack-route53-health-check-alarm-region

# WAF
TF_VAR_waf_enabled := $(WAF_ENABLED)
TF_VAR_waf_acl_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-acl
TF_VAR_waf_log_group_name := aws-waf-logs-$(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-log-group
TF_VAR_waf_log_subscription_filter_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-log-subscription-filter
TF_VAR_waf_ip_set_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-ip-set

TF_VAR_waf_aws_common_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-aws-common-rule
TF_VAR_waf_ip_reputation_list_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-ip-reputation-list-rule
TF_VAR_waf_non_gb_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-non-gb-rule
TF_VAR_waf_ip_allow_list_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-ip-allow-list-rule
TF_VAR_waf_rate_based_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-rate-based-rule
TF_VAR_waf_aws_known_bad_inputs_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-aws-known-bad-inputs-rule
TF_VAR_waf_aws_sqli_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-aws-sqli-rule
TF_VAR_waf_custom_sqli_rule_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-waf-custom-sqli-rule

# -------------------------------
# BLUE/GREEN ENVIRONMENT VARIABLES

# Lambda Security Group
TF_VAR_lambda_security_group_name := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-lambda-sg
TF_VAR_db_sg_name := $(DB_SG_NAME)

# SQS Queues
TF_VAR_holding_queue := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-holding-queue.fifo
TF_VAR_update_request_queue := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-update-request-queue.fifo
TF_VAR_holding_queue_dlq := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-holding-queue-dead-letter-queue.fifo
TF_VAR_update_request_dlq := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-update-request-dead-letter-queue.fifo

# Docker Image Names
TF_VAR_change_event_dlq_handler := $(CHANGE_EVENT_DLQ_HANDLER)
TF_VAR_dos_db_handler := $(DOS_DB_HANDLER)
TF_VAR_dos_db_update_dlq_handler := $(DOS_DB_UPDATE_DLQ_HANDLER)
TF_VAR_event_replay := $(EVENT_REPLAY)
TF_VAR_ingest_change_event := $(INGEST_CHANGE_EVENT)
TF_VAR_send_email := $(SEND_EMAIL)
TF_VAR_service_matcher := $(SERVICE_MATCHER)
TF_VAR_service_sync := $(SERVICE_SYNC)
TF_VAR_slack_messenger := $(SLACK_MESSENGER)
TF_VAR_quality_checker := $(QUALITY_CHECKER)

# Lambda names
CHANGE_EVENT_DLQ_HANDLER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(CHANGE_EVENT_DLQ_HANDLER)
DOS_DB_HANDLER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(DOS_DB_HANDLER)
DOS_DB_UPDATE_DLQ_HANDLER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(DOS_DB_UPDATE_DLQ_HANDLER)
EVENT_REPLAY_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(EVENT_REPLAY)
INGEST_CHANGE_EVENT_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(INGEST_CHANGE_EVENT)
SEND_EMAIL_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(SEND_EMAIL)
SERVICE_MATCHER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(SERVICE_MATCHER)
SERVICE_SYNC_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(SERVICE_SYNC)
SLACK_MESSENGER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(SLACK_MESSENGER)
QUALITY_CHECKER_LAMBDA := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-$(QUALITY_CHECKER)

TF_VAR_change_event_dlq_handler_lambda := $(CHANGE_EVENT_DLQ_HANDLER_LAMBDA)
TF_VAR_dos_db_handler_lambda := $(DOS_DB_HANDLER_LAMBDA)
TF_VAR_dos_db_update_dlq_handler_lambda := $(DOS_DB_UPDATE_DLQ_HANDLER_LAMBDA)
TF_VAR_event_replay_lambda := $(EVENT_REPLAY_LAMBDA)
TF_VAR_ingest_change_event_lambda := $(INGEST_CHANGE_EVENT_LAMBDA)
TF_VAR_send_email_lambda := $(SEND_EMAIL_LAMBDA)
TF_VAR_service_matcher_lambda := $(SERVICE_MATCHER_LAMBDA)
TF_VAR_service_sync_lambda := $(SERVICE_SYNC_LAMBDA)
TF_VAR_slack_messenger_lambda := $(SLACK_MESSENGER_LAMBDA)
TF_VAR_quality_checker_lambda := $(QUALITY_CHECKER_LAMBDA)

# Lambda Versions
TF_VAR_change_event_dlq_handler_version := $(or $(CHANGE_EVENT_DLQ_HANDLER_VERSION), $(VERSION))
TF_VAR_dos_db_handler_version := $(or $(DOS_DB_HANDLER_VERSION), $(VERSION))
TF_VAR_dos_db_update_dlq_handler_version := $(or $(DOS_DB_UPDATE_DLQ_HANDLER_VERSION), $(VERSION))
TF_VAR_event_replay_version := $(or $(EVENT_REPLAY_VERSION), $(VERSION))
TF_VAR_ingest_change_event_version := $(or $(INGEST_CHANGE_EVENT_VERSION), $(VERSION))
TF_VAR_send_email_version := $(or $(SEND_EMAIL_VERSION), $(VERSION))
TF_VAR_service_matcher_version := $(or $(SERVICE_MATCHER_VERSION), $(VERSION))
TF_VAR_service_sync_version := $(or $(SERVICE_SYNC_VERSION), $(VERSION))
TF_VAR_slack_messenger_version := $(or $(SLACK_MESSENGER_VERSION), $(VERSION))
TF_VAR_quality_checker_version := $(or $(QUALITY_CHECKER_VERSION), $(VERSION))

TF_VAR_change_event_dlq_handler_role := $(CHANGE_EVENT_DLQ_HANDLER_LAMBDA_ROLE_NAME)
TF_VAR_dos_db_handler_role := $(DOS_DB_HANDLER_LAMBDA_ROLE_NAME)
TF_VAR_dos_db_update_dlq_handler_role := $(DOS_DB_UPDATE_DLQ_HANDLER_LAMBDA_ROLE_NAME)
TF_VAR_event_replay_role := $(EVENT_REPLAY_LAMBDA_ROLE_NAME)
TF_VAR_ingest_change_event_role := $(INGEST_CHANGE_EVENT_LAMBDA_ROLE_NAME)
TF_VAR_send_email_role := $(SEND_EMAIL_LAMBDA_ROLE_NAME)
TF_VAR_service_matcher_role := $(SERVICE_MATCHER_LAMBDA_ROLE_NAME)
TF_VAR_service_sync_role := $(SERVICE_SYNC_LAMBDA_ROLE_NAME)
TF_VAR_slack_messenger_role := $(SLACK_MESSENGER_LAMBDA_ROLE_NAME)
TF_VAR_quality_checker_role := $(QUALITY_CHECKER_LAMBDA_ROLE_NAME)

# Log Group Filters for Firehose
TF_VAR_change_event_dlq_handler_subscription_filter_name := $(CHANGE_EVENT_DLQ_HANDLER_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_dos_db_update_dlq_handler_subscription_filter_name := $(DOS_DB_HANDLER_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_event_replay_subscription_filter_name := $(EVENT_REPLAY_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_ingest_change_event_subscription_filter_name := $(INGEST_CHANGE_EVENT_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_send_email_subscription_filter_name := $(SEND_EMAIL_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_service_matcher_subscription_filter_name := $(SERVICE_MATCHER_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_service_sync_di_subscription_filter_name := $(SERVICE_SYNC_LAMBDA)-di-cw-logs-firehose-subscription
TF_VAR_service_sync_dos_subscription_filter_name := $(SERVICE_SYNC_LAMBDA)-dos-cw-logs-firehose-subscription
TF_VAR_slack_messenger_subscription_filter_name := $(SLACK_MESSENGER_LAMBDA)-cw-logs-firehose-subscription
TF_VAR_quality_checker_subscription_filter_name := $(QUALITY_CHECKER_LAMBDA)-cw-logs-firehose-subscription

# Cloudwatch dashboards
TF_VAR_cloudwatch_monitoring_dashboard_name := $(PROJECT_ID)-$(SHARED_ENVIRONMENT)-monitoring-dashboard
TF_VAR_sqs_dlq_recieved_msg_alert_name := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-sqs-dlq-recieved-msg-alert
TF_VAR_sns_topic_app_alerts_for_slack_default_region := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-topic-app-alerts-for-slack-default-region
TF_VAR_sns_topic_app_alerts_for_slack_route53_health_check_alarm_region := $(PROJECT_ID)-$(BLUE_GREEN_ENVIRONMENT)-topic-app-alerts-for-slack-route53-health-check-alarm-region
SQS_QUEUE_URL:= https://sqs.$(AWS_REGION).amazonaws.com/$(AWS_ACCOUNT_ID)/$(TF_VAR_change_event_queue)

# Lambda Concurrency
TF_VAR_service_matcher_max_concurrency := $(SERVICE_MATCHER_MAX_CONCURRENCY)
TF_VAR_service_sync_max_concurrency := $(SERVICE_SYNC_MAX_CONCURRENCY)

# Lambda Variables
TF_VAR_log_level := $(LOG_LEVEL)
TF_VAR_lambda_powertools_service_name := $(PROGRAMME)-$(TEAM_ID)-$(PROFILE)-$(BLUE_GREEN_ENVIRONMENT)
TF_VAR_slack_alert_channel := $(SLACK_ALERT_CHANNEL)
TF_VAR_dos_db_cluster_name := $(DB_CLUSTER_NAME)
TF_VAR_dos_db_writer_name := $(DB_WRITER_NAME)
TF_VAR_dos_db_reader_name := $(DB_READER_NAME)
TF_VAR_dos_db_writer_route_53 := $(DB_WRITER_ROUTE_53)
TF_VAR_dos_db_reader_route_53 := $(DB_READER_ROUTE_53)
TF_VAR_dos_db_port := $(DB_PORT)
TF_VAR_dos_db_name := $(DB_NAME)
TF_VAR_dos_db_schema := $(DB_SCHEMA)
TF_VAR_dos_db_writer_security_group_name := $(DB_WRITER_SG_NAME)
TF_VAR_dos_db_reader_security_group_name := $(DB_READER_SG_NAME)
TF_VAR_dos_db_writer_secret_name := $(DB_WRITER_SECRET_NAME)
TF_VAR_dos_db_writer_secret_key := $(DB_WRITER_SECRET_KEY)
TF_VAR_dos_db_reader_secret_name := $(DB_READER_SECRET_NAME)
TF_VAR_dos_db_reader_secret_key := $(DB_READER_SECRET_KEY)
TF_VAR_dos_db_read_only_user_name_secret_name := $(DB_READ_ONLY_USER_NAME_SECRET_NAME)
TF_VAR_dos_db_read_only_user_name_secret_key := $(DB_READ_ONLY_USER_NAME_SECRET_KEY)
TF_VAR_slack_webhook_secret_key := $(SLACK_WEBHOOK_SECRET_KEY)
TF_VAR_odscode_starting_character := $(ODSCODE_STARTING_CHARACTER)

# Lambda Schedules
TF_VAR_quality_checker_schedule_role := $(QUALITY_CHECKER_LAMBDA)-schedule-role
TF_VAR_quality_checker_lambda_schedule_name := $(QUALITY_CHECKER_LAMBDA)-schedule
