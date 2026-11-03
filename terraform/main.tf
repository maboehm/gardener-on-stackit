locals {
  domain                  = "${var.domain_prefix}.stackit.gg"
  backup_bucket_name      = "${var.cluster_name}-backup"
  object_storage_endpoint = "https://object.storage.${var.region}.onstackit.cloud"
}

#####################
## DNS Zone        ##
#####################
resource "stackit_dns_zone" "garden" {
  project_id = var.project_id
  name       = var.domain_prefix
  dns_name   = local.domain
  type       = "primary"
}


#####################
## SKE Cluster     ##
#####################
resource "stackit_ske_cluster" "garden" {
  project_id = var.project_id
  name       = var.cluster_name

  node_pools = [
    {
      name               = "worker"
      machine_type       = var.machine_type
      minimum            = var.node_pool_minimum
      maximum            = var.node_pool_maximum
      availability_zones = var.availability_zones
    }
  ]
}

resource "stackit_ske_kubeconfig" "garden" {
  project_id   = var.project_id
  cluster_name = stackit_ske_cluster.garden.name

  expiration     = 7200
  refresh        = true
  refresh_before = 3600
}

#####################
## Object Storage  ##
#####################
resource "stackit_objectstorage_bucket" "backup" {
  project_id = var.project_id
  name       = local.backup_bucket_name
}

resource "stackit_objectstorage_credentials_group" "backup" {
  project_id = var.project_id
  name       = local.backup_bucket_name
}

resource "stackit_objectstorage_credential" "backup" {
  project_id           = var.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.backup.credentials_group_id
}

#####################
## Service Account ##
#####################
resource "stackit_service_account" "gardener" {
  project_id = var.project_id
  name       = "gardener"
}

resource "stackit_authorization_project_role_assignment" "gardener_editor" {
  resource_id = var.project_id
  role        = "editor"
  subject     = lower(stackit_service_account.gardener.email)
}

resource "stackit_authorization_project_role_assignment" "gardener_isolated_network_admin" {
  resource_id = var.project_id
  role        = "iaas.isolated-network.admin"
  subject     = lower(stackit_service_account.gardener.email)
}

resource "stackit_service_account_key" "gardener" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.gardener.email
  ttl_days              = var.service_account_key_ttl_days

  depends_on = [stackit_authorization_project_role_assignment.gardener_editor]
}
