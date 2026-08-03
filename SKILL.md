---
name: clash-claude-anti-ban
description: Diagnose and fix proxy configurations that may expose a user's real network path to Claude. Implement Claude-scoped fail-closed behavior so Claude uses the intended proxy when available, fails when the proxy is unavailable, and unrelated websites remain usable. Verify IPv4, IPv6, DNS, DoH, WebRTC, UDP/QUIC, failover, restart, and subscription persistence before declaring success.
---

# Claude Proxy Leak Hardening

## Required outcome

Implement and verify this behavior on the user's actual device:

| Proxy state | Claude and Anthropic traffic | Unrelated traffic |
|---|---|---|
| Available | Use the user-approved proxy group and exit | Preserve the user's existing routing policy |
| Not started, exited, crashed, or no usable node | Fail; never connect directly | Continue normally |

This is **Claude scoped fail-closed**, not a device-wide kill switch. Do not block the whole device when only Claude is protected.

Do not stop after explaining a solution. When the user has authorized implementation, inspect the actual environment, back it up, make the changes, restart or reload as required, and verify effective traffic.

## Protected scope

Start with these suffixes and extend the list only from observed Claude connections or current official documentation:

```text
claude.ai
claude.com
anthropic.com
```

Include every subdomain. Do not route unrelated domains through the protected group merely because the group has an AI-themed name.

## Truths that constrain the implementation

- Rules inside a proxy core disappear when that core is not running. TUN, strict routing, or disabling the system proxy cannot by themselves make Claude fail after the proxy exits.
- A protected proxy group must not contain `DIRECT`, a direct-only group, or a direct fallback. An accidentally empty protected group must reject or fail.
- A guard that must survive proxy exit must be owned outside the proxy application's lifecycle.
- DNS resolver exposure is a network inconsistency and may reveal the user's IP to the resolver. It does not by itself prove that the Claude HTTPS endpoint received the real IP.
- A device-wide firewall is the wrong default for this task because unrelated websites must remain usable.
- Configuration text is not proof. Only post-change runtime evidence can pass acceptance.

## Execution procedure

### 1. Discover without mutation

Identify and record:

- operating system and version;
- every running or installed proxy/VPN client that can affect routing;
- active profile, core version, TUN/system-proxy state, local proxy ports and controller;
- protected proxy group and the concrete selected node;
- configuration overwrite lifecycle, including subscription updates;
- browser secure-DNS settings and every Claude client in scope.

Before implementation, declare the acceptance scope as a matrix of `client × protected function × domain set`. Do not omit a discovered Claude client or network function merely because it is difficult to test.

Use official documentation for the installed version before inventing or changing keys. Redact subscription URLs, node addresses, credentials, UUIDs, tokens, cookies and full public IPs.

### 2. Establish a baseline

Test Claude routing, IPv4, IPv6, DNS/DoH, WebRTC/STUN and UDP/QUIC before modification. Also sample unrelated destinations and record their PAC decision, proxy group, exit class and DNS path so unchanged behavior can be verified later. Separate observed facts from inference.

### 3. Back up and plan recovery

Back up every file or system setting that will change. Record an exact restore procedure. Do not perform a destructive network test over the only remote connection to the device.

### 4. Implement for the detected client

The implementation may differ by client, but it must satisfy all of these invariants:

1. Protected domains select the intended proxy group before broader rules.
2. No path from the protected group can reach `DIRECT`, including nested groups and empty fallbacks.
3. Protected DNS and encrypted DNS follow the intended proxy path or fail.
4. IPv6, WebRTC/STUN and UDP/QUIC follow the intended path or fail.
5. Subscription updates cannot erase the protection.
6. A guard independent of the proxy process prevents protected traffic from becoming direct after the proxy exits.
7. The independent guard does not block unrelated websites.

Choose the guard from observed client capabilities:

| In-scope client behavior | Required implementation |
|---|---|
| Honors the OS PAC | Install a persistent PAC outside the proxy application's lifecycle and disable proxy-unavailable fallback |
| Supports an application-specific proxy | Pin that application to the detected local proxy port without a direct fallback |
| Ignores PAC and has no fixed-proxy setting | Use a domain-aware OS content filter or application firewall verified for that client |
| Cannot be intercepted without device-wide blocking | Report the gate as `NOT TESTED` or `FAIL`; do not silently block the whole device |

For every platform-specific mechanism:

1. Read current official OS/client documentation before changing it.
2. Inspect the existing PAC, system proxy, app proxy and managed policies.
3. Preserve their behavior for every unprotected destination.
4. Ensure the guard is loaded at login or boot independently of the proxy client.
5. Prove the guard remains active after fully quitting and force-killing the proxy.
6. Record exact install, verification and restore commands for the detected platform.

If an existing remote PAC, MDM profile or managed policy cannot be composed without changing its lifecycle or decisions, do not replace it with a copied/static approximation. Stop that implementation path and report the guard as unresolved.

For proxy-aware browsers and desktop clients, a persistent platform PAC is one possible reference implementation. `originalRoute` represents the user's pre-existing PAC decision; if no PAC existed and direct access was the observed original behavior, it may return `DIRECT`:

```javascript
function protectedHost(host) {
  host = host.toLowerCase()
  return host === 'claude.ai' || shExpMatch(host, '*.claude.ai') ||
    host === 'claude.com' || shExpMatch(host, '*.claude.com') ||
    host === 'anthropic.com' || shExpMatch(host, '*.anthropic.com')
}

function originalRoute(url, host) {
  // Replace with the user's original PAC logic. Do not assume DIRECT.
  return 'DIRECT'
}

function FindProxyForURL(url, host) {
  if (protectedHost(host)) return 'PROXY 127.0.0.1:LOCAL_PROXY_PORT'
  return originalRoute(url, host)
}
```

The protected return contains no `DIRECT` fallback. The PAC/guard must remain installed when the proxy exits, while `LOCAL_PROXY_PORT` is replaced with the detected client port. Configure the platform so a missing protected proxy cannot silently fall back; verify this behavior rather than assuming it from PAC text.

PAC alone does not cover applications that ignore platform proxy settings. An application-specific proxy must pass the destination hostname to the local proxy for remote resolution. If the client can bypass with direct TCP, IPv6, UDP or QUIC, add a domain-aware filter for that client or mark the corresponding gate unresolved. IP-only firewall tables are not a generic domain guard because shared or changing CDN addresses can block unrelated websites.

For browser DNS prefetch, independent DoH, WebRTC/STUN and QUIC, inspect the actual browser policy and connection log. Disable the bypass only for the protected client/profile when safe, or route it through the protected proxy. Do not globally disable unrelated network features merely to make a test pass.

To build the protected destination set, capture a clean Claude login and usage session, correlate hostnames with client/core logs, and add only Claude/Anthropic-owned or necessary authentication/API endpoints supported by observed evidence or current official documentation. Re-run this discovery after meaningful client updates. Do not proxy an entire third-party CDN suffix without proving it is required.

### 5. Restart and verify runtime behavior

Run every applicable gate below. Mark each `PASS`, `FAIL`, or `NOT TESTED`. Never convert an unrun test into `PASS`.

| Gate | PASS condition |
|---|---|
| Declared scope | Every discovered `client × protected function × domain set` entry has an explicit gate |
| Protected route | A fresh request from each in-scope Claude client selects the intended group and node, confirmed by core log or process-level connection evidence |
| IPv4 | The same protected client request uses the expected proxy exit; no local ISP address |
| IPv6 | Same protected exit or clean failure |
| DNS and DoH/DoT | No forbidden local resolver path for protected queries |
| WebRTC/STUN | No public local address; protected UDP follows proxy or fails |
| UDP/QUIC | Follows the protected outbound or fails |
| Node failure | Claude fails and no direct connection appears |
| Core crash | Claude fails and unrelated websites remain usable |
| Client exit | Claude fails and unrelated websites remain usable |
| Client not started after reboot | Claude fails and unrelated websites remain usable |
| Client recovery | Claude resumes through the intended proxy |
| Unprotected route preservation | Sampled unrelated destinations retain their baseline PAC decision, proxy group, exit class and DNS path |
| Subscription update | Protection remains effective after update and reload |
| Restore | Backup restores and the client can load the restored state |

Test every Claude client declared in scope separately. A browser result does not prove a desktop client, CLI, extension, or embedded WebView is protected. A generic IP-check website cannot substitute for a protected Claude request correlated with the routing/core log.

### 6. Report the outcome

Lead with one conclusion:

- **Accepted for declared scope**: every mandatory gate passed;
- **Partially verified**: no observed failure, but at least one mandatory gate was not tested;
- **Rejected**: at least one mandatory gate failed.

Return a compact table:

| Gate | Status | Redacted evidence | Remaining risk |
|---|---|---|---|

Only **Accepted for declared scope** may be summarized as “Claude network leakage solved.” Keep implementation details brief unless they explain a failed gate or the user asks for them.

## Safety boundary

This procedure reduces network-path inconsistencies. It cannot guarantee that Claude will never restrict an account and does not remove risks from proxy IP reputation, cookies, account history, fingerprints, time zone, language, platform policy, or the proxy provider itself observing the user's source IP.
