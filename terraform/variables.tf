variable "project_id" {
  description = "STACKIT project ID in which to create the Gardener infrastructure."
  type        = string
}

variable "region" {
  description = "STACKIT region for the SKE cluster and object storage."
  type        = string
  default     = "eu02"
}

variable "cluster_name" {
  description = "Name used for the SKE cluster and backup resources."
  type        = string
  default     = "gg"
}

variable "domain_prefix" {
  description = "STACKIT DNS zone name prefix; the domain is <prefix>.stackit.gg."
  type        = string
  default     = "demo-gg"
}

variable "machine_type" {
  description = "Machine type for the SKE worker node pool."
  type        = string
  default     = "g3i.4"
}

variable "availability_zones" {
  description = "SKE availability zones for the worker node pool."
  type        = list(string)
  default     = ["eu02-1", "eu02-2", "eu02-3"]
}

variable "node_pool_minimum" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 3
}

variable "node_pool_maximum" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 6
}

variable "gardener_version" {
  description = "Gardener operator chart version used by the README's Helm command."
  type        = string
  default     = "v1.153.1"
}

variable "acme_email" {
  description = "Email address used by the Gardener ACME certificate issuer."
  type        = string
}

variable "service_account_key_ttl_days" {
  description = "Validity of the Gardener STACKIT service-account key."
  type        = number
  default     = 7
}
