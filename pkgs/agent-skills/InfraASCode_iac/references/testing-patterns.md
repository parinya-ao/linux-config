# Testing Patterns — Molecule, ansible-lint, and CI

## Molecule Scenarios

A role can have **multiple scenarios** for different test cases:

```
roles/webserver/molecule/
├── default/           # Standard happy path
│   ├── molecule.yml
│   ├── converge.yml
│   ├── verify.yml
│   └── prepare.yml    # Pre-tasks (e.g., install test deps)
├── tls/               # Test with TLS enabled
│   ├── molecule.yml   # Override vars for TLS
│   └── ...
└── idempotency/       # Confirm second run makes no changes
```

Run a specific scenario:

```bash
molecule test -s tls
```

## Full molecule.yml for Multi-Platform Testing

```yaml
---
dependency:
  name: galaxy
  options:
    ignore-certs: true
driver:
  name: docker
platforms:
  - name: ubuntu22
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
  - name: rhel9
    image: geerlingguy/docker-rockylinux9-ansible:latest
    pre_build_image: true
    privileged: true
provisioner:
  name: ansible
  playbooks:
    prepare: prepare.yml
    converge: converge.yml
    verify: verify.yml
  inventory:
    group_vars:
      all:
        nginx_port: 8080 # Override for test
verifier:
  name: ansible
lint: |
  set -e
  ansible-lint
```

## converge.yml — Apply the Role

```yaml
---
- name: Converge
  hosts: all
  become: true
  vars:
    nginx_tls_enabled: false
  roles:
    - role: acme.infra.webserver
```

## verify.yml — Assert Desired State

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Check if nginx config exists
      ansible.builtin.stat:
        path: /etc/nginx/nginx.conf
      register: nginx_conf

    - name: Assert nginx config exists
      ansible.builtin.assert:
        that:
          - nginx_conf.stat.exists
          - nginx_conf.stat.mode == '0644'
        fail_msg: "nginx.conf missing or wrong permissions"

    - name: Check nginx service
      ansible.builtin.service_facts:

    - name: Assert nginx is running and enabled
      ansible.builtin.assert:
        that:
          - "'nginx' in services"
          - "services['nginx'].state == 'running'"
          - "services['nginx'].status == 'enabled'"

    - name: Check nginx port is listening
      ansible.builtin.wait_for:
        port: 80
        timeout: 5
        state: started

    - name: Verify nginx returns HTTP 200
      ansible.builtin.uri:
        url: http://localhost:80
        status_code: 200
```

## Testing Idempotency (Critical)

```bash
# Molecule's built-in idempotency check runs converge twice
# and fails if the second run shows any changes
molecule test   # Full sequence including idempotency check

# Manual idempotency test
molecule converge
molecule converge   # Should show "changed=0"
```

If you see `changed=1` on second run, the task is NOT idempotent. Fix the module or add `creates:`/`removes:` guards.

## ansible-lint Deep Config

```yaml
# .ansible-lint
profile: production

offline: false
use_default_rules: true

exclude_paths:
  - .cache/
  - .git/
  - molecule/
  - "**/.tox/"

skip_list:
  # Skip if using legacy roles that can't be changed
  # - no-free-form

warn_list:
  - experimental

mock_modules:
  # Tell lint about modules not installed locally
  - community.general.ufw

mock_roles:
  - geerlingguy.security

loop_var_prefix: "^(__|my_)" # Enforce loop_var naming

# Custom rules directory
rulesdir:
  - .ansible-lint-rules/
```

## CI Integration — GitLab CI Example

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - release

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.pip-cache"

.ansible_base:
  image: python:3.11-slim
  before_script:
    - pip install ansible-dev-tools molecule molecule-plugins[docker] --quiet
  cache:
    paths: [.pip-cache/]

lint:
  extends: .ansible_base
  stage: lint
  script:
    - ansible-lint --format pep8

molecule:ubuntu:
  extends: .ansible_base
  stage: test
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
    ANSIBLE_VAULT_PASSWORD: $VAULT_PASSWORD # from GitLab CI secrets
  script:
    - echo "$ANSIBLE_VAULT_PASSWORD" > .vault_pass
    - molecule test
  artifacts:
    when: always
    reports:
      junit: molecule/default/junit.xml

publish-galaxy:
  stage: release
  script:
    - ansible-galaxy collection build
    - ansible-galaxy collection publish *.tar.gz --token $GALAXY_TOKEN
  only:
    - tags
```

## Testing Playbooks with ansible-playbook --check

```bash
# Dry run — shows what WOULD change
ansible-playbook -i inventories/staging playbooks/webservers.yml --check

# Dry run + show diff for file changes
ansible-playbook -i inventories/staging playbooks/webservers.yml --check --diff

# Run only specific tags
ansible-playbook -i inventories/staging playbooks/webservers.yml --tags configure

# Limit to specific hosts
ansible-playbook -i inventories/staging playbooks/webservers.yml --limit web01.staging.example.com
```

## Pre-commit Hooks for Local Dev

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v24.2.0
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-merge-conflict
```

```bash
pre-commit install   # Run on every git commit
pre-commit run --all-files  # Manual run
```
