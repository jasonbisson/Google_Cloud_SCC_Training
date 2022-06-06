# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  sample_csv_name    = "CCRecords_1564602825.csv"
}

resource "random_id" "random_suffix" {
  byte_length = 2
}

resource "google_project_service" "project_services" {
  project                    = var.project_id
  count                      = var.enable_apis ? length(var.activate_apis) : 0
  service                    = element(var.activate_apis, count.index)
  disable_on_destroy         = var.disable_services_on_destroy
  disable_dependent_services = var.disable_dependent_services
}

module "org-policy1" {
  source      = "terraform-google-modules/org-policy/google"
  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "compute.requireShieldedVm"
  policy_type = "boolean"
  enforce     = false
}

module "org-policy2" {
  source      = "terraform-google-modules/org-policy/google"
  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "compute.requireOsLogin"
  policy_type = "boolean"
  enforce     = false
}

module "org-policy3" {
  source      = "terraform-google-modules/org-policy/google"
  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "iam.disableServiceAccountKeyCreation"
  policy_type = "boolean"
  enforce     = false
}

module "org-policy4" {
  source      = "terraform-google-modules/org-policy/google"
  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "iam.disableServiceAccountCreation"
  policy_type = "boolean"
  enforce     = false
}

resource "google_project_organization_policy" "project_policy_list_allow_all" {
  for_each     = toset(var.constraints)
  project    = var.project_id
  constraint = each.value
  list_policy {
    allow {
      all = true
    }
  }
}

resource "time_sleep" "wait_for_org_policy" {
  depends_on = [google_project_organization_policy.project_policy_list_allow_all]
  create_duration = "90s"
}



/***********************************************
  GCS Bucket 
 ***********************************************/

resource "google_storage_bucket" "batch_data" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.bucket_name_prefix}-${random_id.random_suffix.hex}"
  location                    = var.default_region
  labels                      = var.storage_bucket_labels
  force_destroy = true
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

/***********************************************
  GKE
 ***********************************************/

resource "google_compute_firewall" "icmp" {
  project     = var.project_id 
  name        = "allow-icmp"
  network     = var.network
  description = "Creates firewall for icmp"
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
  depends_on = [module.gcp-network]
}

resource "google_compute_firewall" "ssh" {
  project     = var.project_id 
  name        = "allow-ssh"
  network     = var.network
  description = "Creates firewall for ssh"
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  depends_on = [module.gcp-network]
}


resource "google_compute_firewall" "internal" {
  project     = var.project_id 
  name        = "allow-internal"
  network     = var.network
  description = "Creates firewall for all internal traffic"
  allow {
    protocol = "all"
  }
  source_ranges = ["10.0.0.0/17"]
  depends_on = [module.gcp-network]
}

module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 3.1"
  project_id   = var.project_id
  network_name = var.network

  subnets = [
    {
      subnet_name           = "${var.project_id}-${var.subnetwork}"
      subnet_ip             = "10.0.0.0/17"
      subnet_region         = var.default_region
      subnet_private_access = "true"
    }
  ]

  secondary_ranges = {
    "${var.project_id}-${var.subnetwork}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 19.0"
  project_id     = var.project_id 
  name              = var.environment
  region            = var.default_region
  network                 = module.gcp-network.network_name
  subnetwork              = module.gcp-network.subnets_names[0]
  ip_range_pods     = var.ip_range_pods_name
  ip_range_services = var.ip_range_services_name
}

/***********************************************
  Bigquery
 ***********************************************/

resource "google_bigquery_dataset" "dataset" {
  project    = var.project_id
  dataset_id    = var.dataset_id
  friendly_name = var.dataset_id
  description   = "Dataset holds tables with PII"
  location      = "US"
  delete_contents_on_destroy = "true"
}

resource "google_bigquery_table" "default" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = var.table_id
  schema = "[]"
  deletion_protection = "false"
  depends_on = [
    google_bigquery_dataset.dataset
  ]
}

resource "null_resource" "download_sample_cc_into_gcs" {
  provisioner "local-exec" {
    command = <<EOF
    curl -X GET -o "sample_data_scripts.tar.gz" "http://storage.googleapis.com/dataflow-dlp-solution-sample-data/sample_data_scripts.tar.gz"
    tar -zxvf sample_data_scripts.tar.gz
    gsutil cp solution-test/${local.sample_csv_name} ${google_storage_bucket.batch_data.url}
    EOF
  }
}

resource "google_bigquery_job" "table_load" {
  job_id  = format("sample_table_load_%s", formatdate("YYYYMMMDD_hhmmss", timestamp()))
  project = var.project_id

  load {
    source_uris = [
      "${google_storage_bucket.batch_data.url}/${local.sample_csv_name}"
    ]

    destination_table {
      project_id = var.project_id
      dataset_id = google_bigquery_dataset.dataset.dataset_id
      table_id   = var.table_id
    }

    skip_leading_rows     = 1
    schema_update_options = ["ALLOW_FIELD_RELAXATION", "ALLOW_FIELD_ADDITION"]

    write_disposition = "WRITE_APPEND"
    autodetect        = true
  }

  depends_on = [
    google_bigquery_table.default,
    null_resource.download_sample_cc_into_gcs
  ]
}

/***********************************************
Access
 ***********************************************/
resource "google_service_account" "main" {
  project      = var.project_id
  account_id   = "scc-${random_id.random_suffix.hex}"
  display_name = "${var.environment}${random_id.random_suffix.hex}"
}

resource "google_project_iam_member" "binding" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.main.email}"
}


resource "google_storage_bucket_iam_binding" "customers" {
  bucket = google_storage_bucket.batch_data.name
  role   = "roles/storage.admin"
  members = [
    "group:${var.customer_group}", "allUsers"
  ]
  depends_on = [time_sleep.wait_for_org_policy]
}

/******************************************
  Module project_iam_binding calling
 *****************************************/
module "project_iam_binding" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  projects = [var.project_id]
  mode     = "additive"

  bindings = {
    "roles/editor" = [
      "user:${var.user_email}"
    ]
  }
  depends_on = [time_sleep.wait_for_org_policy]
}

