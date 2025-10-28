TERRAFORM_DIR = $(INFRASTRUCTURE_DIR)/stacks
TERRAFORM_DIR_REL = $(shell echo $(TERRAFORM_DIR) | sed "s;$(PROJECT_DIR);;g")
TERRAFORM_STATE_STORE = $(or $(TEXAS_TERRAFORM_STATE_STORE), state-store-$(AWS_ACCOUNT_NAME))
TERRAFORM_STATE_LOCK = $(or $(TEXAS_TERRAFORM_STATE_LOCK), state-lock-$(AWS_ACCOUNT_NAME))
TERRAFORM_STATE_KEY = $(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)/$(ENVIRONMENT)
TERRAFORM_STATE_KEY_SHARED = texas
TERRAFORM_VERSION = $(or $(TEXAS_TERRAFORM_VERSION), 1.13.0)

# ==============================================================================

terraform-create-module-from-template: ### Create Terraform module from template - mandatory: TEMPLATE=[module template name]
	rm -rf $(INFRASTRUCTURE_DIR)/modules/$(TEMPLATE)
	mkdir -p $(INFRASTRUCTURE_DIR_REL)/modules
	cp -rfv \
		$(LIB_DIR_REL)/terraform/template/modules/$(TEMPLATE) \
		$(INFRASTRUCTURE_DIR_REL)/modules
	cp -fv $(LIB_DIR_REL)/terraform/template/.gitignore $(INFRASTRUCTURE_DIR_REL)
	make -s file-replace-variables-in-dir DIR=$(INFRASTRUCTURE_DIR_REL)/modules/$(TEMPLATE) SUFFIX=_TEMPLATE_TO_REPLACE

terraform-create-stack-from-template: ### Create Terraform stack from template - mandatory: NAME=[new stack name],TEMPLATE=[module template name],PROFILE=[profile name]
	rm -rf $(INFRASTRUCTURE_DIR)/stacks/$(NAME)
	mkdir -p $(INFRASTRUCTURE_DIR_REL)/stacks
	cp -rfv \
		$(LIB_DIR_REL)/terraform/template/stacks/$(TEMPLATE) \
		$(INFRASTRUCTURE_DIR_REL)/stacks/$(NAME)
	cp -rfv \
		$(LIB_DIR_REL)/terraform/template/stacks/*.tf \
		$(INFRASTRUCTURE_DIR_REL)/stacks/$(NAME)
	[ -f $(LIB_DIR_REL)/terraform/template/data-texas-$(TEXAS_VERSION).tf ] && cp -fv $(LIB_DIR_REL)/terraform/template/data-texas-$(TEXAS_VERSION).tf $(INFRASTRUCTURE_DIR_REL)/stacks/$(NAME)/data.tf
	cp -fv $(LIB_DIR_REL)/terraform/template/.gitignore $(INFRASTRUCTURE_DIR_REL)
	make -s file-replace-variables-in-dir DIR=$(INFRASTRUCTURE_DIR_REL)/stacks/$(NAME) SUFFIX=_TEMPLATE_TO_REPLACE

terraform-create-state-store: ### Create an S3 bucket to store the Terraform state
	make aws-s3-create NAME=$(TERRAFORM_STATE_STORE)

# ==============================================================================

terraform-apply-auto-approve: ### Set up infrastructure - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options]
	make terraform-apply \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="apply" \
		OPTS="-auto-approve $(OPTS)"

terraform-apply: ### Set up infrastructure - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options]
	make _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="apply $(OPTS)"

terraform-destroy-auto-approve: ### Tear down infrastructure - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options]
	make terraform-destroy \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="destroy" \
		OPTS="-auto-approve $(OPTS)"

terraform-destroy: ### Tear down infrastructure - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options]
	make _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="destroy $(OPTS)"

terraform-plan: ### Show plan - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options, e.g. -out=plan.out]
	make _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="plan $(OPTS)"

terraform-output: ### Extract output variables - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options]
	make -s _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="output $(OPTS)"

terraform-show: ### Show state - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name],OPTS=[Terraform options, e.g. -json plan.out > build/automation/tmp/plan.out.json]
	make -s _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="show $(OPTS)"

terraform-unlock: ### Remove state lock - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names],ID=[lock ID]; optional: PROFILE=[name],OPTS=-force
	make _terraform-stacks \
		STACKS="$(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS)))" \
		CMD="force-unlock $(ID) $(OPTS)"

terraform-fmt: docker-config ### Format Terraform code - optional: DIR,OPTS=[Terraform options]
	make docker-run-terraform \
		CMD="fmt -recursive $(OPTS)"

terraform-validate: docker-config ### Validate Terraform code - optional: DIR
	make docker-run-terraform \
		CMD="validate"

terraform-clean: ### Clean Terraform files
	find $(TERRAFORM_DIR) -type d -name '.terraform' -print0 | xargs -0 rm -rfv
	find $(TERRAFORM_DIR) -type f -name '*terraform.tfstate*' -print0 | xargs -0 rm -rfv

terraform-delete-state: ### Delete the Terraform state - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names]; optional: PROFILE=[name]
	# set up
	eval "$$(make aws-assume-role-export-variables)"
	# delete state
	for stack in $$(echo $(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS))) | tr "," "\n"); do
		make _terraform-delete-state-store STACK="$$stack"
		make _terraform-delete-state-lock STACK="$$stack"
	done

# ==============================================================================

terraform-export-variables: ### Get environment variables as TF_VAR_[name] variables - return: [variables export]
	make terraform-export-variables-from-shell PATTERN="^(AWS|TX|TEXAS|NHSD|TERRAFORM)"
	make terraform-export-variables-from-shell PATTERN="^(DB|DATABASE|APP|APPLICATION|UI|API|SERVER|HOST|URL)"
	make terraform-export-variables-from-shell PATTERN="^(PROFILE|ENVIRONMENT|BUILD|PROGRAMME|ORG|SERVICE|PROJECT)"

terraform-export-variables-from-secret: ### Get secret as TF_VAR_[name] variables - mandatory: NAME|DEPLOYMENT_SECRETS=[secret name]; return: [variables export]
	if [ -n "$(NAME)" ] || [ -n "$(DEPLOYMENT_SECRETS)" ]; then
		secret=$$(make secret-fetch NAME=$(or $(NAME), $(DEPLOYMENT_SECRETS)))
		exports=$$(make terraform-export-variables-from-json JSON="$$secret")
		echo "$$exports"
	fi

terraform-export-variables-from-shell: ### Convert environment variables as TF_VAR_[name] variables - mandatory: VARS=[comma-separated environment variable names]|PATTERN="^AWS_"; optional: EXCLUDE=[pattern]; return: [variables export]
	OLDIFS=$$IFS; IFS=$$'\n';
	if [ -n "$(PATTERN)" ]; then
		# `exclude` cannot be empty therefore set it to a random string
		[ -n "$(EXCLUDE)" ] && exclude="$(EXCLUDE)" || exclude=$$(make secret-random)
		for str in $$(env | grep -Ei "$(PATTERN)" | sed -e 's/[[:space:]]*$$//' | grep -Ev '^[A-Za-z0-9_]+=$$' | sort | grep -Ev "$$exclude"); do
			key=$$(cut -d "=" -f1 <<<"$$str" | tr '[:upper:]' '[:lower:]')
			value=$$(cut -d "=" -f2- <<<"$$str")
			echo "export TF_VAR_$${key}='$$(echo $${value} | sed -e 's/[[:space:]]/_/g' | sed 's/"//g' | sed "s/'//g")'"
		done
	fi
	if [ -n "$(VARS)" ]; then
		for str in $$(echo "$(VARS)" | sed 's/,/\n/g' | sort); do
			key=$$(echo "$$str" | tr '[:upper:]' '[:lower:]')
			value=$$(cut -d "=" -f2- <<<"$$str")
			echo "export TF_VAR_$${key}='$$(echo $${value} | sed -e 's/[[:space:]]/_/g' | sed 's/"//g' | sed "s/'//g")'"
		done
	fi
	IFS=$$OLDIFS

terraform-export-variables-from-json: ### Convert JSON to Terraform input exported as TF_VAR_[name] variables - mandatory: JSON='{"key":"value"}'|JSON="$$(echo '$(JSON)')"; return: [variables export]
	OLDIFS=$$IFS; IFS=$$'\n';
	for str in $$(echo '$(JSON)' | make -s docker-run-tools CMD="jq -rf $(JQ_DIR_REL)/json-to-env-vars.jq" | sort); do
		key=$$(cut -d "=" -f1 <<<"$$str" | tr '[:upper:]' '[:lower:]')
		value=$$(cut -d "=" -f2- <<<"$$str")
		echo "export TF_VAR_$${key}='$$(echo $${value} | sed -e 's/[[:space:]]/_/g')'"
	done
	IFS=$$OLDIFS

# ==============================================================================

_terraform-stacks: ### Set up infrastructure for a given list of stacks - mandatory: STACK|STACKS|INFRASTRUCTURE_STACKS=[comma-separated names],CMD=[Terraform command]; optional: PROFILE=[name]
	# set up
	eval "$$(make aws-assume-role-export-variables)"
	eval "$$(make terraform-export-variables)"
	# run stacks
	for stack in $$(echo $(or $(STACK), $(or $(STACKS), $(INFRASTRUCTURE_STACKS))) | tr "," "\n"); do
		make _terraform-stack STACK="$$stack" CMD="$(CMD)" AWS_PROFILE=""
	done

_terraform-stack: ### Set up infrastructure for a single stack - mandatory: STACK=[name],CMD=[Terraform command]; optional: TERRAFORM_REINIT=false,PROFILE=[name]
	if [ -d $(TERRAFORM_DIR)/common ]; then
		make _terraform-remove-common STACK=$(STACK)
		make _terraform-copy-common STACK=$(STACK)
	fi
	if [ -f $(TERRAFORM_DIR)/$(STACK)/terraform.tf ]; then
		if [ "$(TERRAFORM_USE_STATE_STORE)" == false ]; then
				sed -i 's/  backend "s3"/  #backend "s3"/g' $(TERRAFORM_DIR)/$(STACK)/terraform.tf
		else
				sed -i 's/  #backend "s3"/  backend "s3"/g' $(TERRAFORM_DIR)/$(STACK)/terraform.tf
		fi
	fi
	if [[ ! "$(TERRAFORM_REINIT)" =~ ^(false|no|n|off|0|FALSE|NO|N|OFF)$$ ]] || [ ! -f $(TERRAFORM_DIR)/$(STACK)/terraform.tfstate ]; then
		make _terraform-reinitialise DIR="$(TERRAFORM_DIR)" STACK="$(STACK)"
	fi
	make docker-run-terraform DIR="$(TERRAFORM_DIR)/$(STACK)" CMD="$(CMD)"
	if [ -d $(TERRAFORM_DIR)/common ]; then
		make _terraform-remove-common STACK=$(STACK)
	fi

_terraform-reinitialise: ### Reinitialise infrastructure state - mandatory: STACK=[name]; optional: TERRAFORM_DO_NOT_REMOVE_STATE_FILE=true,PROFILE=[name],HIDE_OUTPUT=false
	[ "$(TERRAFORM_DO_NOT_REMOVE_STATE_FILE)" != true ] && rm -rf $(DIR)/$(STACK)/*terraform.tfstate*
	if [[ "$(HIDE_INIT)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
		make _terraform-initialise STACK="$(STACK)" > /dev/null 2>&1
	else
		make _terraform-initialise STACK="$(STACK)"
	fi

_terraform-initialise: ### Initialise infrastructure state - mandatory: STACK=[name]; optional: TERRAFORM_USE_STATE_STORE=false,PROFILE=[name]
	if [[ "$(TERRAFORM_USE_STATE_STORE)" =~ ^(false|no|n|off|0|FALSE|NO|N|OFF)$$ ]]; then
		make docker-run-terraform DIR="$(TERRAFORM_DIR)/$(STACK)" CMD="init"
	else
		make docker-run-terraform DIR="$(TERRAFORM_DIR)/$(STACK)" CMD=" \
			init \
				-backend-config="bucket=$(TERRAFORM_STATE_STORE)" \
				-backend-config="dynamodb_table=$(TERRAFORM_STATE_LOCK)" \
				-backend-config="encrypt=true" \
				-backend-config="key=$(TERRAFORM_STATE_KEY)/$(STACK)/terraform.state" \
				-backend-config="region=$(AWS_REGION)" \
		"
	fi

_terraform-delete-state-store: ### Delete Terraform state store - mandatory: STACK=[name]; optional: PROFILE=[name]
	make -s docker-run-tools ARGS="$$(echo $(AWSCLI) | grep awslocal > /dev/null 2>&1 && echo '--env LOCALSTACK_HOST=$(LOCALSTACK_HOST)' ||:)" CMD=" \
		$(AWSCLI) s3 rm \
			s3://$(TERRAFORM_STATE_STORE)/$(TERRAFORM_STATE_KEY)/$(STACK) \
			--recursive \
	"

_terraform-delete-state-lock: ### Delete Terraform state lock - mandatory: STACK=[name]; optional: PROFILE=[name]
	key='{"LockID": {"S": "$(TERRAFORM_STATE_STORE)/$(TERRAFORM_STATE_KEY)/$(STACK)/terraform.state-md5"}}'
	make -s docker-run-tools ARGS="$$(echo $(AWSCLI) | grep awslocal > /dev/null 2>&1 && echo '--env LOCALSTACK_HOST=$(LOCALSTACK_HOST)' ||:)" CMD=" \
		$(AWSCLI) dynamodb delete-item \
			--table-name $(TERRAFORM_STATE_LOCK) \
			--key '$$key' \
		"

# ==============================================================================

_terraform-copy-common: # Copies all common terraform files to the desired stack - Mandatory: STACK - name of stack to copy common terraform file into
	cp $(TERRAFORM_DIR)/common/common-*.tf $(TERRAFORM_DIR)/$(STACK)

_terraform-remove-common: # Removes all common terraform files from the desired stack - Mandatory: STACK - name of stack to clean up common terraform file from
	rm -f $(TERRAFORM_DIR)/$(STACK)/common-*.tf

# ==============================================================================

terraform-check-module-versions: ### Check Terraform module versions alignment
	# acm terraform-aws-modules/acm/aws
	name="terraform acm terraform-aws-modules/acm/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/acm/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-acm/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# alb terraform-aws-modules/alb/aws
	name="terraform alb terraform-aws-modules/alb/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/alb/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-alb/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# autoscaling terraform-aws-modules/autoscaling/aws
	name="terraform autoscaling terraform-aws-modules/autoscaling/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/autoscaling/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-autoscaling/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# dynamodb terraform-aws-modules/dynamodb-table/aws
	name="terraform dynamodb terraform-aws-modules/dynamodb-table/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/dynamodb/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-dynamodb-table/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# ecs terraform-aws-modules/ecs/aws
	name="terraform ecs terraform-aws-modules/ecs/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/ecs/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-ecs/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# iam-roles terraform-aws-modules/iam/aws
	name="terraform iam-roles terraform-aws-modules/iam/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/iam-roles/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-iam/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# rds terraform-aws-modules/rds/aws
	name="terraform rds terraform-aws-modules/rds/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/rds/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-rds/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# route53 terraform-aws-modules/route53/aws
	name="terraform route53 terraform-aws-modules/route53/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/route53/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-route53/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# s3 terraform-aws-modules/s3-bucket/aws
	name="terraform s3 terraform-aws-modules/s3-bucket/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/s3/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-s3-bucket/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# security-group terraform-aws-modules/security-group/aws
	name="terraform security-group terraform-aws-modules/security-group/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/security-group/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-security-group/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"
	# vpc terraform-aws-modules/vpc/aws
	name="terraform vpc terraform-aws-modules/vpc/aws"
	lib_ver=$$(cat $(LIB_DIR_REL)/terraform/template/modules/vpc/main.tf | grep 'version[[:space:]]=[[:space:]]"[0-9]*\.[0-9]*\(\.[0-9]*\)\?"' | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | uniq)
	gh_ver=$$(curl -s https://github.com/terraform-aws-modules/terraform-aws-vpc/releases | grep "releases/tag" | grep -o "[0-9]*\.[0-9]*\(\.[0-9]*\)\?" | sort -V -r | head -n 1)
	echo "$$name library: $$lib_ver (current $(DEVOPS_PROJECT_VERSION))"
	echo "$$name github: $$gh_ver (latest)"

# ==============================================================================

.SILENT: \
	terraform-check-module-versions \
	terraform-export-variables \
	terraform-export-variables-from-json \
	terraform-export-variables-from-secret \
	terraform-export-variables-from-shell \
	terraform-output \
	terraform-show \
	terraform-copy-common \
	terraform-remove-common
