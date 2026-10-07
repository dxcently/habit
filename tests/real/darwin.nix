# tests/real/darwin.nix — habit against the real nix-darwin, evaluated from
# Linux for aarch64-darwin. Nothing here builds: a darwin builder is not needed to
# evaluate.
{
  habit,
  nixpkgs,
  home-manager,
  nix-darwin,
  enabled,
  ...
}:
let
  inherit (nixpkgs) lib;
  composition = habit.lib.composition { inherit lib; };

  macArgs = extra: {
    registry = import ./registry.nix;
    hostName = "mac";
    system = "aarch64-darwin";
    host = lib.recursiveUpdate (import ./hosts/mac.nix) extra;
    homeManagerModule = home-manager.darwinModules.home-manager;
    specialArgs.greeting = "hello";
  };

  macWith = extra: composition.mkDarwinHost (macArgs extra // { darwin = nix-darwin; });

  # The `_file` of a selected module, which the module system prints when it
  # names the module in an error.
  fileOf =
    name:
    (lib.findFirst (m: (m.key or null) == "habit:${name}") null (
      (composition.mkModules (
        macArgs { habit.dendrites.${name}.enable = true; } // { class = "darwin"; }
      )).modules
    ))._file;

  mac = macWith { };
  inherit (mac.system) config;
  alice = config.home-manager.users.alice;

  evaluates = value: (builtins.tryEval value).success;

  # The same host with and without the dendrite: only the dendrite can be why
  # the second does not evaluate.
  refusing = name: {
    got = {
      without = evaluates config.networking.hostName;
      withIt = evaluates (macWith { habit.dendrites.${name}.enable = true; }).system.config.networking.hostName;
    };
    want = {
      without = true;
      withIt = false;
    };
  };
in
{
  # `tmux` is selected by alice: a user's selection applies the system half
  # too, and nix-darwin leaves `programs.tmux.enable` off unless something sets it.
  darwinAppliesTheSystemHalf = {
    got = {
      userSelected = config.programs.tmux.enable;
      args = config.environment.variables.SYSTEM_ARGS;
    };
    want = {
      userSelected = true;
      args = "aarch64-darwin/mac/hello";
    };
  };

  darwinRoutesTheHomeHalfThroughHomeManager = {
    got = {
      zsh = alice.programs.zsh.enable;
      tmux = alice.programs.tmux.enable;
      variables = {
        inherit (alice.home.sessionVariables) PLAIN HOME_ARGS SELECTED;
      };
    };
    want = {
      zsh = true;
      tmux = true;
      variables = {
        PLAIN = "1";
        HOME_ARGS = "aarch64-darwin/mac/hello";
        SELECTED = "tmux";
      };
    };
  };

  darwinUserModuleSetsTheHomeDirectory = {
    got = {
      user = alice.home.username;
      directory = alice.home.homeDirectory;
    };
    want = {
      user = "alice";
      directory = "/Users/alice";
    };
  };

  darwinSelectedHoldsEachScope = {
    got = {
      system = enabled config.habit.selected;
      alice = enabled alice.habit.selected;
    };
    want = {
      system = [
        "args"
        "plain"
        "selected"
        "zsh"
      ];
      alice = [ "tmux" ];
    };
  };

  darwinToplevelEvaluates = {
    got = lib.hasSuffix ".drv" config.system.build.toplevel.drvPath;
    want = true;
  };

  darwinRefusesALinuxOnlyDirectoryEntry = refusing "bluetooth";

  darwinRefusesALinuxOnlyFileEntry = refusing "udev";

  darwinFilesEachModuleUnderItsFile = {
    got = {
      directoryEntry = lib.hasSuffix "/tests/real/dendrites/bluetooth/default.nix" (fileOf "bluetooth");
      fileEntry = lib.hasSuffix "/tests/real/dendrites/udev.nix" (fileOf "udev");
    };
    want = {
      directoryEntry = true;
      fileEntry = true;
    };
  };
}
