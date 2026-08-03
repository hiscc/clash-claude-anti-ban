# Client matrix

| Client family | Detect | Audit guidance | Reference implementation | Using agent responsibility |
|---|---:|---:|---:|---|
| Clash Verge Rev + Mihomo | Yes | Yes | Root scripts | Inspect installed schema and adapt persistent Merge/Rules/Script safely |
| Standalone Mihomo | Yes | Yes | Concepts only | Determine its distinct config and reload lifecycle |
| ClashX Pro / legacy Clash Premium | Yes | Yes | Diagnostic reference | Account for subscription overwrite and missing modern persistent overrides |
| Surge macOS/iOS | Yes | Partial | Concepts only | Verify enhanced mode, encrypted DNS, policy fallback, and IPv6 in current docs |
| sing-box | Yes | Partial | Concepts only | Verify TUN strict route, DNS route rules, and final outbound in current docs |
| WireGuard / OpenVPN | Yes | Partial | Concepts only | Design full-tunnel and OS firewall kill switch separately |
| Tailscale exit node | Yes | Partial | Concepts only | Check exit-node selection, DNS acceptance, and LAN access |
| Shadowrocket / Loon / Quantumult | Manual | Checklist | Concepts only | Implement through device UI/config and verify on device |
| Unknown client | Process/config discovery | Generic snapshot | Adapter contract | Discover read-only, then create a client-specific implementation |

No row authorizes blind automatic mutation. “Reference implementation” means material for the using agent to inspect and adapt, not a compatibility promise.
