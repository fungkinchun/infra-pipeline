terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }

  backend "s3" {
    bucket       = "fancia-infra-terraform-state"
    key          = "fancia-infra/terraform.tfstate"
    region       = "eu-west-2"
    profile      = "AdministratorAccess-562676253586"
    encrypt      = true
    use_lockfile = true
  }
}
