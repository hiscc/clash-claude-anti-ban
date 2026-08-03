# ClashX Pro

ClashX Pro can intercept system DNS with fake-IP/TUN while its upstream resolvers still follow a different path. Seeing `198.18.0.2` as the system resolver proves interception, not that upstream DNS uses the selected proxy.

## Diagnostic sequence

1. Read `scutil --dns`; `198.18.0.0/16` indicates fake-IP interception.
2. Read runtime rules/logs for the tested domain; confirm its HTTPS connection uses the intended node.
3. Run an authoritative DNS leak test; compare resolver egress with the protected path.
4. Inspect connections to AliDNS, DNSPod, Cloudflare DNS, and Google DNS. A direct connection to a domestic resolver explains the split.

## Lifecycle limitation

Remote subscription updates replace the downloaded YAML. Hand-editing its DNS/rules is not a persistent solution. Legacy Clash Premium also lacks the modern Mihomo Merge/Script workflow used by Clash Verge Rev.

Use global mode only as a diagnostic: if DNS moves to the proxy region under global mode, rule-mode DNS endpoints were taking a direct path. For a persistent, auditable solution, migrate the subscription to a Mihomo client with independent Merge/Rules/Script overrides.
