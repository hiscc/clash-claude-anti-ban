# Adapter contract

An adapter is the using agent's client-specific implementation. The skill does not ship a universal mutating adapter.

Every client adapter must answer these questions with observed evidence:

1. Where is the active configuration stored, and what overwrites it?
2. How are application routes, DNS routes, IPv4/IPv6, UDP, and browser/system proxies handled?
3. Which object is the real outbound: node, selector, fallback, URL-test group, direct, or reject?
4. Can a protected group reach `DIRECT` directly or through another group?
5. What happens when the selected proxy is unavailable?
6. Does DNS follow routing rules, use a fixed interface, or run outside the routing engine?
7. Which traffic must remain direct to bootstrap the proxy connection?
8. How are changes backed up, validated, restored, and kept across subscription updates?

## Support levels

- **Detect**: identify process, config root, local proxy ports, TUN interfaces, and system proxy state.
- **Audit**: parse active configuration without exposing secrets and report concrete paths to direct networking.
- **Harden**: mutate only after field names and lifecycle are verified against the installed version or official documentation.
- **Verify**: test the effective runtime, not only source files.

## Required safety behavior

- Default to read-only for an unknown client.
- Back up before mutation.
- Preserve explicit direct-only rules; remove direct fallback only from protected/non-direct groups.
- Abort when the intended proxy group is ambiguous.
- Never embed subscriptions, credentials, or public IPs in fixtures.
- Include an idempotence test and a restore test before calling an adapter automatic.

## Required implementation record

Before changing anything, record:

- detected client, core version, operating system, active profile, and protected scope;
- exact files/settings to change and what can overwrite them;
- intended application outbound, DNS outbound, IPv6/UDP behavior, and failure behavior;
- backup location, restore command/procedure, and restart/reload requirement;
- unknowns that prevent safe implementation.

After changing it, record the resulting runtime evidence using `verification-protocol.md`. Source-file diffs are supporting evidence, never the final acceptance result.
