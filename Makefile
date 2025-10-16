PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(abspath $(PROJECT_DIR)/build/automation/init.mk)

# ==============================================================================
# Development workflow targets

setup: project-config # Set up project
	make tester-build

container-check: # Check the container management tool - can be set with: "export DOCKER_CMD=`which podman`" or "export DOCKER_CMD=`which docker`"
	echo $(DOCKER_CMD)

build: # Build lambdas
	for IMAGE_NAME in $$(echo $(PROJECT_LAMBDAS_LIST) | tr "," "\n"); do
		make -s build-lambda GENERIC_IMAGE_NAME=lambda NAME=$$IMAGE_NAME
	done

build-lambda: ### Build lambda docker image - mandatory: NAME
	UNDERSCORE_LAMBDA_NAME=$$(echo $(NAME) | tr '-' '_')
	cp -f $(APPLICATION_DIR)/$$UNDERSCORE_LAMBDA_NAME/requirements.txt $(DOCKER_DIR)/lambda/assets/requirements.txt
	cd $(APPLICATION_DIR)
	tar -czf $(DOCKER_DIR)/lambda/assets/app.tar.gz \
		--exclude=tests $$UNDERSCORE_LAMBDA_NAME common/*.py __init__.py > /dev/null 2>&1
	cd $(PROJECT_DIR)
	make -s docker-image GENERIC_IMAGE_NAME=lambda CMD=$$UNDERSCORE_LAMBDA_NAME.$$UNDERSCORE_LAMBDA_NAME.lambda_handler BUILD_OPTS="--platform=linux/arm64"
	rm -f $(DOCKER_DIR)/lambda/assets/*.tar.gz $(DOCKER_DIR)/lambda/assets/*.txt

build-and-push: # Build lambda docker images and pushes them to ECR
	for IMAGE_NAME in $$(echo $(PROJECT_LAMBDAS_LIST) | tr "," "\n"); do
		make -s build-lambda GENERIC_IMAGE_NAME=lambda NAME=$$IMAGE_NAME
		make -s docker-push NAME=$$IMAGE_NAME
	done

deploy: # Deploys whole project - mandatory: PROFILE
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=api-key,shared-resources,application,blue-green-link

undeploy: # Undeploys whole project - mandatory: PROFILE
	eval "$$(make -s populate-tagging-variables)"
	make terraform-destroy-auto-approve STACKS=blue-green-link,application,shared-resources VERSION=any
	if [ "$(PROFILE)" != "live" ]; then
		make terraform-destroy-auto-approve STACKS=api-key
	fi

build-and-deploy: # Builds and Deploys whole project - mandatory: PROFILE
	make build-and-push VERSION=$(BUILD_TAG)
	make deploy VERSION=$(BUILD_TAG)

populate-tagging-variables:
	echo "unset AWS_PROFILE"
	DEPLOYMENT_SECRETS=$$(make -s secret-get-existing-value NAME=$(DEPLOYMENT_SECRETS))
	echo "export TF_VAR_service_category=$$(echo $$DEPLOYMENT_SECRETS | jq -r '.$(SERVICE_CATEGORY_KEY)')"
	echo "export TF_VAR_data_classification=$$(echo $$DEPLOYMENT_SECRETS | jq -r '.$(DATA_CLASSIFICATION_KEY)')"
	echo "export TF_VAR_distribution_list=$$(echo $$DEPLOYMENT_SECRETS | jq -r '.$(DISTRIBUTION_LIST_KEY)')"

unit-test:
	make -s docker-run-tester \
	CMD="python -m pytest application --junitxml=./testresults.xml --cov-report term-missing --cov-report xml:coverage.xml --cov=application -vv" \
	ARGS=$(UNIT_TEST_ARGS)

coverage-report: # Runs whole project coverage unit tests
	make -s python-code-coverage CMD="-m pytest application" DIR=/ \
	IMAGE=$$(make _docker-get-reg)/tester:latest \
	ARGS=$(UNIT_TEST_ARGS)

coverage-html:
	make -s docker-run-tools CMD="coverage html" DIR=/ \
		IMAGE=$$(make _docker-get-reg)/tester:latest \
		ARGS=$(UNIT_TEST_ARGS)

UNIT_TEST_ARGS=" \
		-e POWERTOOLS_LOG_DEDUPLICATION_DISABLED="1" \
		--volume $(APPLICATION_DIR)/common:/tmp/.packages/common \
		--volume $(APPLICATION_DIR)/change_event_dlq_handler:/tmp/.packages/change_event_dlq_handler \
		--volume $(APPLICATION_DIR)/dos_db_handler:/tmp/.packages/dos_db_handler \
		--volume $(APPLICATION_DIR)/dos_db_update_dlq_handler:/tmp/.packages/dos_db_update_dlq_handler \
		--volume $(APPLICATION_DIR)/event_replay:/tmp/.packages/event_replay \
		--volume $(APPLICATION_DIR)/ingest_change_event:/tmp/.packages/ingest_change_event \
		--volume $(APPLICATION_DIR)/send_email:/tmp/.packages/send_email \
		--volume $(APPLICATION_DIR)/service_matcher:/tmp/.packages/service_matcher \
		--volume $(APPLICATION_DIR)/service_sync:/tmp/.packages/service_sync \
		--volume $(APPLICATION_DIR)/slack_messenger:/tmp/.packages/slack_messenger \
		--volume $(APPLICATION_DIR)/quality_checker:/tmp/.packages/quality_checker \
		"

integration-test: # End to end test DI project - mandatory: PROFILE, TAG=[complete|dev]; optional: ENVIRONMENT, PARALLEL_TEST_COUNT
	RUN_ID=$$RANDOM
	echo RUN_ID=$$RUN_ID
	make -s docker-run-tester \
	CMD="pytest steps -k $(TAG) -vvvv --gherkin-terminal-reporter -p no:sugar -n $(PARALLEL_TEST_COUNT) --cucumberjson=./testresults.json --reruns 2 --reruns-delay 10" \
	DIR=./test/integration \
	ARGS=" \
		--env-file <(make _docker-get-variables-from-file VARS_FILE=$(VAR_DIR)/project.mk) \
		-e RUN_ID=$$RUN_ID \
		"

production-smoke-test: # Smoke test DI project - mandatory: PROFILE; optional: ENVIRONMENT
	if [ "$(PROFILE)" != "live" ]; then
		make -s docker-run-tester \
		CMD="pytest -vvvv --gherkin-terminal-reporter -p no:sugar --cucumberjson=./results/testresults.json" \
		DIR=./test/smoke \
		ARGS="--env-file <(make _docker-get-variables-from-file VARS_FILE=$(VAR_DIR)/project.mk)"
	else
		echo "Production smoke test not allowed on live profile"
		exit 1
	fi


clean: # Runs whole project clean
	make \
		docker-clean \
		terraform-clean \
		python-clean \
		tester-clean \
		performance-test-clean
	rm -rf test/integration/replay/.*.txt

remove-development-environments: # Removes development environments - mandatory: PROFILE
	STACK_NAMES=$$(aws cloudformation list-stacks  --output json | jq -r '.StackSummaries[] | select ( .StackName | contains("dos-integration")) | select (.StackStatus == "UPDATE_COMPLETE").StackName')
	for ENVIRONMENT in $$STACK_NAMES; do \
		ENVIRONMENT=$$(echo $$ENVIRONMENT | sed -e "s/^uec-dos-integration-//");
		if [[ ! "$$ENVIRONMENT" =~ ^(dev|test|perf|perf2|release)$$ ]] && [[ "$$ENVIRONMENT" != *"-dev" ]]; then
			make terraform-clean
			echo "Removing $$ENVIRONMENT"
			make undeploy PROFILE=dev ENVIRONMENT=$$ENVIRONMENT OPTS="--refresh=false" SHARED_ENVIRONMENT=$$ENVIRONMENT BLUE_GREEN_ENVIRONMENT=$$ENVIRONMENT
			echo "Removed $$ENVIRONMENT"
		fi
	done

# ==============================================================================
# Change Event Dead Letter Queue Handler (change-event-dlq-handler)

change-event-dlq-handler-build-and-deploy: ### Build and deploy change event dlq handler lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=change-event-dlq-handler CHANGE_EVENT_DLQ_HANDLER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# DoS DB Update Dead Letter Queue Handler (dos-db-update-dlq-handler)

dos-db-update-dlq-handler-build-and-deploy: ### Build and deploy dos db update dlq handler lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=dos-db-update-dlq-handler DOS_DB_UPDATE_DLQ_HANDLER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# DoS DB Checker Handler (dos-db-handler)

dos-db-handler-build-and-deploy: ### Build and deploy test db checker handler lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=dos-db-handler DOS_DB_HANDLER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Event Replay lambda (event-replay)

event-replay-build-and-deploy: ### Build and deploy event replay lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=event-replay EVENT_REPLAY_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Ingest Change Event

ingest-change-event-build-and-deploy: ### Build and deploy ingest change event lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=ingest-change-event INGEST_CHANGE_EVENT_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Send Email

send-email-build-and-deploy: ### Build and deploy send email lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=send-email SEND_EMAIL_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Service Matcher

service-matcher-build-and-deploy: ### Build and deploy service matcher lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=service-matcher SERVICE_MATCHER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Service Sync

service-sync-build-and-deploy: ### Build and deploy service sync lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=service-sync SERVICE_SYNC_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Slack Messenger

slack-messenger-build-and-deploy: ### Build and deploy slack messenger lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=slack-messenger SLACK_MESSENGER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Quality Checker

quality-checker-build-and-deploy: ### Build and deploy quality checker lambda docker image - mandatory: PROFILE, ENVIRONMENT
	make build-and-deploy-single-function FUNCTION_NAME=quality-checker QUALITY_CHECKER_VERSION=$(BUILD_TAG) VERSION=$(BUILD_TAG)

# ==============================================================================
# Deployments

quick-build-and-deploy: # Build and deploy lambdas only (meant to for fast redeployment of existing lambdas) - mandatory: PROFILE, ENVIRONMENT
	make -s build VERSION=$(BUILD_TAG)
	make -s push-images VERSION=$(BUILD_TAG)
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=application VERSION=$(BUILD_TAG)

build-and-deploy-single-function: # Build and deploy single lambda only (meant to for fast redeployment of existing lambda) - mandatory: PROFILE, ENVIRONMENT
	make build-lambda GENERIC_IMAGE_NAME=lambda NAME=$(FUNCTION_NAME)
	make docker-push NAME=$(FUNCTION_NAME)
	eval "$$(make -s get-lambda-versions-if-empty)"
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=application

deploy-application-with-same-image-versions: # Deploy application with same image versions - mandatory: PROFILE, ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	eval "$$(make -s get-lambda-versions-from-terraform-stack)"
	make terraform-apply-auto-approve STACKS=application

get-lambda-versions-if-empty:
	VERSIONS=$$(make -s terraform-output STACKS=application OPTS='-json lambda_versions' | tail -n1)
	[[ -z "$$CHANGE_EVENT_DLQ_HANDLER_VERSION" ]] && echo "export CHANGE_EVENT_DLQ_HANDLER_VERSION=$$(echo $$VERSIONS | jq -r '.change_event_dlq_handler')"
	[[ -z "$$DOS_DB_HANDLER_VERSION" ]] && echo "export DOS_DB_HANDLER_VERSION=$$(echo $$VERSIONS | jq -r '.dos_db_handler')"
	[[ -z "$$DOS_DB_UPDATE_DLQ_HANDLER_VERSION" ]] && echo "export DOS_DB_UPDATE_DLQ_HANDLER_VERSION=$$(echo $$VERSIONS | jq -r '.dos_db_update_dlq_handler')"
	[[ -z "$$EVENT_REPLAY_VERSION" ]] && echo "export EVENT_REPLAY_VERSION=$$(echo $$VERSIONS | jq -r '.event_replay')"
	[[ -z "$$INGEST_CHANGE_EVENT_VERSION" ]] && echo "export INGEST_CHANGE_EVENT_VERSION=$$(echo $$VERSIONS | jq -r '.ingest_change_event')"
	[[ -z "$$SEND_EMAIL_VERSION" ]] && echo "export SEND_EMAIL_VERSION=$$(echo $$VERSIONS | jq -r '.send_email')"
	[[ -z "$$SERVICE_MATCHER_VERSION" ]] && echo "export SERVICE_MATCHER_VERSION=$$(echo $$VERSIONS | jq -r '.service_matcher')"
	[[ -z "$$SERVICE_SYNC_VERSION" ]] && echo "export SERVICE_SYNC_VERSION=$$(echo $$VERSIONS | jq -r '.service_sync')"
	[[ -z "$$SLACK_MESSENGER_VERSION" ]] && echo "export SLACK_MESSENGER_VERSION=$$(echo $$VERSIONS | jq -r '.slack_messenger')"
	[[ -z "$$QUALITY_CHECKER_VERSION" ]] && echo "export QUALITY_CHECKER_VERSION=$$(echo $$VERSIONS | jq -r '.quality_checker')"

push-images: # Use VERSION=[] to push a perticular version otherwise with default to latest
	for IMAGE_NAME in $$(echo $(PROJECT_LAMBDAS_LIST) | tr "," "\n"); do
		make docker-push NAME=$$IMAGE_NAME
	done

push-tester-image:
	make docker-push NAME=tester

# ==============================================================================
# Development Tools

deploy-development-and-deployment-tools:
	TF_VAR_github_token=$$(make -s secret-get-existing-value NAME=uec-dos-int-tools/deployment KEY=GITHUB_TOKEN)
	make terraform-apply-auto-approve STACKS=development-and-deployment-tools PROFILE=tools ENVIRONMENT=dev TF_VAR_github_token=$$TF_VAR_github_token

undeploy-development-and-deployment-tools:
	make terraform-destroy-auto-approve STACKS=development-and-deployment-tools PROFILE=tools ENVIRONMENT=dev TF_VAR_github_token="any"

plan-development-and-deployment-tools:
	TF_VAR_github_token=$$(make -s secret-get-existing-value NAME=uec-dos-int-tools/deployment KEY=GITHUB_TOKEN)
	make terraform-plan STACKS=development-and-deployment-tools PROFILE=tools ENVIRONMENT=dev TF_VAR_github_token=$$TF_VAR_github_token

docker-hub-signin: # Sign into Docker hub
	export DOCKER_USERNAME=$$($(AWSCLI) secretsmanager get-secret-value --secret-id uec-pu-updater/deployment --version-stage AWSCURRENT --region $(AWS_REGION) --query '{SecretString: SecretString}' | jq --raw-output '.SecretString' | jq -r .DOCKER_HUB_USERNAME)
	export DOCKER_PASSWORD=$$($(AWSCLI) secretsmanager get-secret-value --secret-id uec-pu-updater/deployment --version-stage AWSCURRENT --region $(AWS_REGION) --query '{SecretString: SecretString}' | jq --raw-output '.SecretString' | jq -r .DOCKER_HUB_PASS)
	make docker-login

wait-for-codebuild-to-finish: # Wait for codebuild project to finish
	build_id=$$(aws codebuild list-builds-for-project --project-name $(PROJECT_NAME) --sort-order DESCENDING | jq --raw-output '.ids[0]')
	while [[ $$(aws codebuild batch-get-builds --ids $$build_id | jq --raw-output '.builds[0].buildStatus') == "IN_PROGRESS" ]]; do
		echo Waiting for $(PROJECT_NAME) to finish
		sleep 60
	done

tag-commit-for-deployment: # Tag git commit for deployment - mandatory: PROFILE=[demo/live], COMMIT=[short commit hash]
	if [ "$(PROFILE)" == "$(ENVIRONMENT)" ]; then
		make git-tag-create-environment-deployment COMMIT=$(COMMIT)
	else
		echo PROFILE=$(PROFILE) should equal ENVIRONMENT=$(ENVIRONMENT)
		echo Recommended: you run this command from the main branch
	fi

tag-commit-to-destroy-environment: # Tag git commit to destroy deployment - mandatory: ENVIRONMENT=[ds-number], COMMIT=[short commit hash]
	if [ "$(PROFILE)" != "$(ENVIRONMENT)" ]; then
		tag=$(ENVIRONMENT)-destroy-$(BUILD_TIMESTAMP)
		make git-tag-create TAG=$$tag COMMIT=$(COMMIT)
	else
		echo This is for destroying old dev environments PROFILE should not be equal to ENVIRONMENT
	fi

get-environment-from-pr:
	ENVIRONMENT=$$(gh pr list -s merged --json number,mergeCommit,headRefName --repo=NHSDigital/dos-integration |  jq --raw-output '.[] | select(.number == $(PR_NUMBER)) | .headRefName | sub( ".*:*/DS-(?<x>.[0-9]*).*"; "ds-\(.x)") ')
	echo $$ENVIRONMENT

is-environment-deployed:
	ENVIRONMENT_DEPLOYED=$$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --max-items 1000 | jq --raw-output '.StackSummaries[] | select(.StackName | contains("$(ENVIRONMENT)"))')
	echo $$ENVIRONMENT_DEPLOYED

slack-codebuild-notification: ### Send codebuild pipeline notification - mandatory: PIPELINE_NAME,BUILD_STATUS=[success|failure]
	time=$$(( $(shell date +"%s") - $(shell date -d '$(BUILD_DATE)' +"%s") ))
	if [[ ! -z "$(PR)" ]]; then
		NAME=codebuild-pipeline-pr-merge-$(shell echo $(BUILD_STATUS) | tr '[:upper:]' '[:lower:]')
	else
		NAME=codebuild-pipeline-$(shell echo $(BUILD_STATUS) | tr '[:upper:]' '[:lower:]')
	fi
	echo NAME=$$NAME
	make slack-send-notification \
			NAME=$$NAME \
			BUILD_TIME=$$(( $$time / 60 ))m$$(( $$time % 60 ))s \
			BUILD_URL=$$(echo https://$(AWS_REGION).console.aws.amazon.com/codesuite/codebuild/$(AWS_ACCOUNT_ID_MGMT)/projects/$(CODEBUILD_PROJECT_NAME)/build/$(CODEBUILD_BUILD_ID)/log?region=$(AWS_REGION)) \
			SLACK_WEBHOOK_URL=$$(make -s secret-get-existing-value NAME=$(DEPLOYMENT_SECRETS) KEY=SLACK_WEBHOOK)

aws-ecr-cleanup: # Mandatory: REPOS=[comma separated list of ECR repo names e.g. service-sync,slack-messenger]
	export THIS_YEAR=$$(date +%Y)
	export LAST_YEAR=$$(date -d "1 year ago" +%Y)
	DELETE_IMAGES_OLDER_THAN=$$(date +%s --date='1 month ago')
	for REPOSITORY in $$(echo $(REPOS) | tr "," "\n"); do
		REPOSITORY_NAME=$$(echo $(PROJECT_GROUP_SHORT)/$(PROJECT_NAME_SHORT)/$$REPOSITORY)
		echo Repository is $$REPOSITORY_NAME
		make remove-untagged-images REPOSITORY=$$REPOSITORY_NAME
		make remove-dev-images REPOSITORY=$$REPOSITORY_NAME DELETE_IMAGES_OLDER_THAN=$$DELETE_IMAGES_OLDER_THAN
	done

remove-dev-images: # Removes dev ecr images in repository older than certain date, REPOSITORY=[$(PROJECT_GROUP_SHORT)/$(PROJECT_NAME_SHORT)/REPOSITORY_NAME], DELETE_IMAGES_OLDER_THAN=[date/time in epoch]
	COUNTER=0
	IMAGE_IDS=$$(aws ecr describe-images --registry-id $(AWS_ACCOUNT_ID_MGMT) --region $(AWS_REGION) --repository-name $(REPOSITORY) --filter "tagStatus=TAGGED" --max-items 1000 --output json | jq -r '.imageDetails[] | select (.imageTags[0] | contains("$(LAST_YEAR)") or contains ("$(THIS_YEAR)")) | select (.imagePushedAt < $(DELETE_IMAGES_OLDER_THAN)).imageDigest')
	for DIGEST in $$(echo $$IMAGE_IDS | tr " " "\n"); do
			IMAGES_TO_DELETE+=$$(echo $$DIGEST | sed '$$s/$$/ /')
			COUNTER=$$((COUNTER+1))
			if [ $$COUNTER -eq 100 ]; then
				make batch-delete-ecr-images LIST_OF_DIGESTS="$$IMAGES_TO_DELETE"
				IMAGES_TO_DELETE=""
				COUNTER=0
			fi
	done
	if [[ ! -z "$$IMAGES_TO_DELETE" ]]; then
		make batch-delete-ecr-images LIST_OF_DIGESTS="$$IMAGES_TO_DELETE"
	fi

remove-untagged-images: # Removes untagged ecr images in repository, Mandatory - REPOSITORY=[$(PROJECT_GROUP_SHORT)/$(PROJECT_NAME_SHORT)/REPOSITORY_NAME]
	IMAGE_DIGESTS=$$(aws ecr describe-images --registry-id $(AWS_ACCOUNT_ID_MGMT) --region $(AWS_REGION) --region $(AWS_REGION) --repository-name $(REPOSITORY) --filter "tagStatus=UNTAGGED" --max-items 100 --output json | jq -r .imageDetails[].imageDigest | tr "\n" " ")
	if [[ ! -z "$$IMAGE_DIGESTS" ]]; then
		make batch-delete-ecr-images LIST_OF_DIGESTS="$$IMAGE_DIGESTS"
	fi

batch-delete-ecr-images: # Mandatory - LIST_OF_DIGESTS: [list of "sha:digest" separated by spaces], REPOSITORY=[$(PROJECT_GROUP_SHORT)/$(PROJECT_NAME_SHORT)/REPOSITORY_NAME]
	for DIGEST in $$(echo $(LIST_OF_DIGESTS) | tr " " "\n"); do
		IMAGES_TO_DELETE+=$$(echo imageDigest=\"$$DIGEST\" | sed 's/$$/ /')
	done
	IMAGE_IDS=$$(echo $$IMAGES_TO_DELETE | sed 's/ $$//')
	aws ecr batch-delete-image --registry-id $(AWS_ACCOUNT_ID_MGMT) --region $(AWS_REGION) --repository-name $(REPOSITORY) --image-ids $$IMAGE_IDS

# ==============================================================================
# Tester

tester-build: ### Build tester docker image
	cat $(APPLICATION_DIR)/*/requirements.txt $(APPLICATION_DIR)/requirements-dev.txt | sort --unique > $(DOCKER_DIR)/tester/assets/requirements.txt
	make -s docker-image NAME=tester

tester-clean:
	rm -fv $(DOCKER_DIR)/tester/assets/*.txt

# ==============================================================================
# Testing

# -----------------------------
# Performance Testing

stress-test: # Create change events for stress performance testing - mandatory: PROFILE, ENVIRONMENT, START_TIME=[timestamp]
	make -s docker-run-tester \
		CMD="python -m locust -f stress_test.py --headless \
			--users 12 --spawn-rate 10 --run-time 12m  \
			--stop-timeout 10 --exit-code-on-error 0 -H $(HTTPS_DOS_INTEGRATION_URL) \
			" $(PERFORMANCE_TEST_DIR_AND_ARGS)

load-test: # Create change events for load performance testing - mandatory: PROFILE, ENVIRONMENT, START_TIME=[timestamp]
	make -s docker-run-tester \
		CMD="python -m locust -f load_test.py --headless \
			--users 50 --spawn-rate 5 --exit-code-on-error 0 \
			-H $(HTTPS_DOS_INTEGRATION_URL) \
			" $(PERFORMANCE_TEST_DIR_AND_ARGS)

PERFORMANCE_TEST_DIR_AND_ARGS= \
	DIR=./test/performance \
	ARGS="-p 8089:8089 --env-file <(make _docker-get-variables-from-file VARS_FILE=$(VAR_DIR)/project.mk)"

performance-test-results: # Get performance test results - mandatory: PROFILE, ENVIRONMENT, START_TIME=[timestamp], END_TIME=[timestamp]
# Timestamps are in ISO 1806 format e.g. 2023-01-01T00:00:00Z
# Example: make performance-test-results PROFILE=perf ENVIRONMENT=perf START_TIME=2023-11-28T10:00:00Z END_TIME=2023-11-28T12:00:00Z
	make -s docker-run-tester CMD="python scripts/performance_test_results/performance_test_results.py" \
		ARGS="--env-file <(make _docker-get-variables-from-file VARS_FILE=$(VAR_DIR)/project.mk) \
			--env START_TIME=$(START_TIME) --env END_TIME=$(END_TIME)"

performance-test-clean: # Clean up performance test results
	rm -rf $(TMP_DIR)/performance
	rm -f $(TMP_DIR)/*.zip
	rm -rf $(PROJECT_DIR)/test/performance/results/*.csv

# -----------------------------
# Other

update-all-ip-allowlists: # Update your IP address in AWS secrets manager to acesss non-prod environments - mandatory: PROFILE, ENVIRONMENT, USERNAME
	USERNAME=$$(git config user.name)
	make -s update-ip-allowlist PROFILE=dev USERNAME="$$USERNAME"

update-ip-allowlist: # Update your IP address in AWS secrets manager to acesss non-prod environments - mandatory: PROFILE, ENVIRONMENT, USERNAME
	make -s docker-run-python \
		IMAGE=$$(make _docker-get-reg)/tester:latest \
		CMD="python update-ip-address.py $(USERNAME)" \
		DIR=$(BIN_DIR) ARGS="-e IP_SECRET=$(TF_VAR_ip_address_secret)"

update-ip-allowlists-and-deploy-allowlist: # Update your IP address in AWS secrets manager to acesss non-prod environments and then redeploy environment - mandatory: PROFILE, ENVIRONMENT
	make update-all-ip-allowlists
	make -s terraform-clean
	make -s terraform-apply-auto-approve STACKS=api-gateway-sqs

delete-ip-from-allowlist: # Update your IP address in AWS secrets manager to acesss test environment - mandatory: PROFILE, ENVIRONMENT, USERNAME
	make -s docker-run-python \
		IMAGE=$$(make _docker-get-reg)/tester:latest \
		CMD="python delete-ip-address.py $(USERNAME)" \
		DIR=$(BIN_DIR) ARGS="-e IP_SECRET=$(TF_VAR_ip_address_secret)"

trigger-dos-deployment-pipeline:
	JENKINS_URL=$$(make -s secret-get-existing-value NAME=uec-dos-int-dev/deployment KEY=JENKINS_MOM_URL)
	JENKINS_USERNAME=$$(make -s secret-get-existing-value NAME=uec-dos-int-dev/deployment KEY=JENKINS_API_USERNAME)
	JENKINS_PASSWORD=$$(make -s secret-get-existing-value NAME=uec-dos-int-dev/deployment KEY=JENKINS_API_PASSWORD)
	JENKINS_CRUMB=$$(curl -L -X GET "$$JENKINS_URL/crumbIssuer/api/json" --user $$JENKINS_USERNAME:$$JENKINS_PASSWORD --cookie-jar jenkins.cookies | jq --raw-output '.crumb')
	curl -L -X POST "$$JENKINS_URL/view/DoS%20Deploy/job/Deploy%20App%20and%20Cron/job/develop/buildWithParameters" --cookie jenkins.cookies \
	--user $$JENKINS_USERNAME:$$JENKINS_PASSWORD -H "Jenkins-Crumb: $$JENKINS_CRUMB" \
	--data TARGET="regressiondi" --data IMAGE_TAG="8.14.1_8894b744" --data REFRESH="true"
	echo Jenkins Job has started
	echo Sleeping for 5 minutes
	sleep 300
	echo Jenkins Job expected to have finished
	rm -rf jenkins.cookies

create-ecr-repositories:
	make docker-create-repository NAME=change-event-dlq-handler
	make docker-create-repository NAME=dos-db-handler
	make docker-create-repository NAME=dos-db-update-dlq-handler
	make docker-create-repository NAME=event-replay
	make docker-create-repository NAME=service-matcher
	make docker-create-repository NAME=service-sync
	make docker-create-repository NAME=slack-messenger
	make docker-create-repository NAME=tester

terraform-security:
	make docker-run-terraform-tfsec DIR=infrastructure CMD="tfsec"

# ==============================================================================
# Checkov (Code Security Best Practices)

docker-best-practices:
	make docker-run-checkov DIR=/build/docker CHECKOV_OPTS="--framework dockerfile --skip-check CKV_DOCKER_2,CKV_DOCKER_3,CKV_DOCKER_4"

terraform-best-practices:
	make docker-run-checkov DIR=/infrastructure CHECKOV_OPTS="--framework terraform --skip-check CKV_AWS_120,CKV_AWS_147,CKV_AWS_149,CKV_AWS_225,CKV_AWS_338,CKV_AWS_316,CKV_AWS_337,CKV_TF_1"

github-actions-best-practices:
	make docker-run-checkov DIR=/.github CHECKOV_OPTS="--skip-check CKV_GHA_2"

checkov-secret-scanning:
	make docker-run-checkov CHECKOV_OPTS="--framework secrets"

# ==============================================================================
# Blue/Green Deployment Targets

deploy-shared-resources: # Deploys shared resources (Only intended to run in pipeline) - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=api-key,shared-resources

deploy-blue-green-environment: # Deploys blue/green resources (Only intended to run in pipeline) - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=application

build-and-deploy-blue-green-environment: # Deploys blue/green resources - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	make build-and-push VERSION=$(BUILD_TAG)
	make deploy-blue-green-environment VERSION=$(BUILD_TAG)

link-blue-green-environment: # Links blue green environment - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-apply-auto-approve STACKS=blue-green-link

undeploy-shared-resources: # Undeploys shared resources (Only intended to run in pipeline) - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-destroy-auto-approve STACKS=shared-resources
	if [ "$(PROFILE)" != "live" ]; then
		make terraform-destroy-auto-approve STACKS=api-key
	fi

undeploy-blue-green-environment: # Undeploys blue/green resources (Only intended to run in pipeline) - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-destroy-auto-approve STACKS=application

unlink-blue-green-environment: # Un-Links blue green environment - mandatory: PROFILE, ENVIRONMENT, SHARED_ENVIRONMENT, BLUE_GREEN_ENVIRONMENT
	eval "$$(make -s populate-tagging-variables)"
	make terraform-destroy-auto-approve STACKS=blue-green-link

tag-commit-to-deploy-blue-green-environment: # Tags commit to deploy blue/green environment - mandatory: COMMIT=[short commit hash]
	tag="$(BUILD_TIMESTAMP)-blue-green-deployment"
	make git-tag-create TAG=$$tag COMMIT=$(COMMIT)

tag-commit-to-deploy-shared-resources: # Tags commit to deploy shared resources - mandatory: COMMIT=[short commit hash]
	tag="$(BUILD_TIMESTAMP)-shared-resources-deployment"
	make git-tag-create TAG=$$tag COMMIT=$(COMMIT)

tag-commit-to-rollback-blue-green-environment: # Tags commit to rollback blue/green environment - mandatory: PROFILE=[name], SHARED_ENVIRONMENT=[name]
	tag="$(BUILD_TIMESTAMP)_$(PROFILE)_$(SHARED_ENVIRONMENT)_blue_green_rollback"
	make git-tag-create TAG=$$tag COMMIT=$(COMMIT)

# ==============================================================================
# Pipeline Targets

commit-date-hash-tag:
	echo "$(BUILD_COMMIT_DATETIME)-$(BUILD_COMMIT_HASH)"

docker-run-tester: ### Run python container - mandatory: CMD; optional: SH=true,DIR,ARGS=[Docker args],LIB_VOLUME_MOUNT=true,VARS_FILE=[Makefile vars file],IMAGE=[image name],CONTAINER=[container name]
	make docker-config > /dev/null 2>&1
	mkdir -p $(TMP_DIR)/.python/pip/{cache,packages}
	lib_volume_mount=$$(([ $(BUILD_ID) -eq 0 ] || [ "$(LIB_VOLUME_MOUNT)" == true ]) && echo "--volume $(TMP_DIR)/.python/pip/cache:/tmp/.cache/pip --volume $(TMP_DIR)/.python/pip/packages:/tmp/.packages" ||:)
	container=$$([ -n "$(CONTAINER)" ] && echo $(CONTAINER) || echo tester-$(BUILD_COMMIT_HASH)-$(BUILD_ID)-$$(date --date=$$(date -u +"%Y-%m-%dT%H:%M:%S%z") -u +"%Y%m%d%H%M%S" 2> /dev/null)-$$(make secret-random LENGTH=8))
	$(DOCKER_CMD) run --interactive $(_TTY) --rm \
		--name $$container \
		--user $$(id -u):$$(id -g) \
		--env-file <(make _list-variables PATTERN="^(AWS|TX|TEXAS|NHSD|TERRAFORM)") \
		--env-file <(make _list-variables PATTERN="^(DB|DATABASE|SMTP|APP|APPLICATION|UI|API|SERVER|HOST|URL)") \
		--env-file <(make _list-variables PATTERN="^(PROFILE|ENVIRONMENT|BUILD|PROGRAMME|ORG|SERVICE|PROJECT)") \
		--env-file <(make _docker-get-variables-from-file VARS_FILE=$(VARS_FILE)) \
		--env HOME=/tmp \
		--env PIP_TARGET=/tmp/.packages \
		--env PYTHONPATH=/tmp/.packages \
		--env XDG_CACHE_HOME=/tmp/.cache \
		--volume $(PROJECT_DIR):/project \
		--volume $(HOME)/.aws:/tmp/.aws \
		--volume $(HOME)/bin:/tmp/bin \
		--volume $(HOME)/etc:/tmp/etc \
		--volume $(HOME)/usr:/tmp/usr \
		$$lib_volume_mount \
		--network $(DOCKER_NETWORK) \
		--workdir /project/$(shell echo $(abspath $(DIR)) | sed "s;$(PROJECT_DIR);;g") \
		$(ARGS) \
		$$(make _docker-get-reg)/tester:latest \
			$(CMD)


# ==============================================================================
# Python Targets (including Ruff)

python-code-checks:
	make python-check-dead-code
	make python-run-ruff-checks
	make unit-test
	echo "Python code checks completed"

python-check-dead-code:
	make -s docker-run-python \
		IMAGE=$$(make _docker-get-reg)/tester:latest \
		DIR=$(APPLICATION_DIR) \
		CMD="python -m vulture"

docker-run-ruff: # Runs ruff tests - mandatory: RUFF_OPTS=[options]
	make -s docker-run \
	IMAGE=$$(make _docker-get-reg)/tester \
		CMD="ruff $(RUFF_OPTS)"

python-run-ruff-checks: # Auto fixes ruff warnings
	make -s docker-run-ruff RUFF_OPTS="format --check ."
	make docker-run-ruff RUFF_OPTS="check ."

python-run-ruff-fixes: # Auto fixes ruff warnings
	make -s docker-run-ruff RUFF_OPTS="format . "
	make docker-run-ruff RUFF_OPTS="check . --fix"

# ==============================================================================

.SILENT: docker-run-ruff \
	commit-date-hash-tag \
	performance-test-results \
	container-check \
