# infra

Terraform for [vedad-dizdarevic.dev](https://vedad-dizdarevic.dev): AWS and Cloudflare infrastructure for a static portfolio site. The site, Worker and Lambda code live in the sibling `app` repo.

> **Status:** planning done, no Terraform written yet. See the app repo's `documentation/implementation-plan.md` (Phase 1 onwards) for the task list.

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

S3 backend in `eu-central-1` with native locking (`use_lockfile = true`), so there is no DynamoDB table. The state bucket is created by `bootstrap/`, which uses local state and is applied once by hand.

## Prerequisites

- Terraform (version pinned in `.terraform-version`)
- AWS credentials for `eu-central-1` (for local runs, `aws login`)
- A scoped Cloudflare API token, passed as `CLOUDFLARE_API_TOKEN`
- `pre-commit` (formatting, trailing whitespace, gitleaks)

## Usage

Bootstrap (once, locally):

```sh
cd bootstrap
terraform init
terraform apply
```

Main stack (normally run by CI, not by hand):

```sh
cd main
terraform init
terraform fmt -check
terraform validate
terraform plan
```

## CI/CD

- **Pull request:** `terraform fmt -check`, `validate`, Trivy/Checkov IaC scan, gitleaks, then `terraform plan` posted as a PR comment.
- **Merge to `main`:** `terraform apply` (protected `production` environment).
- **Auth:** GitHub Actions assumes AWS roles through OIDC, each trusted for one repo and ref. No long-lived AWS keys in CI.

Quality gates fail the build; don't weaken a threshold to get green.

## Secrets and outputs

- No secrets in the repo, in `*.tfvars`, or in Terraform outputs.
- The Worker IAM user's access key is created outside Terraform state outputs and stored only as a Worker secret (`wrangler secret put`).
- Non-secret values the app needs (bucket name, deploy role ARN, zone ID) are copied into the `app` repo's Actions variables.
- `.terraform.lock.hcl` is committed; local state, plans and `.tfvars` files are git-ignored.

## Workflow

Small PRs, one task each. `main` is protected and always applyable.
