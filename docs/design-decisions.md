# Topology Design Decision Record

Use this document to record the decisions made during Activity 01. Replace the example values with the configuration used in your own lab.

## Document control

| Field | Value |
|---|---|
| Lab owner | Your name |
| Design date | YYYY-MM-DD |
| Hypervisor | Hyper-V, VMware Workstation, VirtualBox, Proxmox, or other |
| Host operating system | Windows, Linux, or macOS |
| Lab purpose | Active Directory learning and controlled testing |
| Production connectivity | None |

## Decision 1: isolation model

**Selected design:** Hypervisor NAT network

**Alternatives considered:**

- Internal-only virtual switch.
- Bridged network.
- Separate physical VLAN.

**Decision rationale:**

NAT permits outbound update traffic while preventing the lab's DHCP, DNS, and domain services from being exposed directly to the physical LAN. Bridged networking was rejected because an incorrectly configured lab service could affect unrelated devices.

**Security consequence:**

The hypervisor and host become part of the trust boundary. Host-to-guest file sharing, clipboard integration, and mounted folders should be disabled when testing suspicious scripts or security scenarios.

## Decision 2: forest model

**Selected design:** One forest and one domain named `corp.lab`

**Alternatives considered:**

- Multiple domains in one forest.
- Separate resource and account forests.
- A child-domain hierarchy.

**Decision rationale:**

The beginner lab has one administrative owner and no requirement for schema separation or cross-organizational trust. Multiple domains would add complexity without supporting the current learning objective.

**Future change:**

A second forest is introduced later for explicit forest-trust testing. It should not be added during this activity.

## Decision 3: DNS namespace

**Selected DNS name:** `corp.lab`

**Selected NetBIOS name:** `CORP`

**Validation questions:**

- Does this name conflict with an existing VPN, customer, home, or production namespace?
- Is the DNS name multi-label?
- Is the NetBIOS name 15 characters or fewer?
- Will clients use the domain controller as their resolver after promotion?

## Decision 4: addressing plan

| Purpose | Address or range | Assignment |
|---|---|---|
| Network | `10.10.10.0/24` | Virtual lab subnet |
| Gateway | `10.10.10.1` | Hypervisor NAT |
| DC01 | `10.10.10.10` | Static |
| DC02 | `10.10.10.11` | Static and reserved for a later activity |
| SRV01 | `10.10.10.20` | Static |
| Clients | `10.10.10.100-199` | DHCP or controlled static assignment |

**Overlap check:**

Record the physical LAN, VPN, container, and other hypervisor subnets below. The lab subnet must not overlap any route that the host already uses.

| Interface or service | Existing prefix | Conflict found |
|---|---|---|
| Physical LAN |  | Yes / No |
| Corporate VPN |  | Yes / No |
| Docker or WSL |  | Yes / No |
| Other hypervisors |  | Yes / No |

## Decision 5: system inventory

| Name | Role | OS | vCPU | RAM | Disk | IPv4 |
|---|---|---|---:|---:|---:|---|
| DC01 | First domain controller and DNS | Windows Server 2025 | 2 | 4 GB | 60 GB | 10.10.10.10 |
| DC02 | Additional domain controller | Windows Server 2025 | 2 | 4 GB | 60 GB | 10.10.10.11 |
| SRV01 | Member and infrastructure server | Windows Server 2025 | 2 | 4 GB | 60 GB | 10.10.10.20 |
| CL01 | Domain client | Windows 11 Pro | 2 | 4 GB | 64 GB | DHCP reservation or 10.10.10.101 |

## Decision 6: snapshot and recovery boundaries

Snapshots are used only as short-lived lab checkpoints. They are not treated as a supported Active Directory backup strategy.

Planned checkpoints:

1. Clean operating-system installation.
2. Fully patched pre-role baseline.
3. Post-promotion health validation.
4. Before each destructive recovery exercise.

Record every snapshot with:

- VM name.
- Creation timestamp.
- Directory state.
- Whether the VM is a domain controller.
- Why the snapshot exists.
- Planned deletion date.

## Threat model

| Threat | Likelihood | Impact | Control |
|---|---|---|---|
| Lab DHCP affects physical devices | Medium with bridging | High | NAT or internal-only switch |
| Secrets committed to GitHub | Medium | High | Evidence review, `.gitignore`, no credentials |
| Malware or unsafe tooling reaches host | Low to medium | High | Disable integration features and use isolation |
| Duplicate IP addressing | Medium | Medium | Reserved address plan and validator |
| Public DNS assigned to domain members | High for beginners | High | Document internal DNS requirements |
| Host resource exhaustion | Medium | Medium | VM sizing and staged startup |

## Approval checklist

- [ ] The selected subnet does not overlap a connected network.
- [ ] The lab is not bridged to a customer or production LAN.
- [ ] The forest owner and purpose are documented.
- [ ] All machine names and addresses are unique.
- [ ] Domain controllers have static addressing.
- [ ] DNS resolver behavior is documented.
- [ ] Snapshot use and limitations are understood.
- [ ] No credentials or licence keys appear in repository evidence.
- [ ] `scripts/Test-LabPlan.ps1` passes.
