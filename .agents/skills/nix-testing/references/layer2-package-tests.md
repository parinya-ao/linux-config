# Layer 2 — Package Build Tests (stdenv)

Use this layer to verify that a package compiles correctly, that its bundled
test suite passes, and that installed binaries/libraries are functional.

## The two hooks

| Hook | Phase | When it runs | Typical use |
|------|-------|--------------|-------------|
| `checkPhase` | During build, before install | `doCheck = true` | Run bundled unit/integration tests |
| `installCheckPhase` | After install | `doInstallCheck = true` | Smoke-test installed files in `$out` |

Both are **disabled by default**. Enable them explicitly.

## Full annotated derivation template

```nix
# pkgs/mypkg/default.nix
{ stdenv, lib, cmake, gtest, fetchFromGitHub }:

stdenv.mkDerivation (finalAttrs: {
  pname   = "mypkg";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "example";
    repo  = "mypkg";
    rev   = finalAttrs.version;
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cmake gtest ];

  # ── checkPhase — runs the bundled test suite before install ─────────
  # Always set explicitly; some build systems default doCheck to false
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    # ctest discovers test binaries built by cmake
    ctest --output-on-failure -j$NIX_BUILD_CORES
    runHook postCheck
  '';

  # ── installCheckPhase — smoke-tests the installed result ────────────
  # $out is available here; $src is not
  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    # verify the binary exists and exits cleanly
    $out/bin/mypkg --version
    # verify a shared library is loadable
    ${lib.optionalString stdenv.isLinux ''
      ${stdenv.cc.libc}/bin/ldd $out/lib/libmypkg.so | grep -v "not found"
    ''}
    runHook postInstallCheck
  '';

  # ── passthru.tests — external tests attached to the package ─────────
  # Run with: nix build .#mypkg.passthru.tests.<name>
  passthru.tests = {
    # Check that pkg-config module is present and correct
    pkg-config = pkgs.testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };

    # Check that the binary reports the right version string
    version = pkgs.testers.testVersion {
      package = finalAttrs.finalPackage;
    };

    # Arbitrary derivation that exercises the package
    run-binary = pkgs.runCommand "test-mypkg-run"
      { buildInputs = [ finalAttrs.finalPackage ]; }
      ''
        mypkg --help > /dev/null
        mypkg --self-test
        touch $out   # derivation must produce $out
      '';
  };

  meta = {
    description = "My package";
    license     = lib.licenses.mit;
    platforms   = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
```

## pkgs.testers.* helpers (nixpkgs built-ins)

```nix
# Test that the installed version string matches the derivation version
pkgs.testers.testVersion { package = mypkg; }

# Test that pkg-config modules are present and expose correct flags
pkgs.testers.hasPkgConfigModules { package = mypkg; }

# Test that a NixOS module option evaluates without errors
pkgs.testers.testEqualContents {
  assertion = "mymodule option defaults are correct";
  actual = pkgs.writeText "actual" (builtins.toJSON myModule.config.option);
  expected = pkgs.writeText "expected" (builtins.toJSON { value = 42; });
}
```

## Running package tests manually

```bash
# Build the package (runs checkPhase automatically if doCheck = true)
nix build .#mypkg

# Build and run a specific passthru test
nix build .#mypkg.passthru.tests.run-binary -L

# Run all passthru tests
nix build .#mypkg.passthru.tests.{pkg-config,version,run-binary}

# Force-run checkPhase inside a develop shell (for iteration)
nix develop -c bash -c 'eval "$checkPhase"'
```

## Language-specific checkPhase patterns

### Go
```nix
checkPhase = ''
  runHook preCheck
  go test ./... -v
  runHook postCheck
'';
```

### Python (pytest)
```nix
nativeBuildInputs = [ python3Packages.pytest ];
checkPhase = ''
  runHook preCheck
  pytest tests/ -v
  runHook postCheck
'';
```

### Rust (cargo)
```nix
# Use rustPlatform.buildRustPackage — it handles checkPhase automatically
# when cargoTestFlags is set:
cargoTestFlags = [ "--workspace" "--all-features" ];
```

### Node.js (npm test)
```nix
checkPhase = ''
  runHook preCheck
  npm test
  runHook postCheck
'';
```

## Pitfalls

- **Never reference `$src` in `installCheckPhase`** — the source tree is gone
  by then. Only `$out` is available.
- **`runHook preCheck` / `runHook postCheck` are mandatory.** They allow
  overlays and other customizations to hook into the phase.
- **`ctest` needs `cmake --build . --target test`** for some projects — check
  the project's README.
- **Network access is disabled in the build sandbox.** Tests that phone home
  will fail; mock or skip them.
