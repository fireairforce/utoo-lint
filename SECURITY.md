# Security Policy

## Supported Versions

Security fixes are applied to `main` first. The latest `0.x` release is the
supported release line; older releases should not be assumed to receive
security fixes.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately before public disclosure.

- Prefer a [private GitHub security advisory](https://github.com/fireairforce/utoo-lint/security/advisories/new).
- If private reporting is unavailable, contact a maintainer through a
  non-public channel instead of opening a public issue with exploit details.

Please include:

- the affected package, version, or commit
- the affected operating system and architecture, when relevant
- reproduction steps or a minimal proof of concept
- the expected impact and any known mitigations

The maintainers will coordinate validation, remediation, and disclosure with
the reporter.

## Security-Relevant Controls

The project treats the following as security-relevant controls:

- JavaScript, TypeScript, and configuration files are treated as untrusted input
- the Yuku parser dependency is pinned as a Git submodule
- autofix file writes require explicit opt-in and provide a dry-run mode
- release artifacts include checksums, and npm releases use provenance
