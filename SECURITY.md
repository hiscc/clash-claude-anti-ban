# Security policy

## Secret handling

This repository must never contain subscription URLs, proxy credentials, UUIDs, access tokens, cookies, generated Clash profiles, or user backups.

The installer reads the local Clash Verge Rev configuration only to discover profile structure and policy-group names. It never uploads configuration data. Backups stay under the local application-support directory with user-only permissions.

If a secret is committed, revoke it first, then rewrite the Git history. Deleting the visible line in a later commit is not sufficient.

## Reporting

Open a private GitHub security advisory for vulnerabilities that could expose credentials, weaken fail-closed behavior, or redirect DNS outside the selected proxy group.
