# Pinned version constraints for the workspace module. Kept in a dedicated
# file (Terraform Registry convention) so the required_version /
# required_providers block is easy to find and review.
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}
