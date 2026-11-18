#!/usr/bin/env bash
# Run after `terraform apply` in infra/bootstrap. Creates each GitHub Environment and
# sets the variables the infrastructure workflow signs in with. Every value is an ID,
# not a secret: OIDC means no Azure key or password is stored in GitHub.
#
#   cd infra/bootstrap && ./configure-github.sh
#
# Needs: gh (signed in with admin rights on the repository), terraform, node.
set -euo pipefail

cd "$(dirname "$0")"
repo="${GITHUB_REPOSITORY:-AdamTheAnalyst291/Setlist}"

out="$(terraform output -json)"
value() { node -e 'const o=JSON.parse(process.argv[1]); console.log(process.argv[2].split(".").reduce((v,k)=>v[k],o).value ?? "")' "$out" "$1"; }

subscription_id="$(value subscription_id)"
tenant_id="$(value tenant_id)"

echo "Repository variables for Terraform state"
gh variable set TF_STATE_RESOURCE_GROUP --repo "$repo" --body "$(value state_resource_group)"
gh variable set TF_STATE_STORAGE_ACCOUNT --repo "$repo" --body "$(value state_storage_account)"

for env in $(node -e 'console.log(Object.keys(JSON.parse(process.argv[1]).deploy_identities.value).join(" "))' "$out"); do
  identity() { node -e 'console.log(JSON.parse(process.argv[1]).deploy_identities.value[process.argv[2]][process.argv[3]])' "$out" "$env" "$1"; }

  echo "GitHub Environment $env"
  gh api --method PUT "repos/$repo/environments/$env" --silent
  gh variable set AZURE_CLIENT_ID --repo "$repo" --env "$env" --body "$(identity client_id)"
  gh variable set AZURE_PRINCIPAL_ID --repo "$repo" --env "$env" --body "$(identity principal_id)"
  gh variable set AZURE_TENANT_ID --repo "$repo" --env "$env" --body "$tenant_id"
  gh variable set AZURE_SUBSCRIPTION_ID --repo "$repo" --env "$env" --body "$subscription_id"
done

echo "Done."
