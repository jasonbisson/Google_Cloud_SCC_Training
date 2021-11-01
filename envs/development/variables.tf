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

/******************************************
  Required variables
*******************************************/
variable "enable_apis" {
  description = "Whether to actually enable the APIs. If false, this module is a no-op."
  default     = "true"
}

variable "disable_services_on_destroy" {
  description = "Whether project services will be disabled when the resources are destroyed. https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy"
  default     = "false"
  type        = string
}

variable "disable_dependent_services" {
  description = "Whether services that are enabled and which depend on this service should also be disabled when this service is destroyed. https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services"
  default     = "false"
  type        = string
}

variable "activate_apis" {
  description = "The list of apis to activate within the project"
  default     = ["storage.googleapis.com","bigquery.googleapis.com","container.googleapis.com"]
  type        = list(string)
}

variable "constraints" {
  description = "The list of constraints to disable"
  default     = ["compute.trustedImageProjects","compute.vmExternalIpAccess","compute.restrictSharedVpcSubnetworks","compute.restrictSharedVpcHostProjects","compute.restrictVpcPeering","compute.vmCanIpForward"]
  type        = list(string)
}

variable "environment" {
  description = "Environment name of deployment"
  type        = string
}

variable "project_id" {
  description = "Project ID to deploy storage bucket"
  type        = string
}

variable "bucket_name_prefix" {
  description = "Prefix of GCS Bucket"
  type        = string
}

variable "customer_group" {
  description = "Google Group for customers"
  type        = string
}

variable "user_email" {
  type        = string
  description = "Email for group to receive roles (Ex. user@example.com)"
}

variable "default_region" {
  description = "Default region to create resources where applicable."
  type        = string
  default     = "us-central1"
}

variable "terraform_service_account" {
  description = "Service account email of the account to impersonate to run Terraform."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset."
  type        = string
}

variable "table_id" {
  description = "BigQuery table ID with PII data."
  type        = string
}

/******************************************
optional variables
*******************************************/

variable "storage_bucket_labels" {
  description = "Labels to apply to the storage bucket."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "The VPC network to host the cluster in"
  default     = "gke-network"
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster in"
  default     = "default"
}

variable "ip_range_pods_name" {
  description = "The secondary ip range to use for pods"
  default     = "ip-range-pods"
}

variable "ip_range_services_name" {
  description = "The secondary ip range to use for services"
  default     = "ip-range-scv"
}


