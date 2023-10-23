{
  core-inputs,
  user-inputs,
  snowfall-lib,
  ...
}: let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs callPackageWith;

  user-shells-root = snowfall-lib.fs.get-snowfall-file "shells";
in {
  shell = {
    ## Create flake output packages.
    create-shells = {
      channels,
      alias ? {},
      overrides ? {},
      src ? user-shells-root,
      pkgs ? channels.nixpkgs,
    }: let
      user-shells = snowfall-lib.fs.get-default-nix-files-recursive src;

      create-shell-metadata = shell: let
        extra-inputs =
          pkgs
          // {
            inherit channels;
            lib = snowfall-lib.internal.system-lib;
            inputs = snowfall-lib.flake.without-src user-inputs;
          };
      in {
        name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory shell);
        drv = callPackageWith extra-inputs shell {};
      };

      shells-metadata = builtins.map create-shell-metadata user-shells;
      merge-shells = shells: metadata:
        shells
        // {
          ${metadata.name} = metadata.drv;
        };

      shells-without-aliases = foldl merge-shells {} shells-metadata;
      aliased-shells = mapAttrs (name: value: shells-without-aliases.${value}) alias;
      shells = shells-without-aliases // aliased-shells // overrides;
    in
      filterPackages pkgs.system shells;
  };
}
