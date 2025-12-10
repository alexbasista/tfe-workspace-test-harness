provider "tfe" {
  hostname = "app.terraform.io"
}

module "workspacer_test_harness" {
  count   = 2
  source  = "alexbasista/workspacer/tfe"
  version = "0.13.0"

  organization   = var.organization
  project_name   = var.project_name
  workspace_name = "test-harness-${count.index}"
  workspace_desc = "Test harness workspace to simulate workload on TFC/E."
  auto_apply     = true
  queue_all_runs = true

  vcs_repo = var.vcs_repo == null ? null : {
    identifier                 = var.vcs_repo.identifier
    branch                     = var.vcs_repo.branch
    oauth_token_id             = var.vcs_repo.oauth_token_id
    github_app_installation_id = var.vcs_repo.github_app_installation_id
  }
}