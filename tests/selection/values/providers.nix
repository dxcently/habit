# Provider sets written as catalogue values, and file provider sets with module
# values among their targets. A provider set is read only when it is selected,
# and only its chosen target is imported or applied: the targets and attributes
# that throw sit unchosen beside the ones that are chosen.
{
  mixedSet = {
    providers = {
      alpha = ./providers/alpha.nix;
      beta = {
        fixture.marks = [ "beta" ];
        habit.home.fixture.marks = [ "beta" ];
      };
    };
  };

  unchosenThrowing = {
    providers = {
      good = ./providers/alpha.nix;
      landmine = ../dendrites/notifications/landmine.nix;
      thrown = throw "unchosen provider value was read";
    };
  };

  throwingProviders = {
    providers = throw "providers attribute was read";
  };

  chosenThrown = {
    providers = {
      thrown = throw "chosen provider value was read";
    };
  };

  extraKey = {
    providers = {
      alpha = ./providers/alpha.nix;
    };
    config.fixture.marks = [ "extra" ];
  };

  listProviders = {
    providers = [ ./providers/alpha.nix ];
  };

  numberTarget = {
    providers = {
      num = 3;
    };
  };

  nestedSet = {
    providers = {
      inner = {
        providers = {
          alpha = ./providers/alpha.nix;
        };
      };
    };
  };

  badTarget = {
    providers = {
      bad = {
        habit.homee = { };
      };
    };
  };

  providerSet = {
    providers = {
      dunst = ../dendrites/notifications/dunst.nix;
    };
  };

  fileSet = ./providers/fileSet.nix;

  fileExtra = ./providers/fileExtra.nix;
}
