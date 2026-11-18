# Infrastructure

Terraform for Setlist's Azure environments. Only Dev exists so far; UAT and Prod reuse the same module.

| Path | What it is | Who applies it |
|---|---|---|
| `bootstrap/` | One-time setup: Terraform state storage, each environment's resource group and GitHub deploy identity, and the subscription's budget alert | The subscription owner, by hand |
| `modules/environment/` | Everything one environment runs on: Static Web Apps (Free), a Functions app on Flex Consumption, a Key Vault, and the app database on the Azure SQL free tier | Used by `environments/*` |
| `environments/dev/` | Dev, using the module | GitHub Actions |

## What each environment gets

All in the resource group `rg-setlist-<env>`, in `eastus2`:

- **Web app:** Static Web Apps on the Free plan. The Free plan can't link a separate Functions app, so the web app calls the API's own hostname, and the API allows it with CORS.
- **API:** a Linux Functions app on Flex Consumption (Node 24), with a system-assigned managed identity. It reaches its storage account with that identity. No always-ready instances, and at most 40 instances.
- **Key Vault**, using Azure RBAC. The API's identity can read secrets. Terraform never holds secret values.
- **App database:** an Azure SQL free-tier database (`useFreeLimit`, AutoPause when the monthly allowance runs out). Its server accepts Microsoft Entra sign-in only, so no SQL password exists. The Entra admin is the environment's deploy identity, so the pipeline can run migrations. The firewall allows Azure services only.

The free-limit behaviour can't be changed after a database is created. The free offer allows up to 10 databases per subscription, and they all live in one region.

## Bootstrap (one time)

Run this from a machine signed in to the Azure CLI as an Owner of the Setlist subscription.

1. Check the account first. It must be the Setlist subscription and nothing else:

   ```bash
   az login --tenant <tenant-id>
   az account show
   ```

2. Fill in the variables. `terraform.tfvars` is git-ignored because it holds your email address.

   ```bash
   cd infra/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Review the plan, then apply it. It creates:
   - registrations for the resource providers Setlist uses
   - `rg-setlist-tfstate` with a storage account (Standard LRS, Entra ID access only, versioning and 7-day soft delete) and one `tfstate-<env>` container per environment
   - per environment: `rg-setlist-<env>`, and an app registration `setlist-github-<env>` whose only credential is a federated credential for `repo:AdamTheAnalyst291/Setlist:environment:<env>`
   - role assignments for that identity: Contributor on its resource group; Role Based Access Control Administrator on its resource group, limited to granting Storage Blob Data Owner and Key Vault Secrets User; Storage Blob Data Contributor on its own state container
   - the `setlist-monthly` budget on the subscription, $5 a month, emailing at 50% and 100% of actual spend and 100% of forecast

   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   The bootstrap's state stays in `infra/bootstrap/terraform.tfstate` on your machine (git-ignored). Keep it; if it's lost, the resources can be brought back under Terraform with `terraform import`.

4. Create the GitHub Environments and their variables (IDs only; nothing secret is stored in GitHub):

   ```bash
   ./configure-github.sh
   ```

   This sets the repository variables `TF_STATE_RESOURCE_GROUP` and `TF_STATE_STORAGE_ACCOUNT`, and on each environment `AZURE_CLIENT_ID`, `AZURE_PRINCIPAL_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`.

To add UAT and Prod later, set `environments = ["dev", "uat", "prod"]` in `terraform.tfvars`, apply again, and rerun the script.

## Pipeline

The `Infrastructure` workflow runs when a change touches `infra/` or the workflow itself:

- **Every pull request:** `terraform fmt`, `validate` on every root, and the module's tests (`terraform test`, with mocked providers).
- **Pull requests:** a Dev plan, posted as a comment that is updated on each push.
- **Merge to `main`:** plan and apply Dev.

Until the bootstrap has run and the `dev` Environment has its variables, the plan and apply jobs warn and skip instead of failing.

Both Azure jobs run in the `dev` GitHub Environment and sign in with OIDC, so no Azure key exists anywhere.

## Run it locally

```bash
terraform -chdir=infra/modules/environment init
terraform -chdir=infra/modules/environment test
```
