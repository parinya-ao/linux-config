# Collection & Role Structure — Detailed Reference

## galaxy.yml — Full Example

```yaml
namespace: acme
name: infra
version: 1.2.0
readme: README.md
authors:
  - Your Name <you@example.com>
description: Infrastructure automation collection for ACME Corp
license:
  - GPL-2.0-or-later
tags:
  - linux
  - networking
  - security
dependencies:
  ansible.posix: ">=1.4.0"
  community.general: ">=7.0.0"
repository: https://github.com/acme/ansible-collection-infra
documentation: https://acme.github.io/ansible-collection-infra
```

## Role Directory — Every Folder's Purpose

### `defaults/main.yml`

- **Lowest precedence** — safely overridden by inventory/playbook vars
- Put ALL user-configurable variables here with sensible defaults
- Document each variable with a comment

```yaml
# defaults/main.yml
---
# Port nginx listens on
nginx_port: 80

# Whether to enable TLS
nginx_tls_enabled: false

# List of packages to install
nginx_packages:
  - nginx
  - nginx-extras
```

### `vars/main.yml`

- **High precedence** — only for internal role constants users should NOT override
- Examples: file paths derived from OS, computed values

```yaml
# vars/main.yml
---
# Internal: set OS-specific paths (populated by tasks/preflight.yml)
_nginx_conf_dir: /etc/nginx
_nginx_service_name: nginx
```

### `tasks/main.yml` — Entry Point Pattern

```yaml
# tasks/main.yml — import sub-task files, never inline all tasks here
---
- name: Include OS-specific variables
  ansible.builtin.include_vars: "{{ ansible_os_family }}.yml"
  tags: always

- name: Run pre-flight checks
  ansible.builtin.import_tasks: preflight.yml
  tags: always

- name: Install nginx
  ansible.builtin.import_tasks: install.yml
  tags: [install, nginx]

- name: Configure nginx
  ansible.builtin.import_tasks: configure.yml
  tags: [configure, nginx]

- name: Manage nginx service
  ansible.builtin.import_tasks: service.yml
  tags: [service, nginx]
```

**`import_tasks` vs `include_tasks`:**

- `import_tasks`: static, processed at parse time — use for most cases, tags propagate
- `include_tasks`: dynamic, evaluated at runtime — use when you need `when:` on the include itself or loop over file names

### `meta/main.yml` — Role Metadata

```yaml
# meta/main.yml
---
galaxy_info:
  role_name: webserver
  author: yourname
  description: Install and configure nginx webserver
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions: [jammy, focal]
    - name: EL
      versions: [8, 9]
  galaxy_tags: [nginx, webserver, linux]

dependencies:
  - role: acme.infra.common # FQCN for collection roles
  - role: geerlingguy.security
    vars:
      security_ssh_port: 2222
```

### `templates/` — Jinja2 Best Practices

```jinja2
{# templates/nginx.conf.j2 #}
{# This file is managed by Ansible. Manual changes will be overwritten. #}
server {
    listen {{ nginx_port }};
    server_name {{ ansible_fqdn }};

    {% if nginx_tls_enabled %}
    listen {{ nginx_tls_port }} ssl;
    ssl_certificate {{ nginx_tls_cert_path }};
    ssl_certificate_key {{ nginx_tls_key_path }};
    {% endif %}

    location / {
        root {{ nginx_webroot }};
        index index.html;
    }
}
```

Key Jinja2 patterns:

- Always add "managed by Ansible" comment at top of templates
- Use `{% if %}` blocks for optional config sections
- Use `{{ ansible_fqdn }}` not hardcoded hostnames
- Use `| default('fallback')` filter for optional variables: `{{ nginx_port | default(80) }}`

## Playbook Organization (Top-Level)

```
playbooks/
├── site.yml            # Master playbook — imports all others
├── webservers.yml      # Target a specific group
├── databases.yml
└── adhoc/
    ├── rotate-certs.yml
    └── patch-emergency.yml
```

```yaml
# playbooks/site.yml
---
- name: Apply common baseline to all hosts
  ansible.builtin.import_playbook: common.yml

- name: Configure webservers
  ansible.builtin.import_playbook: webservers.yml

- name: Configure databases
  ansible.builtin.import_playbook: databases.yml
```

## Inventory Structure — Multi-Environment

```
inventories/
├── production/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all/
│       │   ├── vars.yml      # Non-sensitive
│       │   └── vault.yml     # Encrypted with ansible-vault
│       └── webservers/
│           ├── vars.yml
│           └── vault.yml
└── staging/
    ├── hosts.yml
    └── group_vars/
```

```yaml
# inventories/production/hosts.yml
---
all:
  children:
    webservers:
      hosts:
        web01.prod.example.com:
          ansible_host: 10.0.1.10
        web02.prod.example.com:
          ansible_host: 10.0.1.11
    databases:
      hosts:
        db01.prod.example.com:
          ansible_host: 10.0.2.10
```

## ansible.cfg — Project-Level Config

```ini
[defaults]
inventory          = inventories/production
roles_path         = roles:~/.ansible/roles
collections_path   = collections:~/.ansible/collections
remote_user        = ansible
host_key_checking  = True
retry_files_enabled = False
stdout_callback    = yaml
callbacks_enabled  = profile_tasks, timer

[privilege_escalation]
become       = False         # Default off, enable per-task
become_method = sudo

[ssh_connection]
pipelining    = True         # Speed boost — requires requiretty disabled
ssh_args      = -o ControlMaster=auto -o ControlPersist=30m
```
