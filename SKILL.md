---
name: clash-claude-anti-ban
description: Diagnose and fix proxy configurations where Claude uses an unexpected node, DIRECT path, mainland-China DNS, uncovered IPv6, or bypassing WebRTC/UDP/QUIC while a proxy is active. Use when configuring Clash, ClashX Pro/XPro, Clash Verge Rev, Mihomo, VPN or similar clients so Claude HTTPS and DNS follow the user-approved proxy region in rule mode, with runtime and subscription-persistence verification.
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
| Unrelated traffic | Preserve the user's intended rule-mode routing |

Do not replace this objective with a proxy-process exit guard. In regions where Claude direct access already fails, the observed risk is normally an active proxy choosing an unexpected egress or DNS path. Implement an exit-time kill switch only when the user separately requests it and a baseline proves that direct Claude access succeeds.

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

## Optional: macOS exit-time kill switch

Only when the user explicitly asks that Claude fail while the proxy app is closed, crashed or its TUN is down, use [kill-switch/macos-pf](kill-switch/macos-pf/README.md). It does not replace any invariant above.

- It blocks Anthropic's published ranges (`160.79.104.0/21`, `2607:6bc0::/48`) on hardware ports only, enumerated at every load, so it never depends on a `utunN` number.
- Re-check the ranges against [the official IP page](https://platform.claude.com/docs/en/api/ip-addresses) before installing.
- Installing writes a root LaunchDaemon; get the user's consent for that persistence.
- Gate: with the proxy active, Claude still succeeds; a request bound to the physical interface (`curl --interface <hardware port> https://160.79.104.10`) fails, while a non-Anthropic control address succeeds.

## Acceptance gates

Run every applicable gate and mark it `PASS`, `FAIL` or `NOT TESTED`.

The exit-time kill switch below is optional and outside these gates; add its row only when it was installed.

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

Use [Claude AI IP risk detection](https://ip.net.coffee/claude/) as one evidence source. Correlate its result with local controller logs; the webpage alone cannot prove the group chain or subscription persistence.

## Report

Lead with one conclusion:

- **Accepted for declared scope**: every mandatory gate passed;
- **Partially verified**: no observed failure, but at least one gate was not tested;
- **Rejected**: at least one gate failed.

Return a compact table with gate, status, redacted evidence and remaining risk. Never label an unrun test `PASS`.

This skill reduces network-path inconsistency risk. It cannot guarantee account safety against proxy-IP reputation, cookies, history, fingerprinting, time zone, language or platform policy.
