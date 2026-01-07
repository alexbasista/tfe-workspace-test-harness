provider "tfe" {
  hostname = var.tfe_hostname
}

module "workspacer_test_harness" {
  count   = 100
  source  = "alexbasista/workspacer/tfe"
  version = "0.15.0"

  organization   = var.organization
  project_id     = var.project_id
  workspace_name = "test-harness-${count.index}"
  workspace_desc = "Test harness workspace to simulate workload on TFC/E."
  auto_apply     = true
  queue_all_runs = true
  force_delete   = true
}