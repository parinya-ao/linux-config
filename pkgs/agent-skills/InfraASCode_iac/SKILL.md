---
name: ansible-iac
description: >
  Expert guide for writing production-grade Ansible Infrastructure as Code (IaC). Use this skill
  whenever a user asks about Ansible project structure, ansible-creator, Collections, Roles, Playbooks,
  variable management, inventory design, Ansible Vault, testing with Molecule, ansible-lint, Execution
  Environments (EE), or CI/CD pipelines for Ansible. Also trigger for questions like "how do I organize
  my Ansible project?", "is my Ansible code idempotent?", "how do I test Ansible roles?", "should I use
  a role or a collection?", or any request to scaffold, review, refactor, or troubleshoot Ansible code.
  Covers the full ADT (Ansible Development Tools) ecosystem: ansible-creator, ansible-lint, molecule,
  ansible-builder, and ansible-navigator.
---

# Ansible IaC Best Practice Skill

This skill guides you through building, organizing, and maintaining production-grade Ansible projects.
It covers the full lifecycle: scaffolding → authoring → linting → testing → packaging → CI/CD.

## Quick Decision Tree

```
Need to automate infrastructure?
├── One-off or simple task → Playbook only (plays + tasks directly)
├── Reusable, shareable unit → Role (inside a collection)
└── Distributable to team/Galaxy → Collection (contains roles + plugins + docs)
```

Use **ansible-creator** to scaffold all of the above — never create folder structures by hand.

---

## Phase 1: Scaffold the Project

### Install Tooling (ADT)

```bash
pip install ansible-dev-tools   # installs everything: creator, lint, builder, navigator, molecule
```

### Create a Collection (recommended default for IaC teams)

```bash
ansible-creator init collection <namespace>.<collection_name> --init-path ./
# Example:
ansible-creator init collection acme.infra --init-path ./collections
```

### Create a Standalone Role (if not inside a collection)

```bash
ansible-creator init role <role_name> --init-path ./roles
```

### Resulting Collection Structure

```
acme/infra/
├── galaxy.yml              # Metadata: name, version, description, dependencies
├── README.md
├── CHANGELOG.rst
├── roles/
│   └── webserver/
│       ├── defaults/main.yml    # Default variables (lowest precedence)
│       ├── vars/main.yml        # Internal role variables (high precedence)
│       ├── tasks/main.yml       # Entry point for tasks
│       ├── tasks/install.yml    # Split tasks into logical files
│       ├── handlers/main.yml    # Handlers (e.g., restart nginx)
│       ├── templates/           # Jinja2 templates (.j2)
│       ├── files/               # Static files
│       ├── meta/main.yml        # Role dependencies + Galaxy metadata
│       └── molecule/            # Molecule test scenarios
├── plugins/
│   ├── modules/             # Custom modules
│   ├── filter/              # Custom Jinja2 filters
│   └── inventory/           # Dynamic inventory plugins
├── playbooks/               # Top-level playbooks
├── docs/
└── tests/
```

> **Read `references/collection-structure.md`** for detailed file-by-file guidance.

---

## Phase 2: Author Tasks and Roles

### Idempotency First (Most Important Principle)

Every task must be safe to run multiple times with the same result.

```yaml
# ❌ NOT idempotent — runs command every time
- name: Install nginx
  command: apt-get install -y nginx

# ✅ Idempotent — uses proper module
- name: Install nginx
  ansible.builtin.package:
    name: nginx
    state: present
```

**Always use FQCN (Fully Qualified Collection Name):**

```yaml
# ❌ Short form — ambiguous in collections
- copy:
    src: foo.conf
    dest: /etc/app/foo.conf

# ✅ FQCN — explicit and safe
- ansible.builtin.copy:
    src: foo.conf
    dest: /etc/app/foo.conf
```

### Task Structure Best Practices

```yaml
# tasks/install.yml
---
- name: Install {{ app_name }} packages # Descriptive name with variable
  ansible.builtin.package:
    name: "{{ app_packages }}" # Use variables, not hardcoded values
    state: present
  become: true # Elevate only where needed
  tags:
    - install
    - "{{ app_name }}"

- name: Ensure {{ app_name }} config directory exists
  ansible.builtin.file:
    path: "{{ app_config_dir }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0750" # Quoted octal mode (required)
  tags:
    - configure
```

### Handlers — React to Changes Only

```yaml
# handlers/main.yml
---
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
  listen: "restart web server" # Use listen for decoupling

# In task that notifies:
- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: "restart web server"
```

---

## Phase 3: Variable Management

**Variable precedence** (higher = wins): `extra_vars > role vars > set_fact > task vars > block vars > play vars > host_vars > group_vars > role defaults > inventory vars`

### File layout

```
inventory/
├── production/
│   ├── hosts.yml           # Inventory hosts
│   ├── group_vars/
│   │   ├── all.yml         # Applies to everything
│   │   ├── webservers.yml  # Group-specific
│   │   └── webservers/     # Split into multiple files (for large groups)
│   │       ├── vars.yml
│   │       └── vault.yml   # Encrypted sensitive vars
│   └── host_vars/
│       └── web01.example.com.yml
└── staging/
    ├── hosts.yml
    └── group_vars/
```

### Naming Conventions

```yaml
# Prefix role variables with role name to avoid collisions
# ❌ Generic — will collide
port: 8080
user: appuser

# ✅ Namespaced — safe
nginx_port: 8080
nginx_user: www-data
```

> **Read `references/variable-management.md`** for vault, lookup patterns, and precedence traps.

---

## Phase 4: Secrets with Ansible Vault

```bash
# Encrypt a file
ansible-vault encrypt inventory/production/group_vars/all/vault.yml

# Edit in place
ansible-vault edit inventory/production/group_vars/all/vault.yml

# Use vault password file (for CI/CD)
ansible-vault encrypt --vault-password-file .vault_pass secret.yml
```

### Vault Variable Convention

```yaml
# group_vars/all/vars.yml (plaintext) — reference the vault var
db_password: "{{ vault_db_password }}"

# group_vars/all/vault.yml (encrypted) — define it here
vault_db_password: "supersecret"
```

This pattern lets you grep variable names in plaintext while keeping secrets encrypted.

---

## Phase 5: Lint Before You Test

```bash
# Run from collection root
ansible-lint

# With explicit config
ansible-lint -c .ansible-lint
```

### Minimal `.ansible-lint` config

```yaml
# .ansible-lint
profile: production # strict ruleset
exclude_paths:
  - .cache/
  - molecule/
warn_list:
  - experimental
```

Common lint fixes to know:

- `no-free-form`: Use `module: key: val` not `module: arg1 arg2`
- `yaml[truthy]`: Use `true`/`false` not `yes`/`no`
- `fqcn`: Add full collection prefix
- `name[casing]`: Start task names with capital letter

---

## Phase 6: Test with Molecule

Molecule runs your role/collection inside Docker (or VMs) to verify it actually works.

```bash
# Install driver
pip install molecule molecule-plugins[docker]

# Run the full test scenario
molecule test

# Faster dev loop
molecule converge       # Apply the role
molecule verify         # Run tests (testinfra / ansible assertions)
molecule destroy        # Cleanup
```

### Minimal Molecule scenario (`molecule/default/molecule.yml`)

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

### Verify tasks (`molecule/default/verify.yml`)

```yaml
---
- name: Verify
  hosts: all
  tasks:
    - name: Nginx is running
      ansible.builtin.service_facts:

    - name: Assert nginx is active
      ansible.builtin.assert:
        that:
          - "'nginx' in services"
          - "services['nginx'].state == 'running'"
```

> **Read `references/testing-patterns.md`** for multi-scenario molecule, testinfra, and CI integration.

---

## Phase 7: Package with ansible-builder (Execution Environments)

Execution Environments (EE) are container images that bundle Ansible + collections + dependencies. Required for AWX/AAP and recommended for reproducible runs.

```yaml
# execution-environment.yml
---
version: 3
images:
  base_image:
    name: ghcr.io/ansible/community-ansible-de-base:latest
dependencies:
  galaxy:
    collections:
      - name: ansible.posix
      - name: community.general
  python:
    - boto3
    - netaddr
  system:
    - openssh-clients [platform:rpm]
```

```bash
ansible-builder build -t my-ee:1.0.0 -v 3
```

---

## Phase 8: CI/CD Pipeline

### GitHub Actions example

```yaml
# .github/workflows/ci.yml
name: Ansible CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install ansible-dev-tools
      - run: ansible-lint

  molecule:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install ansible-dev-tools molecule molecule-plugins[docker]
      - run: molecule test
        env:
          ANSIBLE_VAULT_PASSWORD: ${{ secrets.VAULT_PASSWORD }}
```

---

## Common Anti-Patterns to Avoid

| Anti-pattern                          | Problem                    | Fix                                                      |
| ------------------------------------- | -------------------------- | -------------------------------------------------------- |
| `command:` / `shell:` for installs    | Not idempotent             | Use `package:`, `pip:`, etc.                             |
| Hardcoded IPs in tasks                | Not portable               | Use inventory + variables                                |
| `ignore_errors: true` everywhere      | Hides real failures        | Use `failed_when:` conditionally                         |
| `vars/main.yml` for user-tunable vars | Can't be overridden easily | Put user vars in `defaults/main.yml`                     |
| Monolithic `tasks/main.yml`           | Hard to maintain           | Split into `install.yml`, `configure.yml`, `service.yml` |
| No `meta/main.yml` dependencies       | Role ordering issues       | Declare role deps explicitly                             |
| Secrets in plaintext                  | Security risk              | Use Ansible Vault                                        |

---

## Output Format for Ansible Code Reviews

When reviewing existing Ansible code, structure output as:

```
## Ansible Code Review: <role/playbook name>

### ✅ Good Practices Found
- ...

### ⚠️ Issues to Fix (with snippets)
1. [RULE] Description — before/after code

### 📁 Suggested Structure Changes
- ...

### 🧪 Recommended Test Coverage
- ...
```

When generating new Ansible code, always:

1. Use FQCN for all modules
2. Namespace variables with role/component name
3. Add `tags:` to every task
4. Quote all Jinja2 expressions: `"{{ var }}"`
5. Include handlers for service restarts
6. Add a molecule scenario if creating a role
