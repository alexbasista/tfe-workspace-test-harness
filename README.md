# tfe-workspace-test-harness

Simulate workload within Terraform Cloud or Terraform Enterprise workspace(s).

## Usage

1. **Clone this repository down locally**

2. **Create a TFE Project dedicated to this scale test**
   
   If using a custom agent pool (recommended), set the Project-level **execution mode** to `Agent (custom)` and select applicable agent pool.

3. **Create your desired number of Workspaces**
   
   Navigate to the `deploy-workspaces` directory.

   Create a TFVARS file and provide values for the inputs:

    - `var.tfe_hostname`
    - `var.organization`
    - `var.project_id`
  
   Set the value of `count` to the number of Workspaces you desire for the scale test.

   Run `terraform apply`.

4. **Trigger runs on all of the test Workspaces**

   Navigate back to the root of the repository and prepare to execute the `blast_api_driven_runs.sh` script.
   
   Set a `TFE_TOKEN` environment variable in your shell.
   
   Run the script.

   Usage:

   ```sh
   blast_api_driven_runs.sh [options] <path_to_content_directory> [workspace_name_prefix_filter]

   Required (via env or flags):
   TFE_TOKEN       or --token/-t
   TFE_HOSTNAME    or --hostname/-H   (e.g. tfe.example.com or https://tfe.example.com)
   TFE_ORG         or --org/-o
   ```

   Example:

   ```sh
   ./blast_api_driven_runs.sh -H tfe.example.com -o my-tfe-org ./ test-harness-
   ```

   The **<path_to_content_directory>** (`./` in the example) is the path to the Terraform configuration to apply against the Workspaces, which in this case is the code at the root of this repository.