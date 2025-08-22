# DoS Integration

## Table of Contents

- [DoS Integration](#dos-integration)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [DI Confluence Page](#di-confluence-page)
    - [Architecture](#architecture)
    - [Technology Stack](#technology-stack)
  - [Quick Start](#quick-start)
    - [Development Requirements](#development-requirements)
    - [Clone Repository](#clone-repository)
    - [AWS Authentication](#aws-authentication)
    - [Mac setup](#mac-setup)
  - [Contributing](#contributing)
  - [Development](#development)
    - [Add IP Address to IP Allow List](#add-ip-address-to-ip-allow-list)
    - [DoS Database Connection](#dos-database-connection)
    - [Python Code Formatting \& Quality](#python-code-formatting--quality)
  - [Testing](#testing)
    - [Unit Testing](#unit-testing)
      - [Where are the unit tests run?](#where-are-the-unit-tests-run)
    - [Integration Testing](#integration-testing)
      - [Where are the integration tests run?](#where-are-the-integration-tests-run)
    - [Performance Testing](#performance-testing)
      - [Where are the performance tests run?](#where-are-the-performance-tests-run)
      - [Collecting Performance Test Results](#collecting-performance-test-results)
    - [Test data and mock services](#test-data-and-mock-services)
  - [General Deployment](#general-deployment)
    - [API Key](#api-key)
    - [Artefacts Versioning](#artefacts-versioning)
      - [Docker Images](#docker-images)
    - [CI/CD Pipelines](#cicd-pipelines)
    - [Deployment From the Command-line](#deployment-from-the-command-line)
    - [Branching Strategy](#branching-strategy)
    - [Branch Naming for Automatic Deployments](#branch-naming-for-automatic-deployments)
    - [Branch Naming to not automatically deploy](#branch-naming-to-not-automatically-deploy)
  - [Blue/Green Deployments](#bluegreen-deployments)
    - [Blue/Green Deployment Strategy](#bluegreen-deployment-strategy)
    - [Blue/Green Deployment Process](#bluegreen-deployment-process)
    - [Useful Blue/Green Deployment Commands](#useful-bluegreen-deployment-commands)
      - [Update shared resources](#update-shared-resources)
      - [Trigger Blue/Green Deployment Pipeline](#trigger-bluegreen-deployment-pipeline)
      - [Trigger Shared Resources Deployment Pipeline](#trigger-shared-resources-deployment-pipeline)
      - [Undeploy Blue/Green Environment](#undeploy-bluegreen-environment)
      - [Undeploy Shared Resources Environment](#undeploy-shared-resources-environment)
      - [Rollback Blue/Green Environment](#rollback-bluegreen-environment)
    - [Quick Re-deploy](#quick-re-deploy)
    - [Remove Deployment From the Command-line](#remove-deployment-from-the-command-line)
    - [Remove deployment with commit tag](#remove-deployment-with-commit-tag)
    - [Remove deployment on Pull Request merge](#remove-deployment-on-pull-request-merge)
    - [Secrets](#secrets)
    - [AWS Access](#aws-access)
  - [Production Deployment](#production-deployment)
    - [Prerequisites](#prerequisites)
    - [Guiding Principles](#guiding-principles)
  - [Operation](#operation)
    - [Observability](#observability)
      - [Tracing Change events and requests Correlation Id](#tracing-change-events-and-requests-correlation-id)
    - [Cloud Environments](#cloud-environments)
    - [Runbooks](#runbooks)
  - [Product](#product)
    - [Communications](#communications)
    - [Documentation](#documentation)

## Overview

The NHS.uk website, and the DoS (Directory of Services) service are separate entities which both store a lot of the same important data about Pharmacies/Dentists and other health organisations around the UK. The management of these individual services therefore needs to update information in multiple places online to keep their data fully up to date for their users.

The DoS Integration project aims to keep any updates made on NHS.uk consistent with DoS by comparing any updates and creating any change requests needed to keep the information up to date.

### DI Confluence Page

<https://nhsd-confluence.digital.nhs.uk/display/DI/DoS+Integration+Home>

### Architecture

![Architecture](./documentation/diagrams/DoS%20Integration-Components.drawio.png)

### Technology Stack

The current technology stack is:

- Python - Main programming language
- AWS: Lambda, DynamoDB, API Gateway, CodePipeline, KMS, SQS, S3
- Terraform

## Quick Start

### Development Requirements

It is recommended to use either a macOS or Linux. If using a Windows machine it is highly recommended to run a VM using WSL2 to create a Linux environment to work with. Try not to use the Windows command line.

A mac is no longer required for basic development since task branches are automatically built on the push of a new commit. However the build/deploy commands currently are only designed to work with macOS.

This project contains a macOS environment which can be installed and setup that gives the user a wide range of tools useful for development. More info on this is in the mac setup section.

The main components you will need for _basic_ development work, are your OS version of the below.

- A VPN Client (OpenVPN or Tunnelblick are 2 NHS Digital suggested options)
- Git
- Python (The project currently runs on 3.12)
- AWS CLI
- Docker/Podman

### Clone Repository

Clone the repository

    git clone git@github.com:NHSDigital/dos-integration.git
    cd ./dos-integration

### AWS Authentication

Please, ask one of your colleagues for the AWS account numbers used by the project. You will use these as roles which you will assume from your account.

Instructions and tips for basic authentication for AWS can be found online. Any method that lets you authenticate and assume roles will work with this project.
<https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html>

There is also an automated method to setup AWS access within the mac setup. Once the mac step up scripts have been run, the following command can be used to choose and switch between AWS roles automatically.

    assume

### Mac setup

The following is equivalent to the `curl -L bit.ly/make-devops-macos-setup | bash` command.

    make macos-setup

There are configuration options that should be set before proceeding. The following command will ensure that tooling like `docker` and `git` are going to operate as expected, including local secret scanning and code formatting are enabled. Make sure you authenticated in the AWS Non-Prod account first before running `make setup`

    make setup

Please, ask one of your colleagues for the AWS account numbers used by the project. The next command will prompt you to provide them. This information can be sourced from a properly set up project by running `make show-configuration | grep ^AWS_ACCOUNT_ID_`

    make devops-setup-aws-accounts

## Contributing

Here is the list of the development practices that have to be followed by the team and the individual members:

- Only use single canonical branch **develop**. Any intermediate branch significantly increases the maintenance overhead of the repository.
- Apply the git rebase workflow and never merge from develop to a task branch. Follow the **squash-rebase-merge** pattern to keep the history linear and clean.
- Cryptographically sign your commits using **GPG** to ensure its content have not been tampered with.
- Format the summary message of your pull request (merge request) using the following pattern **"JIRA-XXX Summary of the change being made"** for complies and clarity as well as to enable tooling to produce release notes automatically.
- Announce your PR/MR on the development Slack channel to allow any team member to review it and to share the knowledge. A change can be merged only if all comments have been addressed and it has been **approved by at least one peer**. Make good use of paring/mobbing/swarming practices for collaborative coding.

Before starting any work, please read [Contributing.md](./documentation/Contributing.md) for more detailed instructions.

## Development

### Add IP Address to IP Allow List

To find your public IP you can visit <https://www.google.com/search?q=whats+my+ip>

An IP Allowlist is kept in secrets manager for each environment (dev, demo, live, etc). The Secret Name for each is of the format

    uec-dos-int-XXXX-ip-addresses-allowlist

where XXXX is the name of the environment in lowercase. For most development work you only need to add your IP to the dev environments list.

You can also add your IP to the lists with a script.

Prerequisites (first setup only)

    make tester-build

To add an IP address to the IP allow lists, Ensure you're authenticated for access to AWS and run the following command.

    make update-all-ip-allowlists [WARNING: Not working the stack for this one needs fixing (likely SSO issue)]

To add an IP address to the IP allow lists and deploy the allow list to environment run the following command.The `PROFILE` delineates which environment to update with the latest IP allow list. Set `ENVIRONMENT` if you are changing an environment not linked to your branch

    make update-ip-allowlists-and-deploy-allowlist PROFILE=dev [WARNING: Not working the stack for this one needs fixing (likely SSO issue)]

### DoS Database Connection

The following vars are required for the project to establish a connection to the DoS writer database (or a Reader).
`Host, Port, Database, Username, Password, Schema`
These variable will be stored in AWS Secrets Manager and will be retrieved by the project at either deployment or runtime.

### Python Code Formatting & Quality

Python code is required be formatted and linted by Ruff.

To run ruff on you branch:

    make python-run-ruff-fixes

## Testing

List all the type of test suites included and provide instructions how to execute them

- Unit
- Integration
- Performance

### Unit Testing

Unit testing is to test the functions within each lambda. This testing is done on the local system to where the commands are run e.g CLI, CI/CD Pipelines

This includes:

- Function calls
- Correct data types and data returned from function
- All paths tested of the application

This testing is generally done by a developer

To run unit tests run the following commands

    make tester-build
    make unit-test

For coverage run

    make coverage-report

The unit tests are run using pytest and coverage (both available to download via pip). If you want to run the unit tests without the setup, or want to target only certain files/folders you can run the tests in your own environment directly by going to the /application directory and running.

    python3 -m pytest --cov=. -vv

#### Where are the unit tests run?

The unit tests are run in multiple places. They are developed and run locally. They are also run in GitHub Actions on each pull request and commit on develop. The unit tests are also run in the development pipeline on each deployment merge into develop.

### Integration Testing

Integration Testing is used to test the functional capabilities of the individual component work together with mocks and partner services. Asserting that individual components can work in harmony together, achieving the overall business goals. This testing is done on AWS to test the connection between components.

This testing includes:

- No Mocking. Except Emails which are mocked in NonProd
- Check data when passed between components
- Meets business needs of the application

This testing is generally done by a tester

Prerequisites

    assume # Granted assume AWS Role
    Sign into Non-Prod VPN #  To connect to lambdas within the VPC
    IP is in the IP Allow List # To connect to the API Gateway
    make tester-build

To run unit tests run the following commands

    make integration-test PROFILE=dev TAG=complete PARALLEL_TEST_COUNT=10

Tests are currently separated into many tags. These tags are used to run the tests in parallel. The tags are as follows:

- general: Tests that do not fall into other groups
- validation: Tests that validate incorrect data is not processed
- slack_and_infrastructure: Tests that validate slack alerts and infrastructure (including quality checker tests)
- reporting: Tests that validate reporting
- opening_times: Tests that check/update opening times

#### Where are the integration tests run?

Integration tests are run locally against development environments. They are also run in the development pipeline on each deployment merge into develop.

### Performance Testing

Performance testing is the practice of evaluating how a system performs in terms of responsiveness and stability under a particular workload. Performance tests are typically executed to examine speed, robustness, reliability of the application.

This testing includes:

- Checking non functional requirements (performance/reliability)

This testing is generally done by a tester

To run the performance tests run the following commands after you have run `assume` to sign into Non-Prod

To run a stress test

    make tester-build
    make stress-test PROFILE=perf ENVIRONMENT=perf START_TIME=$(date +%Y-%m-%d_%H-%M-%S)
    # Wait for the test to complete
    # Collect data from performance testing

Note: if you have any errors consider reducing number of users or increasing the docker resources

To run a load test

    make tester-build
    make load-test PROFILE=perf ENVIRONMENT=perf START_TIME=$(date +%Y-%m-%d_%H-%M-%S)
    # Wait for the test to complete
    # Collect data from performance testing

#### Where are the performance tests run?

Performance tests are run locally against development environments. They are also run in the performance AWS CodeBuild stages adhoc against the performance environment.

#### Collecting Performance Test Results

Performance Test results can be collected

    make performance-test-results PROFILE= ENVIRONMENT= START_TIME=[timestamp], END_TIME=[timestamp]

Example

    make performance-test-results PROFILE=perf ENVIRONMENT=perf START_TIME=2023-11-28T10:00:00Z END_TIME=2023-11-28T12:00:00Z

For more details review the make target documentation with the make file

### Test data and mock services

- How the test data set is produced
- Are there any mock services in place

## General Deployment

### API Key

API Key(s) must be generated prior to external API-Gateways being set up. It is automatically created when deploying with `make deploy PROFILE=dev`. However the dev, demo and live profiles' key must be generated prior to deployment of the API gateway.

### Artefacts Versioning

Releases are semantically versioned using the following format:

    MAJOR.MINOR

All standard releases are considered major releases. Minor releases are used for hotfixes.

Deployment images are instead tagged with the commit hash of the commit it was built from. Standard non deployment images are tagged with the timestamp and commit hash of the commit they were built from.

#### Docker Images

Docker images for releases are tagged with the version of the pipeline.

However in the task deploy and test CodeBuild uses a timestamp and commit hash tag.

### CI/CD Pipelines

![CI/CD Pipelines](./documentation/diagrams/DevOps-Pipelines%20and%20Automation.drawio.png)

All `test` CodeBuild automations can be found in the AWS CodePipeline/CodeBuild areas in the `Texas` `MGMT` account.

More information can be found on DoS Integration's confluence workspace <https://nhsd-confluence.digital.nhs.uk/display/DI/Code+Development+and+Deployment>

### Deployment From the Command-line

    make build-and-deploy PROFILE=dev # Builds docker images, pushes them and deploys to lambda

### Branching Strategy

More information can be found on DoS Integration's confluence workspace <https://nhsd-confluence.digital.nhs.uk/display/DI/Code+Development+and+Deployment>

![Branching Strategy](./documentation/diagram/../diagrams/DoS%20Integration-GitHub.drawio.png)

### Branch Naming for Automatic Deployments

For a branch to be automatically deployed on every push the branch must be prefixed with `task`. This will then be run on an AWS CodeBuild stage to deploy the code to a task environment. e.g `task/DS-123_My_feature_branch`

Once a branch which meets this criteria has been pushed then it will run a build and deployment for the environment and notify the dos-integration-dev-status channel with the status of your deployment.

### Branch Naming to not automatically deploy

For a branch that is meant for testing or another purpose and you don't want it to deploy on every push to the branch. It must be prefixed with one of these `spike|automation|test|bugfix|hotfix|fix|release|migration`. e.g. `fix/DS-123_My_fix_branch`

## Blue/Green Deployments

### Blue/Green Deployment Strategy

To deploy a new version of the application in a blue green way it uses multiple components. Such as resources that should persist between deployments, such as the database, and resources that should be recreated with each deployment, such as the lambda functions.

![Blue/Green Deployment Strategy](./documentation/diagrams/DoS%20Integration-Blue-Green-Deployments.drawio.png)

### Blue/Green Deployment Process

This guide will walk you through the steps to deploy a new version of the application in a blue green way. It assumes you have already deployed the application once and have a blue environment.

This guide will use the following environment names:
Live - The Shared Environment
gggggg - Commit Hash for the Green New Blue/Green Environment.
bbbbbb - Commit Hash for the Blue Current Blue/Green Environment

1. Create a new blue/green environment with the new version. This creates a new blue/green environment ready to be switched to.

    make deploy-blue-green-environment PROFILE=[live/demo] ENVIRONMENT=[blue-green-environment(short-commit-hash)] VERSION=[s3-file-version] SHARED_ENVIRONMENT=[shared-resources-environment] BLUE_GREEN_ENVIRONMENT=[blue-green-environment(short-commit-hash)]

    - Example
    make deploy-blue-green-environment PROFILE=live ENVIRONMENT=ggggggg VERSION=[s3-file-version] SHARED_ENVIRONMENT=[live] BLUE_GREEN_ENVIRONMENT=[ggggg]

2. Unlink the current blue/green environment from the shared resources. This will remove any links between the blue/green environment and the shared resources.

    make unlink-blue-green-environment PROFILE=[live/demo] ENVIRONMENT=[shared-resources-environment]  SHARED_ENVIRONMENT=[shared-resources-environment] BLUE_GREEN_ENVIRONMENT=[blue-green-environment(short-commit-hash)] TF_VAR_previous_blue_green_environment=[OPTIONAL: current-blue-green-environment(short-commit-hash)]

    - Example
    make unlink-blue-green-environment PROFILE=live ENVIRONMENT=live SHARED_ENVIRONMENT=live BLUE_GREEN_ENVIRONMENT=ggggggg TF_VAR_previous_blue_green_environment=bbbbbbb

3. Link the new blue/green environment to the shared resources. This will link the new blue/green environment to the shared resources.

    make link-blue-green-environment PROFILE=[live/demo] ENVIRONMENT=[shared-resources-environment] BLUE_GREEN_ENVIRONMENT=[new-blue-green-environment]

    - Example
    make link-blue-green-environment PROFILE=live ENVIRONMENT=live BLUE_GREEN_ENVIRONMENT=gggggg

### Useful Blue/Green Deployment Commands

#### Update shared resources

To update the shared resources run the following command.
Note: The shared environment must be unlinked from the blue/green environment before running this command. Then the blue/green environment must be linked to the shared environment after running this command.

    make deploy-shared-resources PROFILE=[live/demo] ENVIRONMENT=[shared-resources-environment] SHARED_ENVIRONMENT=[shared-resources-environment]

    - Example
    make deploy-shared-resources PROFILE=live ENVIRONMENT=live SHARED_ENVIRONMENT=live

#### Trigger Blue/Green Deployment Pipeline

This will trigger the blue/green deployment pipeline to deploy the commit hash to the blue/green environment in the MGMT account.
The AWS CodePipeline name will be `uec-dos-int-dev-cicd-blue-green-deployment-pipeline`

COMMIT should be the commit hash of the commit you want to deploy.
This should only be done from main branch.

An approval stage stops this command from automatically deploying to Live. But it will automatically apply to a dev and a demo environment.

    make tag-commit-to-deploy-blue-green-environment COMMIT=[short-commit-hash]

    - Example
    make tag-commit-to-deploy-blue-green-environment COMMIT=ggggggg

#### Trigger Shared Resources Deployment Pipeline

This will trigger the shared resources deployment pipeline to deploy the commit hash to the shared resources environment in the MGMT account.
The AWS CodePipeline name will be `uec-dos-int-dev-cicd-shared-resources-deployment-pipeline`

COMMIT should be the commit hash of the commit you want to deploy.
This should only be done from main branch.

An approval stage stops this command from automatically deploying to Live. But it will automatically apply to a dev and a demo environment.

    make tag-commit-to-deploy-shared-resources COMMIT=[short-commit-hash]

    - Example
    make tag-commit-to-deploy-shared-resources COMMIT=ggggggg

#### Undeploy Blue/Green Environment

This will remove the blue/green environment and is intended to be used when the blue/green rollback environment is no longer needed.

Note: If the blue/green environment is linked to the shared resources environment then it must be unlinked before running this command.

    make undeploy-blue-green-environment PROFILE=[live/demo] ENVIRONMENT=[blue-green-environment] SHARED_ENVIRONMENT=[shared-resources-environment] BLUE_GREEN_ENVIRONMENT=[blue-green-environment]
    - Example
    make tag-commit-to-deploy-blue-green-environment COMMIT=ggggggg

#### Undeploy Shared Resources Environment

This will remove the shared resources environment and is intended to be used when the shared resources environment is no longer needed.

Note: No blue/green environments can exist for this shared resources environment when running this command.
If they do the blue/green environments must be unlinked and undeployed first.

    make undeploy-shared-resources PROFILE=[live/demo] ENVIRONMENT=[blue-green-environment] SHARED_ENVIRONMENT=[shared-resources-environment] BLUE_GREEN_ENVIRONMENT=[blue-green-environment]

    - Example
    make undeploy-shared-resources PROFILE=live ENVIRONMENT=live SHARED_ENVIRONMENT=live BLUE_GREEN_ENVIRONMENT=ggggggg

#### Rollback Blue/Green Environment

This will rollback the blue/green environment to the previous version. It's best to use the commit of the version you are intending to rollback to ensure the Terraform works correctly together.

    make rollback-blue-green-environment PROFILE=[live/demo/dev] SHARED_ENVIRONMENT=[shared-resources-environment] COMMIT=[short-commit-hash]

    - Example
    make tag-commit-to-rollback-blue-green-environment PROFILE=dev SHARED_ENVIRONMENT=cicd-test COMMIT=c951156

### Quick Re-deploy

To quick update the lambdas run the following command. Note this only updates the lambdas

    make quick-build-and-deploy PROFILE=dev ENVIRONMENT=ds-123 # Environment is optional if your branch is prefixed with task/DS-xxx

### Remove Deployment From the Command-line

    make undeploy PROFILE=dev # Builds docker images, pushes them and deploys to lambda

### Remove deployment with commit tag

You can remove a dev deployment using a single command to create a tag which then runs an AWS CodeBuild project that will remove that environment

    make tag-commit-to-destroy-environment ENVIRONMENT=[environment to destroy] COMMIT=[short commit hash]
    e.g. make tag-commit-to-destroy-environment ENVIRONMENT=ds-363 COMMIT=2bc43dd // This destroys the ds-363 dev environment

### Remove deployment on Pull Request merge

When a pull request is merged it will run an AWS CodeBuild project that will destroy the environment if it exists.
The AWS CodeBuild project can be found within the development-pipeline Terraform stack.

### Secrets

Where are the secrets located, i.e. AWS Secrets Manager, under the `$(PROJECT_ID)-$(PROFILE)/deployment` secret name and variable `$(DEPLOYMENT_SECRETS)` should be set accordingly.

### AWS Access

To be able to interact with a remote environment, please make sure you have set up your AWS CLI credentials and
Assume the right AWS account using the following command

    assume

## Production Deployment

### Prerequisites

The pipelines Terraform stack must be deployed

    make deploy-development-and-deployment-tools ENVIRONMENT=dev

### Guiding Principles

List of the high level principles that a product /development team must adhere to:

- The solution has to be coded in the open - e.g. NHSD GitHub org
- Be based on the open standards, frameworks and libraries
- API-first design
- Test-first approach
- Apply the automate everything pattern
- AWS-based cloud solution deployable to the NHSD CPaaS Texas platform
- Use of the Make DevOps automation scripts (macOS and Linux)

## Operation

### Observability

- Logging
  - Indexes
  - Format
- Tracing
  - AWS X-Ray Trace Ids (These are included in logs)
  - `correlation-id` and `reference` provide a common key to track change events across systems: NHS UK Profile Editor and DoS Integration
- Monitoring
  - Dashboards
- Alerting
  - Triggers
  - Service status
- Fitness functions
  - What do we measure?

What are the links of the supporting systems?

#### Tracing Change events and requests Correlation Id

To be able to track a change event and the change requests it can become across systems a common id field is present on logs related to each event. The id is generated in `Profile Editor` (NHS UK) which is then assigned to the `correlation-id` header of the request send to our (DoS Integration) endpoint, for a given change event. The `correlation-id` header is then used throughout the handling of the change event in `DoS Integration`.

If a change event does result in change requests being created for `DoS` then the change requests have a `reference` key with the value being the correlation id.

The events can be further investigated in DoS Integration process by using the X-Ray trace id that is associated with the log that has the correlation id.

### Cloud Environments

List all the profiles

- Dev
  - Profile: `dev`
  - Used for development, testing and integration. This is the default profile in Non-Production environments.
- Demo
  - Profile: `demo`
  - This is the profile used for the demo environment which is used for user acceptance testing and smoke testing.
- Live
  - Profile: `live`
  - This is the profile used for the live environment which is used for production.

### Runbooks

The runbooks for this project can be found on the DI confluence.
<https://nhsd-confluence.digital.nhs.uk/display/DI/Runbooks>

## Product

### Communications

- Slack channels
  - Getting Started (Private: Ask for invite) `di-get-started`
    - Handy tips on how to get started as part of the DoS Integration team
  - Full Development Team (Private: Ask for invite) `dos-integration-devs`
    - For team conversations and team notifications
  - Swarming Channel (Public) `dos-integration-swarming`
    - For team meetings and swarming sessions. Generally used for huddles.
- TO DO SLACK CHANNELS
  - CI/CD and data pipelines, processes & Service status, `dos-integration-dev-status` and `dos-integration-live-status`
- Email addresses in use, e.g. `[service.name]@nhs.net`

### Documentation

- Sprint board link

  <https://nhsd-jira.digital.nhs.uk/secure/RapidBoard.jspa?rapidView=3875>

  Note this sprint board requires permissions for both APU (PU project) and DI project

- Backlog link

  <https://nhsd-jira.digital.nhs.uk/secure/RapidBoard.jspa?rapidView=3875&view=planning&issueLimit=100>

- Roadmap

  <https://nhsd-confluence.digital.nhs.uk/display/DI/Roadmap>

- Risks register

  We have a risk register but not accessible/viewable by the development team. So if a new risk needs to be added the Delivery Manager is the best to talk to.

- Documentation workspace link

  Documentation is stored in the [documentation](documentation) folder

- Confluence

  A separate confluence space has been set up for the DoS Integration Project

  <https://nhsd-confluence.digital.nhs.uk/display/DI/DoS+Integration+Home>

- Definition of Ready/Done

  <https://nhsd-confluence.digital.nhs.uk/pages/viewpage.action?pageId=293247477>

- Ways of working

  <https://nhsd-confluence.digital.nhs.uk/display/DI/DI+Ways+of+Working>
