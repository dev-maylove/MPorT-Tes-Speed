# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest release on `main` / `master` | Yes |
| Older tagged releases | Best effort only |

Security fixes are applied to the current mainline release. Please upgrade to the latest build when a fix is published.

## Reporting a vulnerability

If you discover a security issue in **MPorT Go**, please report it privately. Do **not** open a public GitHub issue or discussion for vulnerabilities.

**Preferred contact**

- Email the maintainer using the address listed on the repository owner profile, or
- Use GitHub **Security → Advisories → Report a vulnerability** (private advisory) if available on this repository.

Please include:

1. A clear description of the issue and its impact  
2. Steps to reproduce (proof of concept if possible)  
3. Affected app version / commit / build number  
4. Suggested remediation if you have one  

We aim to acknowledge reports within **72 hours** and to provide a status update within **7 days**.

## Scope

In scope:

- Authentication or session handling flaws (if introduced in future releases)
- Insecure storage of secrets or tokens on device
- Intentional exposure of credentials in logs, builds, or the public repository
- Path traversal or unsafe file handling in app-writable storage
- Severe denial-of-service in the speed-test engine triggered by untrusted input

Out of scope:

- Issues that require a compromised or rooted/jailbroken device
- Vulnerabilities solely in third-party dependencies already disclosed upstream (please report upstream first)
- Missing security headers on third-party test servers outside our control
- Social engineering or physical access attacks
- Reports without a reasonable proof of concept

## Security practices (project)

- **Secrets** — Release keystores, API keys, and signing passwords are never committed. CI injects them at build time and removes them after the job.
- **Dependencies** — Flutter/Dart packages are resolved from the public pub.dev registry; lockfile changes should be reviewed in PRs.
- **Least privilege CI** — Workflows use minimal `permissions`. Signed release builds do not run on pull requests.
- **Transport** — Network tests use HTTPS where the server supports it; cleartext is only used when a test endpoint requires it and is constrained by the app network config.
- **Local data** — History and preferences use on-device storage (`SharedPreferences`). No account system ships in the current version; treat the device as the trust boundary.
- **Disclosure** — Internal server hostnames, credentials, and infrastructure details are omitted from public documentation.

## Safe Harbor

We will not pursue legal action against researchers who:

- Make a good-faith effort to avoid privacy violations, destruction of data, and interruption of service  
- Report findings promptly through the private channel above  
- Do not exploit the issue beyond what is necessary to demonstrate it  
- Do not publicly disclose the issue until we have confirmed a fix or mutually agreed on a disclosure date  

Thank you for helping keep MPorT Go and its users safe.
