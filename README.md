# Fancia

Fancia is a social platform connecting people with shared interests for offline, in-person group gatherings and community building.

## infra-pipeline

This repository contains Terraform code to provision an AWS-based CI/CD pipeline for managing infrastructure and Helm deployments for the project [fancia-infra](https://github.com/fungkinchun/fancia-infra)

### Prerequisites

- AWS CLI installed and configured for the target account and profile

### Quick start

1. Define the profile to be used for deployment:

   ```bash
   export AWS_PROFILE=<your-aws-profile>
   ```

2. Initialize Terraform state (adjust backend bucket name as needed):

   ```bash
   terraform init -backend-config="bucket=${PROJECT_NAME}-infra-pipeline-terraform-state"
   ```

3. Plan and apply the infrastructure:

   ```bash
   terraform plan
   terraform apply
   ```

### Notes

- This pipeline passes values to [fancia-infra](https://github.com/fungkinchun/fancia-infra), which includes credentials for services such as [fancia-user](https://github.com/fungkinchun/fancia-backend-user).
- Update variables in `terraform.tfvars` (project_name, region, profile, GitHub connection details, and infra_credentials) before applying. Create a local `terraform.tfvars` file if it does not exist and ensure it is not checked into version control.
- Buildspec files referenced by CodeBuild projects (`buildspec_plan.yaml`, `buildspec_apply.yaml`, `buildspec_destroy.yaml`, `buildspec_helm.yaml`) must exist in the repository.
