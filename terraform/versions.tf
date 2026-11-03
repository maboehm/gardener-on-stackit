terraform {
  required_version = ">= 1.10.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "0.121.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0"
    }
  }
}

provider "stackit" {
  default_region        = var.region
  enable_beta_resources = true
  experiments           = ["iam"]
}
