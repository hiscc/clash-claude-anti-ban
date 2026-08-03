---
name: harden-proxy-routing
description: Diagnose and harden proxy/VPN routing against IP, DNS, IPv6, WebRTC, browser DoH, and fail-open leaks. Use when a user asks why a proxy still exposes DNS or location, wants Claude/AI traffic pinned to a safe proxy group, needs kill-switch/fail-closed behavior, wants to configure Clash Verge Rev, Mihomo, ClashX Pro, Surge, sing-box, WireGuard/OpenVPN, Tailscale, Shadowrocket, Loon, Quantumult, or another proxy client, or wants to verify a proxy setup after changes.
---

# Harden Proxy Routing

Treat proxy safety as a path-consistency problem: protected application traffic, DNS, IPv4/IPv6, UDP, and failure behavior must agree on the intended outbound.

This skill is an implementation specification, not a universal installer. It provides reasoning, read-only discovery helpers, reference code, adapter requirements, and acceptance gates. The agent using this skill must inspect the actual client and version, design the client-specific change, implement it in the user's environment, and verify the effective runtime.

## Outcome contract

The result matters more than the mechanism. Continue diagnosing and implementing until every mandatory network-leak gate for the declared scope passes, or report the exact unresolved gate. Do not present configuration edits, a successful restart, or a clean source-file audit as completion.

“Network leakage solved” means that fresh runtime tests show no unintended public-network path for:

- protected application traffic over IPv4 or IPv6;
- classic DNS, encrypted DNS/DoH/DoT, and client-specific DNS;
- browser WebRTC/STUN and other relevant UDP/QUIC traffic;
- fallback behavior when a proxy node, policy group, or proxy process is unavailable;
- the same paths after reload, restart, and subscription update.

It does not mean the proxy provider cannot observe traffic, or that cookies, accounts, device/browser fingerprints, time zone, language, IP reputation, and platform policy risks disappear. Keep these non-network risks out of the network acceptance claim.

## Workflow

1. State the protected scope before changing anything. Distinguish “Claude/overseas traffic must fail closed” from “the entire device must never use direct networking.”
2. Run the read-only helpers `scripts/detect-proxy-clients.sh` and `scripts/capture-network-snapshot.sh`. Redact public IPs before posting output publicly.
3. Classify the finding as one or more of:
   - wrong HTTP/TLS outbound;
   - DNS resolver bypass;
   - IPv6 bypass;
   - browser DoH bypass;
   - WebRTC/UDP exposure;
   - proxy-group or PAC fail-open.
4. Read `references/client-matrix.md`. Load only the reference for the detected client. For unknown clients, follow `references/adapter-contract.md` and do read-only discovery before proposing edits.
5. Produce an implementation plan tied to observed files, lifecycle, version, and recovery path. The repository's Clash Verge Rev code is a reference implementation only; inspect and adapt it instead of treating it as a portable answer.
6. When the user's request authorizes implementation, the agent performs it:
   - back up every changed file and record how to restore it;
   - verify current field names against the installed version or official documentation;
   - preserve subscription-update persistence without editing remote subscription bodies;
   - stop rather than guess when the protected proxy group or configuration lifecycle is ambiguous.
7. Restart the client when required and execute `references/verification-protocol.md`. Configuration inspection alone never proves that leakage is closed.
8. Lead the report with the acceptance conclusion and failed/untested gates. Keep implementation detail brief unless the user asks for it. Report every gate as `PASS`, `FAIL`, or `NOT TESTED`, with observed evidence separated from inference. A DNS resolver in another region is a consistency signal, not proof that the destination learned the user's real IP.

## Division of responsibility

| This skill provides | The using agent must do |
|---|---|
| Threat model and diagnostic order | Discover the installed client, version, active profile, and overwrite lifecycle |
| Read-only detection/snapshot scripts | Redact secrets and interpret evidence |
| Invariants and adapter contract | Design and implement the client-specific change |
| Clash Verge Rev reference code | Reuse only after checking compatibility; never assume it fits another client |
| Acceptance protocol | Restart, test effective traffic, classify every gate, and roll back failures |

Do not claim that this skill itself changed or secured the machine. Only the using agent's observed implementation and post-change evidence can support that conclusion.

## Invariants

- Preserve an independent direct-only group when explicit local/CN rules need it.
- Remove `DIRECT` and direct-group references from every non-direct proxy group.
- Replace an accidentally empty protected group with `REJECT`, never `DIRECT`.
- Bind protected DNS to the same proxy group as protected application traffic.
- Disable IPv6 unless the complete proxy path has been verified dual-stack.
- Remove PAC `DIRECT` fallback for protected traffic.
- Treat proxy-node bootstrap DNS as a documented exception; it must not resolve protected domains.
- Do not claim “anti-ban” guarantees. This skill reduces observable network inconsistencies; it cannot control IP reputation, accounts, cookies, fingerprints, or platform policy.

## Safety

- Do not stop a live proxy or install firewall rules without a known recovery path.
- Do not perform a destructive kill-switch test over a remote-only connection.
- Do not alter browser windows while debugging.
- If the user requests a device-wide kill switch, explain that TUN `strict-route` does not protect against the proxy process exiting; firewall-level enforcement is a separate high-risk adapter.

## References

- Client selection and support level: `references/client-matrix.md`
- New-client adapter requirements: `references/adapter-contract.md`
- Test order and interpretation: `references/verification-protocol.md`
- ClashX Pro limitations and migration: `references/clashx-pro.md`
