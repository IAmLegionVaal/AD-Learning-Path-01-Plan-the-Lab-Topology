# Activity 01 Evidence

Store proof that the topology was planned and validated here.

## Recommended evidence

- `topology-diagram.png` — diagram showing network, VMs, roles, addresses, and traffic boundary.
- `completed-design-decisions.md` — copy of the design record with your values.
- `validation-output.txt` — output from `scripts/Test-LabPlan.ps1`.
- `host-capacity.txt` — non-sensitive CPU, memory, storage, and hypervisor details.
- `network-overlap-check.txt` — routes or subnet list used to confirm there is no overlap.

## Capture validation output

```powershell
.\scripts\Test-LabPlan.ps1 -Path .\lab-plan.json *>&1 |
    Tee-Object -FilePath .\evidence\validation-output.txt
```

## Evidence quality rules

Evidence should prove the activity was completed without exposing sensitive information.

Before committing, remove or redact:

- Passwords and secure strings.
- Windows or application product keys.
- GitHub, cloud, or API tokens.
- Customer names, domains, addresses, and ticket numbers.
- Public IP addresses tied to a real organization.
- Hostnames or screenshots from unrelated production systems.
- Browser tabs, notifications, or clipboard contents containing personal data.

## Findings template

```markdown
# Observed findings

## Environment

- Hypervisor:
- Host OS:
- Lab network type:
- Lab prefix:
- Forest name:

## Validation result

- Validation date:
- Checks passed:
- Checks failed:
- Corrective actions:

## Deviations from the reference design

Describe any different domain name, IP range, VM size, or hypervisor configuration and explain why it was chosen.

## Security observations

Document isolation controls, overlap checks, secret-handling decisions, and any residual risk.
```

Do not present expected results as observed results. Only record command output and screenshots actually produced by your lab.
