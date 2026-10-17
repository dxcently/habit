# tests/real/nixos.nix — habit against the real NixOS and Home Manager modules.
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

  desk = composition.mkNixosHost {
    inherit nixpkgs;
    registry = import ./registry.nix;
    hostName = "desk";
    host = ./hosts/desk.nix;
    homeManagerModule = home-manager.nixosModules.home-manager;
    specialArgs.greeting = "hello";
  };

  house = composition.mkNixosHost {
    inherit nixpkgs;
    registry = import ./registry.nix;
    hostName = "house";
    host = ./hosts/house.nix;
    homeManagerModule = home-manager.nixosModules.home-manager;
  };

  valued = composition.mkNixosHost {
    inherit nixpkgs;
    registry = import ./valueRegistry.nix;
    hostName = "valued";
    host = ./hosts/valued.nix;
  };

  providerSet = composition.mkNixosHost {
    inherit nixpkgs;
    registry = import ./providerRegistry.nix;
    hostName = "providerSet";
    host = ./hosts/providerSet.nix;
  };

  inherit (desk.system) config;
  alice = config.home-manager.users.alice;
  bob = config.home-manager.users.bob;

in
{
  nixosHostSelectionReachesEveryUser = {
    got = {
      system = config.programs.zsh.enable;
      alice = alice.programs.zsh.enable;
      bob = bob.programs.zsh.enable;
    };
    want = {
      system = true;
      alice = true;
      bob = true;
    };
  };

  nixosUserSelectionReachesThatUserOnly = {
    got = {
      system = config.programs.tmux.enable;
      alice = alice.programs.tmux.enable;
      bob = bob.programs.tmux.enable;
    };
    want = {
      system = true;
      alice = true;
      bob = false;
    };
  };

  nixosHomeOnlySelectionAppliesNoSystemHalf = {
    got = {
      system = config.programs.git.enable;
      alice = alice.programs.git.enable;
      bob = bob.programs.git.enable;
    };
    want = {
      system = false;
      alice = false;
      bob = true;
    };
  };

  nixosPlainAndOverriddenHomeHalvesBothReachTheUser =
    let
      read = user: {
        plain = user.home.sessionVariables.PLAIN;
        forced = user.home.preferXdgDirectories;
        winner = user.home.language.base;
      };
    in
    {
      got = {
        alice = read alice;
        bob = read bob;
      };
      want =
        let
          both = {
            plain = "1";
            forced = true;
            winner = "forced";
          };
        in
        {
          alice = both;
          bob = both;
        };
    };

  nixosHomeHalvesReadTheBuildersArgumentsAndTheirOwnSelection = {
    got = {
      alice = {
        inherit (alice.home.sessionVariables) HOME_ARGS SELECTED;
      };
      bob = {
        inherit (bob.home.sessionVariables) HOME_ARGS SELECTED;
      };
    };
    want = {
      alice = {
        HOME_ARGS = "x86_64-linux/desk/hello";
        SELECTED = "tmux";
      };
      bob = {
        HOME_ARGS = "x86_64-linux/desk/hello";
        SELECTED = "git";
      };
    };
  };

  nixosFalseConditionOverAnUndeclaredHomeOptionDefinesNothing = {
    got = {
      alice = alice ? fixtureUndeclared;
      bob = bob ? fixtureUndeclared;
    };
    want = {
      alice = false;
      bob = false;
    };
  };

  nixosTrueConditionAroundAHomeHalfApplies = {
    got = {
      alice = alice.home.sessionVariables.GATED;
      bob = bob.home.sessionVariables.GATED;
    };
    want = {
      alice = "on";
      bob = "on";
    };
  };

  nixosFunctionHomeHalfTakesHomeManagersLib = {
    got = alice.home.activation.habitFixture.after;
    want = [ "writeBoundary" ];
  };

  nixosSelectedHoldsEachScope = {
    got = {
      system = enabled config.habit.selected;
      alice = enabled alice.habit.selected;
      bob = enabled bob.habit.selected;
    };
    want = {
      system = [
        "activation"
        "args"
        "forced"
        "gated"
        "plain"
        "selected"
        "zsh"
      ];
      alice = [ "tmux" ];
      bob = [ "git" ];
    };
  };

  nixosSystemHalfTakesTheBuildersArguments = {
    got = config.environment.variables.SYSTEM_ARGS;
    want = "x86_64-linux/desk/hello";
  };

  nixosHostGroupHomeHalfReachesEveryUserButAnOptOut = {
    got = {
      alice = house.system.config.home-manager.users.alice.programs.git.enable;
      bob = house.system.config.home-manager.users.bob.programs.git.enable;
    };
    want = {
      alice = true;
      bob = false;
    };
  };

  nixosToplevelEvaluates = {
    got = lib.hasSuffix ".drv" config.system.build.toplevel.drvPath;
    want = true;
  };

  nixosValueEntrySelectedIsAppliedAndUnselectedIsNot = {
    got = {
      tmux = valued.system.config.programs.tmux.enable;
      htop = valued.system.config.programs.htop.enable;
    };
    want = {
      tmux = true;
      htop = false;
    };
  };

  nixosProviderValueChosenIsAppliedAndUnchosenIsNot = {
    got = {
      tmux = providerSet.system.config.programs.tmux.enable;
      zsh = providerSet.system.config.programs.zsh.enable;
    };
    want = {
      tmux = true;
      zsh = false;
    };
  };
}
