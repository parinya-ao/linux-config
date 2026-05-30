# Layer 4 — NixOS Integration Tests

Full VM-level tests for services, systemd units, and multi-machine scenarios.

---

## Basic single-node test

```nix
# tests/integration/myapp.nix
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "myapp-integration";

  nodes.machine = { config, pkgs, ... }: {
    services.myapp.enable = true;
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("myapp.service")
    machine.wait_for_open_port(8080)
    result = machine.succeed("curl -sf http://localhost:8080/health")
    assert "ok" in result, f"expected 'ok' in health check, got: {result}"
  '';
}
```

---

## Multi-node test

```nix
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "myapp-cluster";

  nodes = {
    server = { config, pkgs, ... }: {
      services.myapp.enable = true;
      networking.firewall.allowedTCPPorts = [ 8080 ];
    };
    client = { config, pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [];
    };
  };

  testScript = ''
    start_all()
    server.wait_for_unit("myapp.service")
    server.wait_for_open_port(8080)

    # Get the server's IP
    server_ip = server.succeed("ip -4 addr show eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+)+'").strip()

    # Test from client
    client.succeed(f"curl -sf http://{server_ip}:8080/health")
  '';
}
```

---

## Test script helpers

```python
# Common OCD Python driver methods

machine.start()                                    # Boot VM
machine.wait_for_unit("foo.service")               # Wait for systemd unit
machine.wait_for_open_port(80)                     # Wait until port is reachable
machine.succeed("cmd")                             # Run cmd, assert exit 0
machine.fail("cmd")                                # Run cmd, assert non-zero exit
machine.screenshot("name")                         # Save screenshot
machine.copy_from("/src", "/dst")                  # Copy file out of VM
machine.send_key("ctrl-alt-delete")                # Send keystroke
```

---

## Wire into flake checks

```nix
perSystem = { pkgs, system, ... }: {
  checks.integration = pkgs.callPackage ./tests/integration/myapp.nix { };
};
```

```bash
# Run (takes a few minutes)
nix build .#checks.x86_64-linux.integration -L

# Interactive debug — boot VM and drop into Python REPL
nix run .#checks.x86_64-linux.integration.driver -- --interactive
```

---

## Speeding up VM tests

| Technique | How |
|-----------|-----|
| Pre-build VM image | Use `--no-build-on-import-paths-missing` or pre-build via CI cache |
| Reduce memory | Set `virtualisation.memorySize = 512;` in node config |
| Only run on nightly CI | Gate with `if: github.event_name == 'schedule'` |
| Disable graphics | `virtualisation.graphics = false;` |
| Use host network | `virtualisation.forwardPorts = [];` + `virtualisation.hostNetwork = true;` |

---

## Common Pitfalls

| Problem | Fix |
|---------|-----|
| VM test hangs forever | Set `meta.timeout = 600;` in the test derivation |
| "Cannot connect to QEMU" | Ensure `/dev/kvm` is accessible; run on Linux |
| Test passes but takes forever | Reduce VM memory; disable unused services |
| `machine.succeed` returns bytes | Decode: `machine.succeed("cmd").decode()` |
| Python error in test script | Use `print()` for debug output, see with `-L` |
