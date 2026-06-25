# AD Learning Path 01 — Plan the Lab Topology

> Beginner activity 01 of 64. This repository covers one activity only: designing a safe, reproducible Active Directory lab before any virtual machines are built.

## Objective

Create a documented topology for a small Windows Server Active Directory lab that can be expanded throughout the learning path without requiring a redesign.

By the end of this activity, you will have:

- A defined forest and domain name.
- A documented IP addressing plan.
- A server and workstation naming convention.
- A virtual network design that isolates the lab from production devices.
- Minimum CPU, memory, storage, and operating-system requirements.
- A dependency map showing which later activities require each system.
- A validated `lab-plan.json` file that can be reused by future automation.

## Why planning comes first

Active Directory Domain Services is not only a user database. It is a distributed identity, authentication, authorization, policy, directory, DNS, and replication platform. AD DS stores network objects in a hierarchical directory, integrates authentication and access control, uses a schema to define object types, maintains a Global Catalog, and replicates directory changes between domain controllers.

A poor initial design usually creates avoidable problems later:

- Clients point to public DNS instead of the domain controller.
- The domain name conflicts with an existing public or home network namespace.
- Domain controllers receive dynamic IP addresses.
- The lab can reach production devices or the household router.
- Snapshots are taken at unsafe points and later restored without understanding AD replication implications.
- Server names, site names, and subnets are inconsistent.
- Resource limits cause slow promotion, replication failures, or misleading troubleshooting results.

## Recommended beginner topology

```text
                         Optional Internet access
                                  |
                           [Hypervisor NAT]
                                  |
                     10.10.10.0/24 Lab Network
                                  |
          +-----------------------+-----------------------+
          |                       |                       |
     DC01.corp.lab           SRV01.corp.lab          CL01.corp.lab
     10.10.10.10             10.10.10.20            10.10.10.101
     Windows Server 2025     Windows Server 2025     Windows 11 Pro
     AD DS + DNS             Member server           Domain client

Future additions:

     DC02.corp.lab           CL02.corp.lab            Second site subnet
     10.10.10.11             10.10.10.102             10.20.20.0/24
```

## Baseline design

| Component | Recommended value | Reason |
|---|---:|---|
| Forest root domain | `corp.lab` | Short, non-production namespace for an isolated training environment |
| NetBIOS name | `CORP` | Derived from the left-most DNS label |
| First domain controller | `DC01` | Predictable role-based naming |
| Second domain controller | `DC02` | Used later for replication, FSMO, DNS, and resiliency labs |
| Member server | `SRV01` | Used for file services, DHCP, software deployment, and service-account labs |
| First client | `CL01` | Used for domain join, Group Policy, authentication, and troubleshooting |
| First subnet | `10.10.10.0/24` | Simple private subnet with room for expansion |
| Default gateway | `10.10.10.1` | Hypervisor NAT gateway when Internet access is required |
| DC01 address | `10.10.10.10` | Static address for AD-integrated DNS and domain services |
| DC02 address | `10.10.10.11` | Static address reserved for the second domain controller |
| SRV01 address | `10.10.10.20` | Static address for infrastructure services |
| Client DHCP range | `10.10.10.100-199` | Keeps clients separate from infrastructure addresses |
| Preferred client DNS | `10.10.10.10` | Domain members must use AD-aware DNS |
| Time zone | `South Africa Standard Time` | Matches the lab operator and simplifies event correlation |

## Virtual machine sizing

These are lab baselines, not enterprise capacity recommendations.

| VM | vCPU | RAM | Disk | Network |
|---|---:|---:|---:|---|
| DC01 | 2 | 4 GB | 60 GB | Lab network |
| DC02 | 2 | 4 GB | 60 GB | Lab network |
| SRV01 | 2 | 4 GB | 60 GB | Lab network |
| CL01 | 2 | 4 GB | 64 GB | Lab network |

For simultaneous use of four VMs, plan for at least:

- 8 logical host CPU threads.
- 20 GB available host RAM.
- 250 GB free SSD storage.
- Hardware virtualization enabled in firmware.
- A hypervisor supporting isolated or NAT virtual switches.

## Network isolation model

### Preferred: isolated NAT network

The VMs can reach the Internet through the hypervisor, but unsolicited inbound traffic from the physical LAN cannot reach the lab. This is the most convenient option for updates and downloads.

### Maximum isolation: internal-only network

The VMs can communicate only with each other and the host. Add a temporary second adapter when updates are required, then remove it.

### Avoid: bridged networking

Do not place an experimental domain controller directly on a household, office, or customer LAN. A lab DHCP server, DNS server, duplicate name, or misconfigured route can disrupt real devices.

## Naming standard

Use role-based names that stay meaningful when the lab grows.

| Prefix | Purpose | Examples |
|---|---|---|
| `DC` | Domain controllers | `DC01`, `DC02` |
| `SRV` | General member servers | `SRV01` |
| `FS` | File servers | `FS01` |
| `APP` | Application servers | `APP01` |
| `CL` | Windows clients | `CL01`, `CL02` |
| `ADM` | Privileged access workstations | `ADM01` |

Rules:

1. Use uppercase computer names.
2. Keep names at or below 15 characters for compatibility with legacy NetBIOS-based tooling.
3. Do not encode mutable information such as a user name in a server name.
4. Do not reuse the same computer name after cloning without generalizing the image.
5. Reserve addresses and names before building systems.

## Forest and domain design decision

For this learning path, use a single forest with a single domain:

```text
Forest: corp.lab
Domain: corp.lab
NetBIOS: CORP
```

A single-domain forest is appropriate because the lab has one administrative boundary and one schema. Additional domains add DNS, replication, trust, administration, and recovery complexity. A second forest is introduced later as a deliberate trust lab.

Microsoft's forest-design guidance recommends identifying ownership, requirements, forest purpose, and the number of forests before deployment. Documenting those decisions prevents the forest from becoming an accidental boundary.

## Activity procedure

### 1. Record the hypervisor

Document the hypervisor product and version, host operating system, available CPU, memory and storage, virtual-switch type, and snapshot/export locations.

### 2. Select the namespace

Use `corp.lab` for this series unless you already operate that namespace elsewhere.

Do not use a customer namespace, a real company domain you do not control, a namespace already used by the router or VPN, or a single-label domain such as `CORP`.

### 3. Build the addressing plan

```text
10.10.10.1       NAT gateway
10.10.10.10      DC01
10.10.10.11      DC02
10.10.10.20      SRV01
10.10.10.30-49   Future infrastructure
10.10.10.100-199 DHCP clients
10.10.10.200-254 Reserved
```

### 4. Define DNS behavior

Before AD DS is installed, DC01 may temporarily use an external resolver for updates. After promotion:

- DC01 should use itself or another internal domain controller for DNS.
- Domain clients should use only internal AD DNS servers.
- External resolution should be provided through DNS forwarders, not by assigning public DNS directly to clients.

### 5. Define snapshot boundaries

1. Take a clean snapshot before role installation.
2. Take a second snapshot after successful promotion and health validation.
3. Label snapshots with exact state and date.
4. Do not treat snapshots as an AD backup strategy.
5. Use system-state backup activities later in the path for supported recovery practice.

### 6. Complete the machine-readable plan

```powershell
Copy-Item .\lab-plan.example.json .\lab-plan.json
.\scripts\Test-LabPlan.ps1 -Path .\lab-plan.json
```

### 7. Save evidence

Add the completed design and screenshots under `evidence/`. Never commit product keys, passwords, API tokens, customer details, or screenshots containing unrelated sensitive data.

## Success criteria

- [ ] The lab uses an isolated or NAT virtual network.
- [ ] The forest and domain names are documented.
- [ ] Every planned system has a unique name and IP address.
- [ ] Domain controllers and infrastructure servers use static addresses.
- [ ] Client DNS points to the planned domain controller.
- [ ] The host has sufficient resources for the selected VMs.
- [ ] The topology diagram matches the addressing table.
- [ ] `Test-LabPlan.ps1` exits with code `0`.
- [ ] Evidence is stored without credentials or sensitive customer data.

## Technical findings

These findings are design conclusions, not fabricated command output:

1. **DNS is a core AD dependency.** Domain location relies on DNS records, so client resolver configuration belongs in the initial design.
2. **A single forest is the simplest valid boundary for this lab.** A second forest should be introduced only for a specific cross-forest objective.
3. **Static infrastructure addresses reduce hidden dependencies.** A domain controller changing address can disrupt DNS referrals, domain join, authentication, and service discovery.
4. **Subnet documentation becomes operational data later.** Active Directory Sites and Services maps IP prefixes to sites, influencing domain-controller location and replication behavior.
5. **Isolation is a security control.** It prevents experimental DHCP, DNS, routing, and policy changes from affecting production or home devices.

## Troubleshooting

### Duplicate addresses

Two machines use the same `ipv4Address`. Assign a unique static address to each infrastructure system.

### Client DNS uses a public resolver

Set the client DNS server to DC01's planned address. Public resolvers do not host the AD domain's service records.

### Subnet overlaps the physical LAN

Choose a different RFC1918 subnet and recreate or update the virtual switch.

### The host cannot run all VMs

Start with DC01 and CL01. Add SRV01 and DC02 only when their activities begin.

### The isolated network has no Internet access

Use hypervisor NAT or a temporary update adapter. Do not solve this by bridging the domain controller directly onto an uncontrolled LAN.

## Repository contents

```text
README.md
lab-plan.example.json
docs/
  design-decisions.md
evidence/
  README.md
scripts/
  Test-LabPlan.ps1
tests/
  Test-LabPlan.Tests.ps1
```

## Authoritative references

- Microsoft Learn — Active Directory Domain Services overview: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview
- Microsoft Learn — Creating a Forest Design: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/creating-a-forest-design
- Microsoft Learn — Creating a Site Design: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/creating-a-site-design

## Next activity

Continue with `AD-Learning-Path-02-Create-an-Isolated-Virtual-Network`.
