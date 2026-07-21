# Security Policy

## Supported Code

This repository does not publish versioned releases. Security fixes are applied only
to the current code on the default branch.

| Code | Supported |
| --- | --- |
| Current `master` branch | Yes |
| Older commits or copies | No |
| Scripts under `Legacy/` | No |

Users should pull the latest version before reporting a vulnerability or applying a
security fix. The `Legacy/` directory contains historical examples retained for
reference and should not be used in production.

## Reporting a Vulnerability

Please do not disclose suspected security vulnerabilities in a public GitHub issue,
discussion, or pull request.

Use GitHub's private vulnerability reporting feature:

1. Open the repository's **Security and quality** tab.
2. Select **Report a vulnerability**.
3. Submit the report privately.

Please include, when applicable:

- The affected script and line or function
- A description of the vulnerability and its potential impact
- The conditions required to reproduce it
- Reproduction steps or a minimal proof of concept
- The AWS service and relevant configuration
- Any suggested mitigation or fix

Do not include AWS access keys, session tokens, passwords, private keys, unredacted
account information, or sensitive production data. Replace sensitive values with
clearly marked placeholders.

If private vulnerability reporting is unavailable, open a public issue asking the
maintainer for a private security contact, but do not include vulnerability details.

## What Qualifies as a Security Vulnerability

Examples include:

- Command or code injection through untrusted input
- Exposure of AWS credentials or sensitive cloud information
- Operations affecting an AWS account or region other than the one selected
- Bypassing an execution preview or confirmation safeguard
- Destructive behavior that is not clearly documented
- Use of broader IAM permissions than the script claims to require

General bugs, feature requests, documentation problems, and expected behavior should
be reported through the public issue tracker.

## Response Process

The maintainer aims to:

- Acknowledge a report within 7 days
- Provide an initial assessment within 14 days
- Request additional information when needed
- Coordinate any fix and public disclosure with the reporter

These response times are targets rather than guaranteed service levels. Please allow
a reasonable remediation period before publicly disclosing an accepted vulnerability.

## AWS Shared Responsibility

These scripts rely on AWS, the AWS CLI, local credentials, IAM policies, and the
user's environment. Vulnerabilities in AWS services or the AWS CLI should be reported
to their respective maintainers. Configuration mistakes or overly broad IAM policies
outside this repository are generally outside this project's scope.
