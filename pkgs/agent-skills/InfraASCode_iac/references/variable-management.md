# Variable Management — Detailed Reference

## Full Variable Precedence (Low → High)

| Priority     | Source                                | Notes                          |
| ------------ | ------------------------------------- | ------------------------------ |
| 1 (lowest)   | Role defaults                         | `roles/x/defaults/main.yml`    |
| 2            | Inventory group_vars `all`            |                                |
| 3            | Inventory group_vars (specific group) |                                |
| 4            | Inventory host_vars                   |                                |
| 5            | Inventory file vars                   |                                |
| 6            | Play `vars:`                          | Inline in playbook             |
| 7            | Play `vars_files:`                    | External files                 |
| 8            | Role vars                             | `roles/x/vars/main.yml`        |
| 9            | Block vars                            | `block: vars:`                 |
| 10           | Task vars                             | `vars:` in a task              |
| 11           | `include_vars`                        | Dynamic var loading            |
| 12           | `set_fact` / `register`               | Runtime computed               |
| 13           | Role params                           | `roles: { role: x, var: val }` |
| 14           | Include params                        | `include_role vars:`           |
| 15 (highest) | `extra_vars` (`-e`)                   | CLI override                   |

> **Key insight**: `role vars/` (priority 8) beats `group_vars` (3-4). So put user-configurable vars in `defaults/`, not `vars/`.

## Common Patterns

### Pattern 1: Environment Differentiation

```yaml
# group_vars/all/vars.yml — shared defaults
app_log_level: info
app_replicas: 2

# group_vars/all/vault.yml — encrypted
vault_app_secret_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          ...

# inventories/production/group_vars/all/vars.yml — production overrides
app_log_level: warning
app_replicas: 5
```

### Pattern 2: OS-Specific Variables

```yaml
# tasks/main.yml
- name: Load OS-specific variables
  ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - files:
        - "{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml"
        - "{{ ansible_distribution }}.yml"
        - "{{ ansible_os_family }}.yml"
        - "default.yml"
      paths: "{{ role_path }}/vars"
  tags: always
```

```yaml
# vars/RedHat.yml
nginx_packages: [nginx]
nginx_conf_dir: /etc/nginx

# vars/Debian.yml
nginx_packages: [nginx, nginx-extras]
nginx_conf_dir: /etc/nginx
```

### Pattern 3: Computed/Derived Variables

```yaml
# Use set_fact for derived values
- name: Build application URL
  ansible.builtin.set_fact:
    app_url: "{{ 'https' if nginx_tls_enabled else 'http' }}://{{ ansible_fqdn }}:{{ nginx_port }}"
  tags: always
```

### Pattern 4: Vault Variable Indirection

```yaml
# group_vars/webservers/vars.yml (plaintext, greppable)
db_host: "{{ vault_db_host }}"
db_password: "{{ vault_db_password }}"
api_token: "{{ vault_api_token }}"

# group_vars/webservers/vault.yml (encrypted, never grep here)
vault_db_host: db01.internal
vault_db_password: "s3cr3t!"
vault_api_token: "tok_abcd1234"
```

## Traps & Gotchas

### Trap 1: `vars/main.yml` is NOT for defaults

```yaml
# ❌ WRONG — vars/main.yml overrides group_vars; users can't customize
# vars/main.yml
nginx_port: 80

# ✅ CORRECT — use defaults/main.yml for user-tunable vars
# defaults/main.yml
nginx_port: 80
```

### Trap 2: Unquoted Jinja2 expressions

```yaml
# ❌ YAML parser error — unquoted { is invalid YAML
dest: {{ nginx_conf_dir }}/nginx.conf

# ✅ Always quote Jinja2 expressions
dest: "{{ nginx_conf_dir }}/nginx.conf"
```

### Trap 3: Boolean confusion

```yaml
# ❌ Ambiguous — YAML interprets 'yes'/'no'/'on'/'off' as booleans too
nginx_tls_enabled: yes

# ✅ Explicit Python booleans — ansible-lint enforces this
nginx_tls_enabled: true
```

### Trap 4: Magic variables you can always use

```yaml
inventory_hostname       # FQDN as defined in inventory
ansible_host             # Connection IP/hostname
ansible_fqdn             # System's actual FQDN
ansible_distribution     # e.g., Ubuntu, RedHat
ansible_os_family        # e.g., Debian, RedHat
ansible_user             # Current remote user
ansible_become           # Whether privilege escalation is active
hostvars[other_host]     # Access another host's variables
groups['webservers']     # List of hosts in a group
group_names              # List of groups current host belongs to
```

## Lookup Plugins for Dynamic Values

```yaml
# Read from environment variable (with fallback)
api_endpoint: "{{ lookup('env', 'API_ENDPOINT') | default('http://localhost:8080') }}"

# Read from a local file
ssh_public_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"

# Read from HashiCorp Vault (requires community.hashi_vault)
db_password: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=secret/db password=db_pass') }}"

# Read from AWS SSM Parameter Store (requires amazon.aws)
secret_key: "{{ lookup('amazon.aws.aws_ssm', '/prod/app/secret_key') }}"
```
