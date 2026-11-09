# infra

Terraform for [vedad-dizdarevic.dev](https://vedad-dizdarevic.dev): AWS and Cloudflare infrastructure for a static portfolio site. The site, Worker and Lambda code live in the sibling `app` repo.

> **Status:** `bootstrap/` and `main/` are applied (2026-11-02), and `terraform plan` in CI reports no changes. The apply workflow, Trivy/Checkov and the plan PR comment are in place. See the app repo's `documentation/implementation-plan.md` for the task list.

## Architecture

Browser → Cloudflare (DNS, CDN, TLS, Worker) → private S3 bucket in `eu-central-1` via SigV4. `/api/contact` → Worker → Lambda function URL (`AWS_IAM` auth) → SES.

## Layout

```
infra/
├── bootstrap/          # state bucket + GitHub OIDC provider and CI roles (applied once, locally)
├── main/               # everything else: S3 site bucket, IAM, Lambda, SES, Cloudflare zone/DNS/rules
└── .github/workflows/  # fmt, validate, Trivy/Checkov, gitleaks, plan, apply
```

## What lives where

| Managed here (Terraform) | Managed elsewhere |
|---|---|
| AWS resources: S3, IAM, Lambda, SES | Worker script and route: deployed with Wrangler from the `app` repo |
| Cloudflare zone, DNS records, rules, Turnstile widget | Site content: uploaded by the `app` repo's CI |

Never manage the same resource with both Terraform and Wrangler.

## State

S3 backend in `eu-central-1` with native locking (`use_lockfile = true`), so there is no DynamoDB table. The state bucket is created by `bootstrap/`, which was applied once by hand with local state and then migrated into the bucket (`bootstrap/terraform.tfstate`; `main/` uses `main/terraform.tfstate`).

## Prerequisites

- Terraform (version pinned in `.terraform-version`)
- AWS credentials for `eu-central-1` (for local runs, `aws login`)
- A scoped Cloudflare API token, passed as `CLOUDFLARE_API_TOKEN`
- `pre-commit` (formatting, trailing whitespace, gitleaks)

## Usage

Bootstrap (done; the commands are kept for a rebuild). Besides names and the GitHub org, `terraform.tfvars` needs the numeric IDs of the owner and both repos, because GitHub issues immutable OIDC subjects (`repo:<owner>@<ownerId>/<repo>@<repoId>`) and the trust policies pin them:

```sh
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # names, org, and IDs (see gh api commands in variables.tf)
terraform init -backend-config=backend.hcl     # first run with local state, then -migrate-state
terraform apply
```

Then in `main/`, copy `backend.hcl.example` to `backend.hcl` (bucket = bootstrap's `state_bucket` output) and
`terraform init -backend-config=backend.hcl`. Variables without defaults (`site_bucket_name`, `cloudflare_account_id`,
`github_org`, `app_repo`, `github_owner_id`, `app_repo_id`, `alert_email`, `dmarc_rua_email`) go in a git-ignored `terraform.tfvars` locally or in
`TF_VAR_*` CI variables. CI gets them from Actions variables (`AWS_ACCOUNT_ID`, `CLOUDFLARE_ACCOUNT_ID`, `ALERT_EMAIL`, `DMARC_RUA_EMAIL`, `GH_OWNER_ID`, `APP_REPO_ID`, `PURELYMAIL_OWNERSHIP_PROOF`, `TF_STATE_BUCKET`, role ARNs) and the `CLOUDFLARE_API_TOKEN` secret; a variable missing in CI shows up as a spurious diff (a missing `purelymail_ownership_proof` planned to delete the ownership TXT record).

Main stack (normally run by CI, not by hand):

```sh
cd main
terraform init
terraform fmt -check
terraform validate
terraform plan
```

## CI/CD

- **Pull request:** `terraform fmt -check`, `validate`, gitleaks, Trivy (config scan, HIGH and CRITICAL), Checkov, and `terraform plan` through the `gh-infra-plan` role. The plan is posted as a sticky PR comment and in the job summary.
- **Scanner exceptions** live next to the code as `#checkov:skip=<id>:<reason>` and `#trivy:ignore:<id>` with a reason above it. A new finding fails the build; add an exception only with a real reason, never a global skip.
- **Merge to `main`:** `apply.yml` runs `terraform apply` in the protected `production` environment through `gh-infra-apply` when `main/**` changes. One apply at a time, never cancelled mid-run. It refuses a plan that deletes or replaces anything unless a person re-runs it manually with `allow_destroy=true`. `bootstrap/` is still applied locally.
- **Auth:** GitHub Actions assumes AWS roles through OIDC, each trusted for one repo and ref. No long-lived AWS keys in CI.

Quality gates fail the build; don't weaken a threshold to get green.

## Secrets and outputs

- No secrets in the repo, in `*.tfvars`, or in Terraform outputs.
- The Worker IAM user's access key is created outside Terraform state outputs and stored only as a Worker secret (`wrangler secret put`).
- Non-secret values the app needs (bucket name, deploy role ARN, zone ID) are copied into the `app` repo's Actions variables.
- `.terraform.lock.hcl` is committed; local state, plans and `.tfvars` files are git-ignored.

## Workflow

Small PRs, one task each. `main` is protected and always applyable.

## Gotchas

- **Cloudflare TXT content** is returned wrapped in quotes, so TXT `content` in `cloudflare_dns_record` is written with escaped quotes. Otherwise every plan shows a permanent diff.
- **Lambda reserved concurrency** is `-1` (not reserved): AWS rejects any reservation on this account because it must keep 10 unreserved.
- **Cloudflare Web Analytics** is not managed here: the API returned 403 for the Terraform token. Revisit in Phase 10.
- **Shared AWS account:** account `769814228024` also hosts sorted.onl. Everything here is prefixed `vdd-` (bootstrap roles are `gh-*`), and the apply role is scoped to that prefix.
- **Budget scope:** `vdd-monthly` filters on the `Project = vedad-dizdarevic.dev` tag (set by the provider's `default_tags`), so sorted.onl's costs don't trigger it. The `Project` cost allocation tag is activated by hand in the Billing console (the apply role has no `ce:` permissions); if it is ever deactivated, the budget silently reads $0. Costs are only tagged from activation onwards.
- **Cloudflare zone settings** cannot be destroyed through Terraform; `terraform destroy` leaves them in place.
