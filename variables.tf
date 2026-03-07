variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment of the project (e.g., dev, staging, prod)"
}

variable "region" {
  type        = string
  description = "The region of the project"
  default     = "eu-west-2"
}

variable "profile" {
  type        = string
  description = "The AWS profile to use for authentication"
  default     = "default"
}

variable "github_username" {
  type        = string
  description = "The GitHub username for authentication"
}

variable "github_token" {
  type        = string
  description = "The GitHub token for authentication"
}

variable "infra_credentials" {
  description = "Central map of infrastructure credentials and configuration"
  type = object({
    project_name    = string
    region          = string
    profile         = string
    github_username = string
    github_token    = string

    repo_names = list(string)

    s3_credentials = object({
      BUCKET_ACCESS_KEY = string
      BUCKET_SECRET_KEY = string
      REGION            = string
      BUCKET_NAME       = string
      BUCKET_ENDPOINT   = string
    })

    smtp_credentials = object({
      SMTP_USERNAME = string
      SMTP_PASSWORD = string
    })
  })
}
