# Secure Command Center Training

## Purpose

This repository aims to learn Security Command Center by detecting an insecure infrastructure findings in a development environment.

## Prerequisites

To run the commands described in this document, you need to have the following
installed:

- The [Google Cloud SDK](https://cloud.google.com/sdk/install) version 319.0.0 or later
- [Terraform](https://www.terraform.io/downloads.html) version 0.13.6.
- An existing project and GCS Bucket to store Terraform state

**Note:** Make sure that you use the same version of Terraform throughout this
series. Otherwise, you might experience Terraform state snapshot lock errors.

## Update variables

1. Change to deployment directory
   ```
   cd envs/development
   ```
1. Update `backend.tf` with an existing GCS bucket to store Terraform state.
   ```
   bucket = "UPDATE_ME"
   ```
1. Rename `terraform.example.tfvars` to `terraform.tfvars` and update the file with values from your environment:
   ```
   mv terraform.example.tfvars terraform.tfvars
   ```
1. Update required  variables
   
## Deploy Insecure Infrastructure

### Deploy from a desktop

1. Run `terraform init`
1. Run `terraform plan` and review the output.
1. Run `terraform apply`

### Optional Deploy a Cloud Build environment

1. Deploy Bootstrap environment from [Cloud Foundation Toolkit](https://github.com/terraform-google-modules/terraform-example-foundation/tree/master/0-bootstrap)

1. Add cloud_source_repos to terraform.tfvars file to build gcp-scc repo in 0-bootstrap

   ```
   cloud_source_repos = ["gcp-org", "gcp-environments", "gcp-networks", "gcp-projects", "gcp-scc-training"]
   ```
1. Run `terraform apply`

#### Deploy from Cloud Build pipeline

1. Clone the empty gcp-scc-training repo.
   ```
   gcloud source repos clone gcp-scc-training --project=YOUR_CLOUD_BUILD_PROJECT_ID_FROM_0-bootstrap
   ```
1. Navigate into the repo and change to a non-production branch.
   ```
   cd gcp-scc-training
   git checkout -b plan
   ```
1. Copy the development environment directory and cloud build configuration files
   ```
   cp -r ../gcp_scc_training/envs  .
   cp ../gcp_scc_training/build/*  . 
   ```
1. Ensure wrapper script can be executed.
   ```
   chmod 755 ./tf-wrapper.sh
   ```
1. Commit changes.
   ```
   git add .
   git commit -m 'Your message'
   ```
1. Push your plan branch to trigger a plan. For this command, the branch `plan` is not a special one. Any branch which name is different from `development`, `non-production` or `production` will trigger a Terraform plan.
   ```
   git push --set-upstream origin plan
   ```
1. Review the plan output in your Cloud Build project. https://console.cloud.google.com/cloud-build/builds?project=YOUR_CLOUD_BUILD_PROJECT_ID
1. Merge changes to production branch.
   ```
   git checkout -b development
   git push origin development
   ```
1. Review the apply output in your Cloud Build project. https://console.cloud.google.com/cloud-build/builds?project=YOUR_CLOUD_BUILD_PROJECT_ID

1. Destroy the infrastructure with gcloud build command
   ```
   gcloud builds submit . --config=cloudbuild-tf-destroy.yaml --project your_build_project_id --substitutions=BRANCH_NAME="$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')",_ARTIFACT_BUCKET_NAME='Your Artifact GCS Bucket',_STATE_BUCKET_NAME='Your Terraform GCS bucket',_DEFAULT_REGION='us-central1',_GAR_REPOSITORY='prj-tf-runners'
   ```

