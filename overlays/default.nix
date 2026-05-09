{
  # This overlay can be used to add custom packages, override existing ones,
  # or apply patches/custom compiler flags.
  final: prev:
  {
    # Example: Override a package version or apply a patch
    # my-package = prev.my-package.overrideAttrs (old: {
    #   ...
    # });

    # Example: Pin a specific version
    # pinned-package = prev.callPackage ./pkgs/pinned-package.nix { };
  }
}
