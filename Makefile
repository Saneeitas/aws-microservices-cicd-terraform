TF := terraform -chdir=terraform

.PHONY: test init plan apply destroy push-images push-deploy-files fmt validate

# Offline checks with a mocked AWS provider (no credentials, no AWS calls). Terraform >= 1.7.
test: init
	$(TF) test

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate: init
	$(TF) validate

plan:
	$(TF) plan

apply:
	$(TF) apply

destroy:
	$(TF) destroy

# Build and push both images. Needs the ECR repos to exist already
# (terraform apply -target=aws_ecr_repository.repo).
push-images:
	@set -e; \
	for svc in customer employee; do \
	  url=$$($(TF) output -json ecr_repository_urls | python3 -c "import json,sys; print(json.load(sys.stdin)['$$svc'])"); \
	  ./scripts/build_and_push.sh $$svc $$url $${AWS_REGION:-us-east-1}; \
	done

push-deploy-files:
	./scripts/push_deployment_files.sh $${AWS_REGION:-us-east-1}
