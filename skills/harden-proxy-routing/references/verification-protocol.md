# Verification protocol

Run checks in this order after restarting the proxy client. Classify every applicable gate as `PASS`, `FAIL`, or `NOT TESTED`. A setup is not accepted while any mandatory gate is `FAIL` or `NOT TESTED`.

| Gate | Mandatory | Evidence | PASS condition |
|---|---:|---|---|
| Scope declaration | Yes | Protected apps/domains and allowed direct traffic | Scope is explicit enough to distinguish intended direct traffic from leakage |
| Runtime route | Yes | Client connection/log entry during a fresh protected request | Protected domain selects the intended proxy group and actual proxy node |
| IPv4 egress | Yes | Fresh HTTPS egress observation | Address/ASN belongs to the expected proxy exit, not local ISP |
| IPv6 egress | Yes | Fresh IPv6 probe | Same protected exit, or IPv6 fails cleanly without local ISP egress |
| DNS path | Yes | Deep DNS test plus client log when available | Protected/overseas query shows no local ISP or forbidden-region resolver path |
| Encrypted DNS | Yes | DoH/DoT endpoint traffic in client log or packet observation | DoH/DoT cannot bypass the protected route; no forbidden direct endpoint appears |
| Browser DoH | Yes for browsers | Browser DNS test and browser secure-DNS setting | Browser DoH follows the protected route or is disabled in favor of intercepted DNS |
| WebRTC/STUN | Yes for browsers/RTC apps | WebRTC test and client log | No public local address; STUN follows protected proxy or fails cleanly |
| UDP/QUIC | Yes when used by protected apps | Client log or controlled packet observation | Protected UDP/QUIC follows the intended outbound or fails cleanly |
| Non-browser protected app | Yes when in scope | Fresh app request and route log | App does not bypass the browser/system proxy path |
| In-core fail-closed | Yes | Deliberately unavailable protected node/`REJECT`, plus route log | Protected request fails and no direct connection is created |
| Process-exit kill switch | Only if claimed | Controlled core-exit test and OS firewall evidence | Protected/device traffic cannot use direct networking after the proxy process exits |
| Persistence | Yes when subscriptions update | Update subscription/reload, then repeat runtime route and DNS gates | Hardening remains effective without editing the downloaded subscription body |
| Restore | Yes | Restore execution and post-restore parse/start check | Backup restores successfully and client can load the restored configuration |

## Recommended probes

- `https://ip.net.coffee/dns/` — deep DNS test.
- `https://browserleaks.com/dns` — browser-specific DoH/resolver view.
- `https://dnsleaktest.com/` — extended resolver test.
- `https://browserleaks.com/webrtc` — WebRTC/UDP exposure.

## Interpretation rules

- Detecting a DNS resolver is normal. It is a leak only when that resolver contradicts the intended path or privacy boundary.
- Cloudflare/Google recursive DNS may exit in a nearby or distant region because of anycast. It need not be in the exact proxy city.
- A destination HTTP server normally sees the proxy connection IP, not the client's recursive resolver field. DNS/CDN telemetry can still create a correlatable inconsistency signal.
- A successful `curl -6` showing a local ISP address is an IPv6 bypass even if IPv4 is correct.
- TUN `strict-route` protects while the core runs; it is not an OS firewall kill switch after process exit.

## Acceptance report format

Lead with the conclusion, then return a compact table with: `Gate`, `Status`, `Observed evidence`, and `Remaining risk`. Never turn an unrun probe into `PASS`; use `NOT TESTED`. Keep implementation detail out unless it explains a failed gate. Redact public IPs to a coarse prefix and remove subscription URLs, node addresses, UUIDs, tokens, and cookies.

The final conclusion must be one of:

- **Accepted for declared scope**: every mandatory gate passed;
- **Partially verified**: no observed failure, but one or more mandatory gates were not tested;
- **Rejected**: at least one mandatory gate failed.

Only **Accepted for declared scope** may be summarized as “network leakage solved.”

## Fail-closed test precautions

Prefer selecting a known non-working test node or a temporary `REJECT` outbound for the protected group. Record the original selection and restore it immediately. Do not stop the only remote-access tunnel on a remote machine.
