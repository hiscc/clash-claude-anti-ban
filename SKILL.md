---
name: clash-claude-anti-ban
description: Diagnose and fix proxy configurations where Claude uses an unexpected node, DIRECT path, mainland-China DNS, uncovered IPv6, or bypassing WebRTC/UDP/QUIC while a proxy is active, and make Claude connections fail outright when no proxy is running. Use when configuring Clash, ClashX Pro/XPro, Clash Verge Rev, Mihomo, VPN or similar clients so Claude HTTPS and DNS follow the user-approved proxy region in rule mode, with runtime and subscription-persistence verification.
---

# Claude Proxy Path Hardening

## Required outcome

Implement and prove this result on the user's actual device:

| Traffic | Required result |
|---|---|
| Claude HTTPS/TCP | Use the user-approved group and currently selected node |
| Claude DNS/DoH/DoT | Use an encrypted resolver through the same approved proxy path; never use mainland-China or local-ISP DNS |
| Claude IPv6 | Use the approved path or fail cleanly |
| Claude WebRTC/UDP/QUIC | Use the approved path or be rejected; never fall through to `DIRECT` |
| Claude with no proxy running | Proxy app closed, crashed or TUN down: the connection fails at the OS firewall and never leaves through a hardware port |
| Unrelated traffic | Preserve the user's intended rule-mode routing |

Both layers are required. The proxy-path invariants stop a running proxy from choosing an unexpected egress or DNS path; the [no-proxy kill switch](#no-proxy-kill-switch) stops Claude from leaving directly when no proxy is running. Neither replaces the other. Do not skip the kill switch because direct Claude access currently fails on the user's network: reachability changes, and the kill switch makes failure deterministic.

Do not stop at advice or example YAML when implementation is authorized. Inspect, back up, modify, reload and verify the effective runtime.

## Protected scope

Start with these suffixes and add domains only from observed Claude connections or current official documentation:

```text
claude.ai
claude.com
anthropic.com
```

Include subdomains. Treat `claudeusercontent.com` as conditional: add it when observed in the user's Claude client.

## Non-negotiable facts

- TUN/enhanced mode means traffic enters the proxy core; it does not mean every destination uses a proxy node. Rules still decide `DIRECT`, proxy or reject.
- The macOS `utunN` number is dynamic. Never hard-code the observed interface number.
- When a verified TUN/enhanced mode already intercepts the in-scope clients, a simultaneous OS HTTP/HTTPS/SOCKS proxy is normally unnecessary. Do not enable both without an observed requirement.
- A proxy-group label is not proof. Resolve the full chain to its concrete selected node.
- DNS provider names and DNS exit paths are different facts. Prove the resolver connection's actual outbound group and node.
- Anycast can make a resolver's displayed city differ from the proxy city. This is acceptable only when logs prove the DNS transport used the approved node and no forbidden mainland/local resolver appeared.
- Old Clash cores can skip a matched rule when its selected adapter does not support UDP, continue evaluating rules and ultimately use `DIRECT`. Never infer UDP safety from a TCP rule.
- Configuration text is not acceptance evidence. Only post-change runtime observations can pass a gate.

## Procedure

### 1. Inspect without mutation

Determine:

- operating system, proxy application and exact core version;
- active profile location, including iCloud or generated-profile storage;
- TUN/enhanced mode, OS system-proxy state, DNS interception and IPv6 state;
- rule mode and controller/log access;
- Claude group members, nested groups, concrete selected node, node region and UDP support;
- configured DNS, fallback DNS, browser DoH, WebRTC and QUIC policies;
- every in-scope Claude client: browser, desktop app, CLI, extension or embedded WebView;
- how subscription updates overwrite or merge local changes.

Redact subscription URLs, credentials, node addresses, tokens, cookies and full public IPs.

### 2. Establish a baseline

Generate fresh Claude and DNS traffic. Record the actual rule, group chain, concrete node, network type and resolver path. Test IPv4, IPv6, DNS/DoH, WebRTC/STUN and UDP/QUIC separately.

Separate these conclusions:

| Observation | Valid conclusion |
|---|---|
| System DNS points to a Fake-IP address | DNS interception is active; upstream safety is still unknown |
| Claude TCP log shows a Taiwan node | HTTPS path is correct for that request only |
| DNS test shows a mainland resolver | DNS path is inconsistent even if HTTPS is correct |
| Selected node reports `udp: false` | UDP must have an explicit reject/failure path |

### 3. Back up

Back up every profile, preference and browser policy that will change. Record exact restore locations. Do not expose secrets in logs or commits.

### 4. Implement invariants

Choose mechanisms supported by the detected client and version. The final configuration must satisfy all invariants:

1. Put protected-domain rules before broader direct, GeoIP and catch-all rules.
2. Route protected domains to one stable protected group.
3. If the user wants `openAI → 节点选择组`, make `openAI` contain only that group. Verify the current nested selection is the approved concrete node.
4. Do not add automatic `DIRECT`, latency-test or unrelated-region fallback to the protected chain. An explicit manual user selection is not an automatic fallback, but acceptance fails while it selects `DIRECT` or an unapproved node.
5. Replace mainland plaintext DNS and mainland DoH/DoT for protected resolution.
6. Make encrypted DNS transport use the same protected group and selected node. Merely changing `nameserver` to an overseas URL is insufficient when the core dials that URL directly.
7. Disable IPv6 when it cannot be proved safe; otherwise route and verify it.
8. For each protected TCP rule targeting a UDP-incapable group, add a later matching `REJECT` rule or an equivalent UDP-safe control. TCP must hit the proxy rule first; unsupported UDP must continue to reject, never direct.
9. Disable or constrain browser-specific DoH, non-proxied WebRTC UDP and QUIC when they can bypass the verified path.
10. Preserve the repair across subscription refreshes. Prefer supported merge/override facilities; otherwise install an idempotent post-update patcher and prove it runs in the profile's real storage location.
11. Install the [no-proxy kill switch](#no-proxy-kill-switch).

Do not claim that `tun: true`, Fake-IP, an overseas resolver address or a group named `openAI` satisfies these invariants without runtime evidence.

## XPro / ClashX Pro reference pattern

Use this pattern when actual inspection confirms XPro enhanced mode is the active interception mechanism:

| Setting | Target |
|---|---|
| Enhanced mode / TUN | On |
| Set as system proxy | Off after verifying TUN covers every in-scope client |
| Outbound mode | Rule |
| Protected chain | `Claude → openAI → 节点选择组 → approved node` |
| DNS | Local encrypted forwarder or supported core DNS feature whose transport is proven through the protected chain |
| Browser DoH | Off or pinned to the same verified path |
| WebRTC | Disable non-proxied UDP |
| QUIC | Disable when the selected node/core cannot proxy UDP safely |

Legacy Clash v1.10's built-in DoH dialer can connect directly rather than through a proxy group. If the required result cannot be obtained natively, use a local encrypted DNS forwarder configured to send DoH through the local Clash HTTP/SOCKS port, then route the DoH endpoint through the protected group. Prove the resulting chain in the core log.

If XPro stores profiles in iCloud and a background persistence agent lacks permission to read that path, do not report persistence as solved. Use a supported local profile/override location or another mechanism that survives unattended subscription updates.

## No-proxy kill switch

Required. Target behavior: Anthropic destinations are rejected on hardware network ports, so Claude can only leave through the proxy core. This covers a closed or crashed proxy app, a TUN that is down, the proxy's direct mode, and any proxy rule that sends Claude to `DIRECT`.

Installing adds root-level persistence. Tell the user what will be installed and where before writing it, and get consent.

### macOS (pf)

1. Read Anthropic's current inbound ranges from [the official IP page](https://platform.claude.com/docs/en/api/ip-addresses) (as of 2026-10: `160.79.104.0/21`, `2607:6bc0::/48`). Filter by IP, not domain, so every Claude subdomain is covered.
2. Enumerate hardware ports with `networksetup -listallhardwareports` at load time. Never list `utunN` interfaces and never allow-list a specific TUN number.
3. Load `block return out quick` rules for those ranges on the hardware ports into a sub-anchor of the existing `com.apple/*` anchor point (for example `com.apple/claude-killswitch`) and enable pf with `pfctl -E`. Do not edit or flush `/etc/pf.conf`.
4. Persist with a root LaunchDaemon that reloads the anchor at boot (`RunAtLoad`) and on network configuration changes (`WatchPaths` on `/Library/Preferences/SystemConfiguration/preferences.plist`), so newly added adapters are covered.
5. Record the anchor, daemon and file locations, plus the removal steps: boot out the daemon, flush the anchor, delete the files.

Why proxied traffic still works: with the proxy active, Claude traffic enters the TUN or a local proxy port, and the hardware port only carries connections to the proxy node. A proxy rule that sends Claude to `DIRECT` is rejected too; fix that rule instead of removing the kill switch.

Gate, with the proxy active:

| Check | PASS condition |
|---|---|
| Proxied Claude | `claude.ai` and `api.anthropic.com` return HTTP status codes |
| Direct Claude | `curl --interface <connected hardware port> https://160.79.104.10` fails to connect |
| Control | The same interface-bound request to a non-Anthropic address succeeds |
| Persistence | Rules are present after a reboot |

### Other operating systems

Implement the equivalent with the OS firewall: outbound block rules for the same ranges, bound to physical adapters rather than the TUN adapter, loaded at boot. If no equivalent can be implemented, mark the kill-switch gate `FAIL`, never `PASS`.

Residual risks: while the proxy is down, the OS still sends Claude DNS queries to the local resolver; Claude subdomains hosted outside the published ranges are not covered.

## Acceptance gates

Run every applicable gate and mark it `PASS`, `FAIL` or `NOT TESTED`.

| Gate | PASS condition |
|---|---|
| Interception | System proxy can be off and every declared Claude client still appears in the TUN/core log |
| Rule mode | Runtime controller reports rule mode after reload/restart |
| Protected group | Protected group resolves only to the intended nested selector and current approved node |
| Claude TCP | Fresh Claude request logs the protected group and approved concrete node |
| DNS transport | Fresh resolver connection logs the same protected group and node |
| Forbidden DNS | No mainland public DNS or local-ISP resolver appears in the test |
| Plain DNS bypass | Hard-coded or unexpected port 53 traffic is rejected or otherwise cannot expose protected queries |
| IPv6 | Approved exit or clean failure |
| WebRTC | No public local address; non-proxied UDP is disabled or rejected |
| UDP/QUIC | Approved proxy path or explicit rejection; no `DIRECT` continuation |
| OS proxy | Off when TUN-only operation is the chosen architecture |
| Dynamic interface | No configuration depends on a particular `utunN` number |
| Restart | Rule mode, group chain, DNS and browser protections remain effective |
| Subscription update | Refresh and reload do not remove any invariant |
| Unrelated routing | Representative domestic, LAN and foreign destinations retain the user's intended rule behavior |
| No-proxy kill switch | Every check in the [kill-switch gate](#no-proxy-kill-switch) passes, including persistence after reboot |

Use [Claude AI IP risk detection](https://ip.net.coffee/claude/) as one evidence source. Correlate its result with local controller logs; the webpage alone cannot prove the group chain or subscription persistence.

## Report

Lead with one conclusion:

- **Accepted for declared scope**: every mandatory gate passed;
- **Partially verified**: no observed failure, but at least one gate was not tested;
- **Rejected**: at least one gate failed.

Return a compact table with gate, status, redacted evidence and remaining risk. Never label an unrun test `PASS`.

This skill reduces network-path inconsistency risk. It cannot guarantee account safety against proxy-IP reputation, cookies, history, fingerprinting, time zone, language or platform policy.
