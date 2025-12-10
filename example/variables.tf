variable "organization" {
  type        = string
  description = "Name of TFC/E organization."
}

variable "project_name" {
  type        = string
  description = "Name of TFC/E project to place workspace in."
  default     = "Default Project"
}

variable "vcs_repo" {
  type = object({
    identifier                 = string
    branch                     = optional(string, "main")
    oauth_token_id             = optional(string, null)
    github_app_installation_id = optional(string, null)
  })
  description = "VCS integration settings for workspace(s) if VCS-driven run workflow is desirable."
  sensitive   = true
  default     = null

  validation {
    condition     = var.vcs_repo == null || ((var.vcs_repo.oauth_token_id != null || var.vcs_repo.github_app_installation_id != null))
    error_message = "When vcs_repo is provided, either oauth_token_id or github_app_installation_id must be set (non-null)."
  }
}