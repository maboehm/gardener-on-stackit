resource "local_file" "environment" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    export PROJECT_ID=${jsonencode(var.project_id)}
    export CLUSTER_NAME=${jsonencode(var.cluster_name)}
    export DOMAIN_PREFIX=${jsonencode(var.domain_prefix)}
    export DOMAIN=${jsonencode(local.domain)}
    export MACHINE_TYPE=${jsonencode(var.machine_type)}
    export GARDENER_VERSION=${jsonencode(var.gardener_version)}
    export ACME_EMAIL=${jsonencode(var.acme_email)}
    export REGION=${jsonencode(var.region)}
    export KUBECONFIG="$(pwd)/kubeconfig"
  EOT
}

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/../kubeconfig"
  content         = stackit_ske_kubeconfig.garden.kube_config
  file_permission = "0600"
}

resource "local_file" "backup_credentials" {
  filename        = "${path.module}/../manifests/00-providers/backup-s3-credentials.env"
  file_permission = "0600"
  content         = <<-EOT
    accessKeyID=${stackit_objectstorage_credential.backup.access_key}
    endpoint=${local.object_storage_endpoint}
    region=${var.region}
    s3ForcePathStyle=false
    secretAccessKey=${stackit_objectstorage_credential.backup.secret_access_key}
  EOT
}

resource "local_file" "service_account_key" {
  filename        = "${path.module}/../manifests/00-providers/serviceaccount.json"
  content         = stackit_service_account_key.gardener.json
  file_permission = "0600"
}
