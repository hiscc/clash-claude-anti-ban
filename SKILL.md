---
name: clash-claude-anti-ban
description: Diagnose and fix proxy and host-network configurations where Claude uses an unexpected node, unsupported region, DIRECT path, conflicting or mainland-China DNS, uncovered IPv6, bypassing WebRTC/UDP/QUIC, or rogue client/OS proxies while a proxy is active, and make Claude connections fail outright at the OS firewall when no proxy is running. Use when configuring Mihomo, Clash Verge Rev, ClashX Pro/XPro, Clash, Sing-box or similar clients so Claude HTTPS, DNS and host-level egress stay strictly aligned and deterministic, with runtime, failover and subscription-persistence verification.
---

# Claude Proxy & Host-Network Hardening

## Required outcome

Implement and prove both defense layers on the user's actual device:

| Layer / Traffic | Required result |
|---|---|
| Claude HTTPS/TCP | Use a dedicated Claude proxy group and concrete node in an Anthropic-supported region (never mainland China, HK, MO, RU, etc.), isolated from routine daily node switching |
| Exit IP stability | Repeated probes resolve to a stable exit IP/ASN without silent multi-exit rotation |
| Claude DNS/DoH/DoT | Encrypted resolver pinned via per-domain policy to the **same** Claude proxy group/node; never mainland-China, local-ISP, or a mismatched-region DNS path |
| Claude IPv6 | Disabled or routed through the same approved path and verified; never falls back to local IPv6 |
| Claude WebRTC/UDP/QUIC | Routed through the approved path or explicitly rejected; never falls through to `DIRECT` |
| Client & OS bypasses | No conflicting `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY`, browser proxy extensions, iCloud Private Relay, or zombie legacy proxy/DNS daemons splitting traffic |
| Host-network kill switch | Proxy app closed, crashed, TUN down, or rule routed `DIRECT`: all published Anthropic IPv4 & IPv6 ranges fail immediately at the OS firewall on every non-proxy path |
| Cutover & persistence | Stale connections and DNS caches flushed on cutover; invariants survive subscription updates, GUI overrides, proxy restarts, network changes and OS reboots |
| Unrelated traffic | Preserve the user's intended rule-mode routing (including other AI/regional services on their own groups) |

Both layers are mandatory. The proxy-path invariants stop a running proxy from choosing an unexpected egress or DNS path; the [host-network kill switch](#host-network-kill-switch) makes direct egress impossible when no proxy is running or a rule misroutes to `DIRECT`. Neither replaces the other. Do not skip the kill switch because direct Claude access currently fails on the user's network: reachability changes, and the kill switch makes failure deterministic.

Do not stop at advice or example YAML when implementation is authorized. Inspect, back up, modify, reload, flush stale state, and verify the effective runtime.

## Protected scope

### Domains

Start with these default suffixes (include all subdomains) and add domains from observed Claude traffic or current official documentation:

```text
claude.ai
claude.com
anthropic.com
claudeusercontent.com
```

`claudeusercontent.com` (including `bridge.claudeusercontent.com` and Artifacts) is mandatory by default; omitting it causes traffic to fall through to `MATCH` (which is often `DIRECT` in rule mode).

### Official IP ranges (fallback routing & kill switch)

Always check [Anthropic's official IP page](https://platform.claude.com/docs/en/api/ip-addresses) at implementation time. As of 2026-11, published ranges are:

- **IPv4**: `160.79.104.0/21` (encompasses inbound `160.79.104.0/23`), `153.61.224.0/22` (inbound), and `153.61.208.0/20` (outbound; adjacent to `/22`, **not** overlapping!)
- **IPv6**: `2607:6bc0::/48`

Add these ranges as `IP-CIDR` / `IP-CIDR6` rules with `,no-resolve` to the Claude proxy group (to catch direct-IP bypasses without triggering local DNS lookups), and enforce them in the [host-network kill switch](#host-network-kill-switch).

### Coupled services & CLI telemetry

- **Auth / challenge / billing**: Check how `challenges.cloudflare.com`, `hcaptcha.com`, and `stripe.com` route during login, verification, or payment so they do not silently exit from a conflicting or unsupported region.
- **Claude Code non-essential traffic**: Where acceptable to the user, recommend setting `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (or targeted `DISABLE_TELEMETRY=1`, `DISABLE_ERROR_REPORTING=1`) to eliminate unnecessary outer connections (e.g. Statsig, Sentry).

## Non-negotiable facts

- **TUN ≠ proxied**: TUN/enhanced mode means traffic enters the proxy core; rules still decide `DIRECT`, proxy, or `REJECT`.
- **GUI override precedence & single source of truth**: Clients such as Clash Verge Rev apply global `config.yaml` and `dns_config.yaml` (when GUI DNS override is enabled) on top of profile merges/scripts—silently discarding `dns.*` / `tun.*` / `ipv6` written by Merge/Script and triggering startup warnings. Pick **one** owner (recommended: keep `config.yaml` + `dns_config.yaml` as the single source of truth and remove duplicate `dns`/`tun`/`ipv6` writes from Merge/Script) and verify the **final generated runtime config, startup log, and live controller API**.
- **Raw-IP DoH can fail on SOCKS5/HTTP nodes**: Some proxy nodes reject pure-IP targets (`1.1.1.1`, `8.8.8.8`), causing `https://1.1.1.1/dns-query#<Group>` to return `EOF` while domain-based HTTPS still works. Always test with live `/dns/query` and switch to verified domain-based DoH (e.g. `https://dns.twnic.tw/dns-query#<Group>`, `https://doh.opendns.com/dns-query#<Group>`) when pure-IP DoH fails.
- **Never mentally assume CIDR subsumption**: Verify every published IP range individually. Adjacent blocks can look inclusive at a glance when they are not (e.g. `153.61.208.0/20` ends at `.223.255` and does **not** cover inbound `153.61.224.0/22`). Probe a live representative IP from **each** block.
- **Browser WebRTC policies do not cover Electron or Safari**: Setting `WebRtcIPHandling = disable_non_proxied_udp` protects Chrome, but Electron desktop apps (Claude Desktop, IDE WebViews) and Safari ignore Chrome policies. If rule-mode `MATCH` defaults to `DIRECT` (`udp: true`), third-party WebRTC STUN servers can still leak the real public IP unless explicitly blocked on UDP in the proxy rules (surgically—without globally killing `UDP/3478`, which breaks domestic conferencing apps).
- **Dedicated group beats shared selector**: Binding Claude to a daily-browsing selector (`节点选择`) creates high risk—switching daily browsing to Hong Kong, mainland, or auto-test immediately drags background Claude sessions into an unsupported region. Isolate Claude in its own group unless the user explicitly accepts that risk.
- **Dynamic `utunN` interfaces**: macOS dynamically assigns `utunN` numbers unless explicitly pinned by a TUN driver, and secondary VPNs (Tailscale, WireGuard, corporate VPN) also create `utun` interfaces. Never rely on a dynamic `utunN` number, and never assume enumerating hardware ports alone covers secondary VPNs or hotspots.
- **Multi-AI coexistence**: If another platform (e.g., Google / Antigravity) requires a different region/group, bind Claude's DNS via per-domain `nameserver-policy` to Claude's own group rather than overriding a shared global `nameserver`.
- **Group label ≠ proof, node label ≠ single IP**: Resolve every group chain to its concrete node, confirm the node's country is Anthropic-supported, and probe repeatedly to confirm the exit IP/ASN does not rotate behind one label.
- **DNS provider ≠ DNS exit path**: Prove the actual outbound group and node carrying the encrypted DNS transport. Anycast city mismatch is acceptable only when logs prove the DNS transport traversed the approved Claude node and no forbidden mainland/local or wrong-region resolver appeared.
- **UDP safety cannot be inferred from TCP**: Old Clash cores skip a matched rule if the selected node has `udp: false` and may fall through to `DIRECT`; even on Mihomo, verify explicit UDP handling (`REJECT` or verified UDP-capable proxy) for Claude domains and QUIC (`UDP/443`).
- **Rules do not kill existing sessions or caches**: Changing proxy rules, switching nodes, or loading firewall blocks does not drop already-established TCP/HTTP2/WebSocket sockets, PF state-table entries, or OS/browser DNS caches. Flush them explicitly.
- **Never attach user credentials during probes**: All connectivity, latency, IP-stability, and kill-switch tests **must** be strictly unauthenticated (no browser cookies, OAuth tokens, API keys, or Claude Code / Desktop sessions). Never probe multiple candidate nodes with a logged-in account session—that itself creates a multi-IP account-risk signal.
- **Subscription node-rename resilience**: Hard-coded proxy names in a dedicated group can break profile reload (or silently drop members) if the subscription renames or removes nodes. Filter missing node names dynamically in the post-update script and fail closed (`REJECT`) if zero approved-region nodes remain—never fall back to `DIRECT` or unsupported regions.
- **Config text ≠ acceptance evidence**: Only post-change runtime observations can pass a gate.

## Procedure

### 1. Inspect without mutation

Determine:

- OS, active proxy application, exact core version, and any retired/competing proxy or DNS daemons (e.g. leftover LaunchAgents/LaunchDaemons from previous clients);
- active profile storage, subscription override chain (merge/script/rules/groups), and GUI-level override files (`verge.yaml`, `config.yaml`, `dns_config.yaml`, or iCloud profile paths);
- live runtime controller state (`/configs`, `/proxies`, `/connections`): mode, `ipv6`, `tun` (`device`, `strict-route`, `dns-hijack`), `sniffer`, active group chains, concrete node, node region, and `udp` flag;
- OS system-proxy state, `scutil --dns`, shell/launchd env vars (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`), browser proxy extensions, iCloud Private Relay, browser DoH / Async DNS / WebRTC / QUIC / ECH policies;
- every in-scope Claude client: browser, Claude Desktop, Claude Code CLI, IDE extensions, containers/WSL/remote hosts;
- existing host firewall / kill-switch rules (e.g. `/etc/pf.anchors/*`, `/Library/LaunchDaemons/*`, `pfctl -s info`, `pfctl -s References`) and other active VPN/hotspot interfaces.

Redact subscription URLs, credentials, node addresses, tokens, cookies and full public IPs in all reports.

### 2. Establish a baseline

Generate fresh Claude, asset (`claudeusercontent.com`), and DNS traffic. Record actual rule, full group chain, concrete node, exit IP/region (across repeated probes), network type, and DNS transport chain. Test IPv4, IPv6, DNS/DoH, WebRTC/STUN, UDP/QUIC, and direct physical-interface reachability to **all** published Anthropic IP blocks separately.

Separate these conclusions:

| Observation | Valid conclusion |
|---|---|
| System DNS points to Fake-IP (`198.18.x.x`) | DNS interception is active; upstream transport group/region is still unknown |
| Claude TCP log shows approved Taiwan node | HTTPS path is correct for that request only |
| DNS transport hits a US or mainland node while Claude HTTPS uses Taiwan | Split-region DNS leak—must fix via per-domain `nameserver-policy` |
| Selected node reports `udp: false` | Claude UDP/QUIC must have an explicit `REJECT` path |
| `160.79.104.10` is rejected on `en0`, but `153.61.224.1` completes TCP handshake | Kill switch is incomplete—missing Anthropic's second IPv4 block |

### 3. Back up

Back up every profile, GUI override file, firewall anchor, LaunchDaemon/LaunchAgent, and browser policy before editing. Record exact restore locations. Never expose secrets in logs or commits.

### 4. Implement invariants

Choose mechanisms supported by the detected client and version. The final effective runtime must satisfy every invariant:

1. **Rule precedence**: Place protected domain rules (`claude.ai`, `claude.com`, `anthropic.com`, `claudeusercontent.com`) and official Anthropic `IP-CIDR` / `IP-CIDR6` rules (with `,no-resolve`) before broader direct, GeoIP, and `MATCH` rules.
2. **Dedicated protected group**: Route all protected rules to one dedicated Claude selector group containing only Anthropic-supported-region manual nodes (decoupled from routine daily browsing). Do not include `DIRECT`, auto-latency test, fallback, or unsupported regions (CN/HK/MO/RU). Only nest a daily selector if the user explicitly requests it, and record the mis-switch risk.
3. **Per-domain encrypted DNS**: Pin encrypted DoH/DoT for all protected domains to the **same** Claude proxy group via `nameserver-policy` (on Mihomo with `respect-rules: true` and `proxy-server-nameserver`), or via a verified local forwarder on legacy cores. Never rely on a global `nameserver` that belongs to another region/service, and never allow mainland/local-ISP DNS for protected domains.
4. **Prevent DNS bypass & Fake-IP drift**: Hijack both UDP and TCP port 53 (`any:53`, `tcp://any:53`), block or intercept port `853` (DoT/DoQ), ensure protected domains are never excluded by `fake-ip-filter`, and enable `sniffer` (TLS/HTTP) on cores that support it.
5. **Reconcile GUI overrides & single source of truth**: On Clash Verge Rev or similar GUIs, when GUI DNS override is enabled, treat `config.yaml` (`ipv6: false`, `sniffer`, `tun.dns-hijack`) and `dns_config.yaml` (`nameserver-policy`) as the single source of truth and remove duplicate `dns`/`tun`/`ipv6` keys from Merge/Script so startup logs stay warning-free. If pure-IP DoH (`1.1.1.1`/`8.8.8.8`) fails on the selected node, use verified domain-based DoH (e.g. `dns.twnic.tw`, `doh.opendns.com`) pinned to `#<ClaudeGroup>`.
6. **IPv6, UDP/QUIC & WebRTC STUN safety**: Disable IPv6 unless end-to-end verified on the approved path. Add explicit UDP `REJECT` rules for protected domains (and QUIC `UDP/443`) so UDP never falls through to `DIRECT` on `udp: false` nodes. For **WebRTC**, enforce two layers:
   - **Browser policies**: Verify/set `WebRtcIPHandling = disable_non_proxied_udp`, `DnsOverHttpsMode = off`, `QuicAllowed = false` on Chromium browsers (via `defaults` / managed policies and `chrome://policy`), and keep Safari/other browsers out of scope or protected against STUN & iCloud Private Relay.
   - **Proxy STUN layer (covers Electron & Safari)**: Add explicit UDP `REJECT` rules for common foreign public STUN servers (`stun.cloudflare.com`, `stun.l.google.com`, `stun1-4.l.google.com`, `stun.stunprotocol.org`, `global.stun.twilio.com`) so non-Chrome apps cannot fall through to `MATCH → DIRECT` and leak the real public IP—while avoiding a blanket `UDP/3478` block that breaks domestic video conferencing (Feishu/WeChat/Zoom).
7. **Eliminate client/OS bypasses**: Turn off OS system proxy once TUN covers all in-scope clients (unless an observed client requires it); remove or align conflicting shell proxy env vars and browser proxy extensions; disable iCloud Private Relay for Claude browsing; retire zombie proxy/DNS LaunchAgents from previous proxy apps.
8. **Silence non-essential CLI telemetry**: Suggest or configure `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (or `DISABLE_TELEMETRY=1` / `DISABLE_ERROR_REPORTING=1`) if consistent with the user's workflow.
9. **Subscription resilience & fail-closed updates**: Use supported merge/override/script chains (watch iCloud permission limits) and add a post-update script guard that prunes removed/renamed node names from dedicated groups (preventing `proxy not exist` reload errors), optionally discovers replacement nodes only within an approved-region regex if all curated names disappear, and **fails closed to `REJECT`** if zero approved-region nodes remain. Prove invariants survive reload and synthetic node-removal tests.
10. **Host-network kill switch**: Install or update the [host-network kill switch](#host-network-kill-switch) covering all current Anthropic IPv4 & IPv6 blocks.
11. **Cutover flush**: After reloading, flush OS DNS cache (`dscacheutil -flushcache && sudo killall -HUP mDNSResponder` on macOS), clear browser DNS/socket pools, and close existing Claude connections via the proxy controller so no stale-IP sessions survive.

Do not claim that `tun: true`, Fake-IP, an overseas resolver address, or a group named `openAI` satisfies these invariants without runtime evidence.

## Client reference patterns

### Mihomo / Clash Verge Rev (recommended modern stack)

| Setting | Target |
|---|---|
| TUN mode | On (`strict-route: true`, `auto-route: true`, `auto-detect-interface: true`, `dns-hijack: [any:53, tcp://any:53]`) |
| System proxy | Off after verifying TUN covers every in-scope client |
| `ipv6` | `false` in **both** merge/profile and Clash Verge `config.yaml` |
| `sniffer` | Enabled for TLS/HTTP (`override-destination: true`, `force-dns-mapping: true`) |
| Protected group | Dedicated `Claude` group with fixed supported-region nodes (decoupled from daily selector) |
| Protected rules | `DOMAIN-SUFFIX` (`claude.ai`, `claude.com`, `anthropic.com`, `claudeusercontent.com`) + `IP-CIDR`/`IP-CIDR6` (`no-resolve`) for official Anthropic ranges → `Claude`; explicit UDP `REJECT` if `udp: false` |
| DNS | `enhanced-mode: fake-ip`, `respect-rules: true`, `proxy-server-nameserver` set, and `nameserver-policy` in `dns_config.yaml` pinning `+.claude.ai`, `+.claude.com`, `+.anthropic.com`, `+.claudeusercontent.com` to a verified DoH endpoint `#Claude` (use domain-based DoH such as `dns.twnic.tw` / `doh.opendns.com` if the node blocks pure-IP `1.1.1.1`/`8.8.8.8`) |
| WebRTC & STUN | Browser `WebRtcIPHandling = disable_non_proxied_udp` + proxy UDP `REJECT` for Claude domains and foreign public STUN servers (covers Electron/Safari without breaking domestic calls) |
| Persistence | Profile groups/rules/script (with dead-node pruning + fail-closed `REJECT`) + single-owner `config.yaml` / `dns_config.yaml` (no duplicate `dns`/`tun`/`ipv6` in Merge/Script, zero startup warnings) |

### Legacy ClashX Pro / Clash v1.10

Use when inspection confirms XPro enhanced mode is active:

- Enhanced mode ON, system proxy OFF once TUN coverage is proven, rule mode ON.
- Legacy Clash v1.10's built-in DoH dialer can connect directly instead of through a proxy group. Use a local encrypted DNS forwarder configured to send DoH through the local proxy port, route the DoH endpoint through the Claude group, and prove the chain in core logs.
- For every protected TCP rule targeting a `udp: false` group, add a later matching `REJECT` rule so skipped UDP never falls through to `DIRECT`.
- If XPro stores profiles in iCloud and a background agent cannot read that path, move to a supported local path before reporting persistence as solved.

## Host-network kill switch

Required. Target behavior: connections to all published Anthropic IPv4 and IPv6 ranges are rejected at the OS firewall on every non-proxy path, so Claude can never leave directly when the proxy app is closed, crashed, TUN is down, the proxy is switched to direct mode, or a rule routes Claude to `DIRECT`.

Installing or modifying the kill switch touches root-level persistence. Tell the user the exact files, rules, and removal steps before writing, and get explicit consent.

### macOS (`pf`)

1. **Fetch current official ranges** from [Anthropic's IP page](https://platform.claude.com/docs/en/api/ip-addresses) (as of 2026-11: IPv4 `160.79.104.0/21`, `153.61.224.0/22`, `153.61.208.0/20`; IPv6 `2607:6bc0::/48`). Store them in a `pf` table (`table <anthropic> const { ... }`) inside a dedicated sub-anchor under `com.apple/*` (e.g. `com.apple/claude-killswitch` or `com.apple/claude-guard`). Do not edit or flush `/etc/pf.conf`.
2. **Choose the strictest interface strategy for the active proxy mode**:
   - **Strategy A — Fake-IP global block (strongest, recommended when Fake-IP is active)**: Under Fake-IP, proxied clients connect to `198.18.0.0/15`, and the proxy core connects to the proxy node's IP—neither emits packets addressed to Anthropic's real IP blocks on any interface. Load unconditional `block return out quick inet to <anthropic>` and `block return out quick inet6 to <anthropic>` (no interface list required). This automatically blocks physical ports, USB hotspots, `bridge*`, and secondary VPN `utun` interfaces without hardcoding any `utunN`.
     *(Only add a `pass out quick on <pinned_tun>` exception if the proxy explicitly pins a static TUN device name AND real-IP direct connections through TUN are an intentional requirement; never allow-list a dynamic macOS `utunN`.)*
   - **Strategy B — Non-TUN interface block (for Redir-Host / real-IP TUN)**: Enumerate hardware ports (`networksetup -listallhardwareports`) **plus** active non-proxy interfaces (hotspots, `bridge*`, secondary VPNs) at load time and block outbound `<anthropic>` on all of them.
3. **Prevent `pfctl -E` reference-count leaks**: macOS `pfctl -E` increments a kernel reference counter on every invocation. Do **not** blindly run `pfctl -E` on every `WatchPaths` reload. Either check `pfctl -s info` and only call `pfctl -E` when disabled (recording the returned token once so uninstall can release it with `pfctl -X <token>`), or separate one-time enablement from rule reloads.
4. **Flush existing PF states on load/reload**: Loading `block` rules does not terminate already-established states in the PF state table. Run `pfctl -k 0.0.0.0/0 -k <CIDR>` (and IPv6 equivalent) for each Anthropic range immediately after loading the anchor.
5. **Pre-flight validation & persistence**:
   - Validate anchor syntax with `pfctl -n -f <anchor_file>` before loading.
   - Persist with a root LaunchDaemon (`root:wheel`, `0644`, validated via `plutil -lint`) using `RunAtLoad`; for Strategy B also add `WatchPaths` on `/Library/Preferences/SystemConfiguration/preferences.plist`.
   - Record the anchor name, daemon path, anchor/script path, stored token path, and exact uninstall steps (`launchctl bootout`, `pfctl -a <anchor> -F all`, `pfctl -X <token>`, delete files).

#### Extending to additional AI platforms (optional)

If the user also requires host-level direct-egress blocking for another region-sensitive AI platform (for example Google Antigravity), add a separate `pf` `table` (e.g. `table <antigravity>`) in the same anchor using verified dedicated entry ranges—and **first prove zero IP overlap** against both:
1. any intentional `DIRECT` exceptions (e.g. `storage.googleapis.com` via local DNS, CDN downloads), and
2. all configured proxy server IPs.

Never block broad shared cloud/CDN ranges (`34.0.0.0/8`, `142.250.0.0/15`, etc.) without verifying collateral impact.

#### Kill-switch gate

| Check | PASS condition |
|---|---|
| Proxied Claude | Unauthenticated probes to `claude.ai`, `api.anthropic.com`, and `bridge.claudeusercontent.com` succeed via the approved Claude group/node |
| Direct IPv4 (every block) | Interface-bound `curl --interface <active_phys>` to a representative IP in **every** published block (`160.79.104.10`, `153.61.224.1`, and any additional protected table) fails immediately in milliseconds (local reject, no TCP handshake) |
| Direct IPv6 | Interface-bound request to `2607:6bc0::` fails cleanly |
| Direct UDP/QUIC | Outbound UDP to Anthropic ranges on physical port is rejected |
| Real proxy-down test | With proxy app paused/stopped, `claude.ai` and `api.anthropic.com` fail outright; after resuming proxy + flushing DNS cache, access recovers cleanly |
| Control & direct exceptions | Same interface-bound request to a non-protected address succeeds, and intentional `DIRECT` exceptions remain reachable |
| Persistence & hygiene | Rules survive reboot (confirm after actual reboot); `pfctl -s References` shows no leaked duplicate tokens |

### Other operating systems

Implement the equivalent OS firewall block for all published Anthropic IPv4 & IPv6 ranges (global block in Fake-IP mode, or physical + non-proxy adapters otherwise), loaded at boot, with existing connection state cleared. If no equivalent can be implemented, mark the kill-switch gate `FAIL`, never `PASS`.

Residual risks (state honestly in the report):
- while the proxy is down, the OS may still send Claude DNS queries to the local resolver (no traffic reaches Anthropic, but the local DNS sees the lookup);
- static `pf` tables do not auto-refresh if Anthropic publishes a new IP block or an optional single-IP LB changes;
- coupled third-party domains outside protected IP tables (OAuth, Captcha, Stripe) are not blocked by IP-range rules alone;
- host-level rules protect only this machine, not mobile apps or remote servers logged into the same account.

## Acceptance gates

Run every applicable gate and mark it `PASS`, `FAIL`, or `NOT TESTED`.

| Gate | PASS condition |
|---|---|
| Interception | System proxy is off (when TUN-only is chosen) and every declared Claude client appears in the TUN/core log |
| Config precedence & startup hygiene | Live controller `/configs` and final generated runtime config match all invariants; startup log shows zero discarded app-managed field warnings |
| Rule mode | Runtime controller reports `rule` mode after reload/restart |
| Dedicated group & region | Claude rules resolve only to the dedicated Claude group and an Anthropic-supported concrete node (not CN/HK/MO/RU, no auto-fallback/DIRECT) |
| Exit IP stability | Repeated unauthenticated probes via Claude endpoint return a consistent supported-region exit IP/ASN |
| Claude TCP & assets | Fresh unauthenticated requests to `claude.ai`, `api.anthropic.com`, and `claudeusercontent.com` log the Claude group and concrete node |
| DNS transport & region | Live `/dns/query` succeeds (`Status: 0`) and DNS transport logs the **same** Claude group/node (not mainland/local ISP, not a different-region AI group, no `EOF` on raw-IP-blocking nodes) |
| Plain & encrypted DNS bypass | Port 53 (UDP + TCP) is hijacked; port 853 (DoT/DoQ) and hard-coded resolvers cannot expose protected queries |
| IPv6 | Disabled or verified on the same approved path |
| WebRTC & STUN | Browser `WebRtcIPHandling = disable_non_proxied_udp` verified **and** direct RFC 5389 UDP STUN probes (`stun.cloudflare.com:3478`, `stun.l.google.com:19302`) do not reply via `DIRECT` (covering Electron/Safari too) |
| UDP/QUIC | Approved proxy path or explicit `REJECT`; never falls through to `DIRECT` |
| Client & OS bypass audit | No conflicting shell/launchd proxy env vars, browser proxy extensions, iCloud Private Relay, or zombie legacy daemons |
| Cutover hygiene | OS/browser DNS cache flushed and pre-change Claude connections closed |
| Dynamic interface | No configuration depends on a dynamic macOS-assigned `utunN` number |
| Restart & subscription update | Reload, proxy restart, subscription refresh, and synthetic node-removal tests preserve every invariant (fail-closed `REJECT` if zero approved nodes remain) |
| Unrelated routing | Representative domestic, LAN, direct exceptions, and other-region (e.g. Google) destinations retain intended routing |
| Host-network kill switch | Every check in the [kill-switch gate](#kill-switch-gate) passes, including every IP block individually, real proxy-down test, and reboot persistence |

Combine independent native CLI evidence (`dig`, `curl https://claude.ai/cdn-cgi/trace`, direct `--interface` probes, and local proxy controller `/connections` logs) with optional browser verification such as [Claude AI IP risk detection](https://ip.net.coffee/claude/). Never rely on a single third-party webpage alone.

## Report

Lead with one conclusion:

- **Accepted for declared scope**: every mandatory gate passed;
- **Partially verified**: no observed failure, but at least one gate was not tested;
- **Rejected**: at least one gate failed.

Return a compact table with gate, status, redacted evidence, and remaining risk (including multi-device concurrent login risk if the same account is used on mobile/other hosts). Never label an unrun test `PASS`.

This skill reduces network-path inconsistency and direct-egress risk. It cannot guarantee account safety against proxy-IP reputation, cookies, account history, multi-device multi-region usage, fingerprinting, time zone, language, or platform policy.
