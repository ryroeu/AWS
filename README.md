# AWS CLI toolbox

A small, safety-conscious collection of Bash scripts for common AWS operations. The
toolbox is organized by service area, uses the AWS CLI's normal profile and region
resolution, and keeps mutating commands in preview mode until `--execute` is given.

## Requirements

- Bash 3.2 or newer
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [`jq`](https://jqlang.org/download/)
- AWS credentials with only the permissions needed for the script being run

Configure credentials using AWS IAM Identity Center, `aws configure`, or your usual
credential provider. Select an account and region with the standard AWS variables:

```bash
export AWS_PROFILE=my-sandbox
export AWS_REGION=eu-west-1
./account/whoami.sh
```

`AWS_DEFAULT_REGION` and the configured profile region are also supported. Scripts
that operate on regional services fail with a clear message when no region is set.
Every AWS CLI call disables the pager, so these scripts work in terminals and CI.

## What's included

| Area | Script | Purpose |
| --- | --- | --- |
| Account / IAM | `account/whoami.sh` | Confirm the active identity, account alias, and CLI context |
| Account / IAM | `iam-security/audit-access-keys.sh` | Report key age and last use, highlighting stale active keys |
| Account / IAM | `iam-security/list-admin-attachments.sh` | List direct attachments of the AWS managed AdministratorAccess policy |
| EC2 | `ec2/inventory.sh` | Inventory instances and their key networking details |
| EC2 | `ec2/find-unattached-volumes.sh` | Find available EBS volumes that may still incur charges |
| EC2 | `ec2/stop-by-tag.sh` | Preview and stop running instances selected by one tag |
| S3 | `s3/inventory.sh` | List buckets, regions, versioning, and public-block posture |
| S3 | `s3/audit-public-access.sh` | Review bucket policies, ACL grants, and block settings |
| S3 | `s3/sync-directory.sh` | Preview and upload a local directory using `aws s3 sync` |
| RDS | `rds/inventory.sh` | Inventory database instances |
| RDS | `rds/find-old-manual-snapshots.sh` | Find manual snapshots older than a threshold |
| RDS | `rds/create-snapshot.sh` | Preview and create a manual DB snapshot |
| Lambda | `lambda/inventory.sh` | Inventory functions, runtimes, sizes, and update state |
| Lambda | `lambda/tail-logs.sh` | Tail the standard CloudWatch log group for a function |
| Lambda | `lambda/invoke.sh` | Preview and invoke a function with an explicit payload |
| CloudWatch | `cloudwatch/log-groups-without-retention.sh` | Find log groups that retain data indefinitely |
| CloudWatch | `cloudwatch/set-log-retention.sh` | Preview and set retention on one log group |
| CloudWatch | `cloudwatch/tail-log-group.sh` | Tail any CloudWatch Logs group |
| Networking | `networking/inventory-vpcs.sh` | Inventory VPCs and their primary CIDR blocks |
| Networking | `networking/find-unattached-eips.sh` | Find allocated but unassociated Elastic IPs |
| Networking | `networking/inventory-load-balancers.sh` | Inventory Application, Network, and Gateway load balancers |
| Cost | `cost/month-to-date.sh` | Break down month-to-date unblended cost by service |
| Cost | `cost/daily-costs.sh` | Show daily unblended cost totals for a recent window |

All scripts support `--help`. Inventory scripts return either an AWS CLI table or
tab-separated output suitable for a spreadsheet, depending on the script. Cost and
security reports use TSV because it is both readable and easy to pipe.

## Safe usage

Read-only example:

```bash
AWS_PROFILE=production AWS_REGION=eu-central-1 ./ec2/inventory.sh
```

Mutating scripts first show exactly what they selected:

```bash
./ec2/stop-by-tag.sh --tag Environment=dev
./ec2/stop-by-tag.sh --tag Environment=dev --execute
```

Even with `--execute`, the script asks for confirmation. Add `--yes` only for
reviewed automation. The S3 sync wrapper also uses the AWS CLI's documented
[`--dryrun`](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) behavior
for its preview.

Some audits are intentionally conservative:

- `list-admin-attachments.sh` reports direct attachments of the managed policy; it
  does not prove that other policies are non-administrative.
- `audit-public-access.sh` reports configuration signals. AWS Organizations SCPs,
  access points, VPC endpoint policies, and other controls can affect effective access.
- “Unattached” resources should be reviewed for disaster recovery or future-use
  intent before removal. This repository does not delete them.
- The Resource Groups Tagging API is not used as a complete inventory because AWS
  documents that its `get-resources` operation does not return never-tagged resources.

## Development

Run the local checks after changing a script:

```bash
make check
```

The check validates Bash syntax, executable bits, and every script's help path. If
ShellCheck is installed, it runs that too.

The original 2018-era examples are preserved in [`legacy/`](legacy/README.md). They
are not part of the supported toolbox and should not be run on current systems
without review.

