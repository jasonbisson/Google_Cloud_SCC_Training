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

resource "random_id" "suffix" {
  byte_length = 2
}

/***********************************************
  GCS Bucket 
 ***********************************************/

resource "google_storage_bucket" "batch_data" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.bucket_name_prefix}-${random_id.suffix.hex}"
  location                    = var.default_region
  labels                      = var.storage_bucket_labels
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

/***********************************************
  Bigquery
 ***********************************************/

resource "google_bigquery_dataset" "dataset" {
  dataset_id    = var.dataset_id
  friendly_name = var.dataset_id
  description   = "Dataset holds tables with PII"
  location      = "US"
}

resource "google_bigquery_table" "default" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.default.dataset_id
  table_id   = var.table_id
  schema = []
}

resource "null_resource" "download_sample_cc_into_gcs" {
  provisioner "local-exec" {
    command = <<EOF
    curl -X GET -o "sample_data_scripts.tar.gz" "http://storage.googleapis.com/dataflow-dlp-solution-sample-data/sample_data_scripts.tar.gz"
    tar -zxvf sample_data_scripts.tar.gz
    rm sample_data_scripts.tar.gz
    tmpfile=$(mktemp)
    gsutil cp solution-test/${local.sample_csv_name}  google_storage_bucket.batch_data.bucket.url
    EOF
  }
}

resource "google_bigquery_job" "table_load" {
  job_id  = format("sample_table_load_%s", formatdate("YYYYMMMDD_hhmmss", timestamp()))
  project = var.project_trusted_data

  load {
    source_uris = [
      "${module.tmp_data.bucket.url}/${local.sample_csv_name}",
    ]

    destination_table {
      project_id = var.project_trusted_data
      dataset_id = module.bigquery.bigquery_dataset.dataset_id
      table_id   = "${local.pii_table_id}"
    }

    skip_leading_rows     = 1
    schema_update_options = ["ALLOW_FIELD_RELAXATION", "ALLOW_FIELD_ADDITION"]

    write_disposition = "WRITE_APPEND"
    autodetect        = true
  }

  depends_on = [
    google_bigquery_table.default,
    null_resource.download_sample_cc_into_gcs,
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
}

