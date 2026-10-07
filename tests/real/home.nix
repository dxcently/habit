# tests/real/home.nix — habit against the real standalone Home Manager.
{
  habit,
  nixpkgs,
  home-manager,
  enabled,
  ...
}:
let
  inherit (nixpkgs) lib;
  composition = habit.lib.composition { inherit lib; };
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  home = composition.mkHome {
    inherit home-manager pkgs;
    registry = import ./registry.nix;
    hostName = "alice";
    host = ./hosts/home.nix;
    overlays = [
      (_final: _prev: {
        habitMark = "caller";
        habitCallerOnly = "caller";
      })
    ];
    specialArgs.greeting = "hello";
  };

  inherit (home.home) config;

  example = (import "${habit}/examples/home" { inherit habit nixpkgs home-manager; }).home;
in
{
  homeDropsTheSystemLaneAndLandsTheHomeHalf = {
    got = {
      plain = config.home.sessionVariables.PLAIN;
      forced = config.home.preferXdgDirectories;
      winner = config.home.language.base;
      args = config.home.sessionVariables.HOME_ARGS;
    };
    want = {
      plain = "1";
      forced = true;
      winner = "forced";
      args = "x86_64-linux/alice/hello";
    };
  };

  homeSelectionIsReadByTheHomeHalf = {
    got = config.home.sessionVariables.SELECTED;
    want = "activation,args,forced,plain,selected,zsh";
  };

  homeSelectedIsItsOwnScope = {
    got = enabled config.habit.selected;
    want = [
      "activation"
      "args"
      "forced"
      "plain"
      "selected"
      "zsh"
    ];
  };

  homeFunctionHalfTakesHomeManagersLib = {
    got = config.home.activation.habitFixture.after;
    want = [ "writeBoundary" ];
  };

  homeCallerAndRecordOverlaysApply = {
    got = {
      inherit (home.home.pkgs) habitMark habitCallerOnly habitRecordOnly;
    };
    want = {
      habitMark = "caller";
      habitCallerOnly = "caller";
      habitRecordOnly = "record";
    };
  };

  homeActivationPackageEvaluates = {
    got = lib.hasSuffix ".drv" home.home.activationPackage.drvPath;
    want = true;
  };

  exampleHomeEvaluates = {
    got = {
      ssh = example.config.programs.ssh.enable;
      selected = enabled example.config.habit.selected;
      drv = lib.hasSuffix ".drv" example.activationPackage.drvPath;
    };
    want = {
      ssh = true;
      selected = [ "ssh" ];
      drv = true;
    };
  };
}
