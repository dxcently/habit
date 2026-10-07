# Executable schema cases. Each attribute is one case, evaluated on its own by
# tests/selection/run.sh; negative cases are expected to throw with a message
# the runner greps for, so "clear error" is evidence rather than a claim.
{ lib }:
let
  composition = import ../../lib/composition.nix { inherit lib; };
  registry = import ./registry.nix;

  # A host module that selects what `selects` says and sets nothing else: the
  # cases write the keys under `habit`, and this is the module they are the
  # keys of.
  selecting = selects: { habit = selects; };

  select =
    mod:
    composition.evalSelection {
      inherit registry;
      host = selecting mod;
    };

  # Force every element of a module list, then answer `result`. A wrapped module
  # imports its file when it is forced, so without this a throw hiding in an
  # unforced thunk passes. Only to the head: a module's option declarations
  # carry types that cannot be forced further.
  forceEach = list: result: builtins.foldl' (acc: m: builtins.seq m acc) result list;

  # The whole resolution: selection, inventory, and every element of the module
  # list the host would import.
  resolve =
    mod:
    let
      r = mkModules { host = selecting mod; };
    in
    builtins.deepSeq (builtins.toJSON r.inventory) (
      forceEach r.modules {
        inherit (r) selection modules;
        inv = r.inventory;
      }
    );

  # A module list's identity, element for element, short of the values it holds.
  # `==` is no instrument here: Nix counts two distinct function objects as
  # unequal, so a list carrying a wrapped function never compares equal to a
  # copy of itself. What is left is each element's type, and for an attrset its
  # attribute names.
  fingerprint =
    l:
    map (
      m:
      if builtins.isAttrs m then
        "${builtins.typeOf m}{${builtins.concatStringsSep "," (builtins.attrNames m)}}"
      else
        builtins.typeOf m
    ) l;

  # ── The constructor's two hooks ────────────────────────────────────────────
  # `mkNixosModules` is the platform pass as a function: the same module list
  # and specialArgs `mkNixosHost` hands `nixosSystem`, without a package set in
  # the way. Everything here drives it directly.
  mkModules =
    args:
    composition.mkNixosModules (
      {
        hostName = "fixture";
        inherit registry;
        host = { };
        homeManagerModule = { };
      }
      // args
    );

  # A key under `habit` that the CONSTRUCTOR does not know about, declared the
  # way a capability that needs one supplies it, so the fixture keeps the
  # constructor's vocabulary out of it. A selection module is a module of
  # `habit`, so this option is `habit.tag`.
  declareTag = {
    options.tag = lib.mkOption {
      type = lib.types.str;
      default = "unset";
      description = "A habit key declared outside the constructor.";
    };
  };

  # ── Stub platforms ─────────────────────────────────────────────────────────
  # What the routed halves land in, without NixOS or Home Manager. `marks` is a
  # list option, so a half applied twice shows twice. `systemFixtures` declares
  # only what the fixtures write: a key the platform does not have, such as
  # anything under `home-manager` without its module, is an error as on a real
  # host. `anyKey` lets the system accept every other key too.
  marksOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  # NixOS, nix-darwin and Home Manager all declare `assertions`; the constructor
  # adds to it.
  assertionsOption = lib.mkOption {
    type = lib.types.listOf lib.types.anything;
    default = [ ];
  };

  systemFixtures = {
    options.assertions = assertionsOption;
    options.fixture.marks = marksOption;
    options.fixture.account = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
    };
  };

  anyKey.freeformType = lib.types.lazyAttrsOf lib.types.anything;

  # Home Manager's NixOS module as far as the constructor's wiring touches it:
  # the wiring's options are free, and each user is a submodule that carries
  # `marks` and accepts any other key. Like Home Manager's own, a user's
  # definition is a module, so its `imports` are read as imports.
  homeManagerStub = {
    options.home-manager = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        freeformType = lib.types.lazyAttrsOf lib.types.anything;
        options.users = lib.mkOption {
          default = { };
          type = lib.types.attrsOf (
            lib.types.submoduleWith {
              modules = [
                {
                  freeformType = lib.types.lazyAttrsOf lib.types.anything;
                  options.fixture.marks = marksOption;
                }
              ];
            }
          );
        };
      };
    };
  };

  # The configuration the constructor's module list evaluates to on a stub
  # platform, with the arguments `nixosSystem` would give every module. `args`
  # reach `mkNixosModules` beside the host, which is `host` or else the module
  # that selects `mod`.
  evalAssembled =
    {
      mod ? { },
      host ? selecting mod,
      args ? { },
      platform ? [
        systemFixtures
        anyKey
      ],
    }:
    let
      resolved = mkModules (
        {
          inherit host;
          homeManagerModule = homeManagerStub;
        }
        // args
      );
    in
    (lib.evalModules {
      specialArgs = {
        inherit lib;
      }
      // resolved.specialArgs;
      modules = platform ++ resolved.modules;
    }).config;

  # What NixOS does with `assertions`: a failed one aborts the build, naming
  # each message.
  failedAssertions =
    c:
    let
      failed = lib.filter (a: !a.assertion) c.assertions;
    in
    if failed == [ ] then
      "none"
    else
      throw "Failed assertions:\n${lib.concatMapStrings (a: "- ${a.message}\n") failed}";

  marksOf = c: builtins.concatStringsSep "+" c.fixture.marks;

  # What landed where: the system's marks, then each Home Manager user's.
  assembled =
    mod:
    let
      c = evalAssembled { inherit mod; };
    in
    builtins.concatStringsSep " " (
      [ "sys=${marksOf c}" ]
      ++ lib.mapAttrsToList (n: u: "${n}=${marksOf u}") (c.home-manager.users or { })
    );

  # A user with Home Manager on, whose module is the fixture of that name.
  homeUser =
    name: extra:
    lib.recursiveUpdate {
      definition = ./users + "/${name}.nix";
      home.enable = true;
    } extra;

  dunst = {
    enable = true;
    provider = "dunst";
  };

  # The names one scope selected, each with its provider when it has one.
  enabledIn =
    selected:
    builtins.concatStringsSep "," (
      lib.mapAttrsToList (n: s: if s.provider == null then n else "${n}/${s.provider}") (
        lib.filterAttrs (_: s: s.enable) selected
      )
    );

  # What one scope selected, as `habit.selected` reports it.
  selectedBy = c: enabledIn c.habit.selected;

  # The fixture registry plus the entries only the module-system cases use.
  registryWithModules = registry // {
    catalogue = registry.catalogue // {
      declares = ./dendrites/declares;
      homeThrows = ./dendrites/homeThrows;
      laneRecord = ./dendrites/laneRecord;
      nestedHome = ./dendrites/nestedHome;
    };
  };

  selectionCases = rec {
    # ── A disabled implementation is never imported ────────────────────────────
    # landmine/default.nix throws on import; selecting everything around it and
    # forcing the resolution must still succeed.
    disabledIsInert = (resolve { dendrites.systemonly.enable = true; }).inv.host;

    # The complement: selecting the landmine reaches it, so the case above
    # passes because nothing imported it and not because the resolution never
    # looks.
    selectedModuleIsImported = (resolve { dendrites.landmine.enable = true; }).inv.host;

    # An enabled dendrite imports only the provider that was chosen. The
    # landmine provider sits beside dunst in the same registry.
    unselectedProviderIsInert =
      (resolve {
        dendrites.notifications = {
          enable = true;
          provider = "dunst";
        };
      }).inv.dendrites.notifications.provider;

    # aggregations/landmine/default.nix throws on import. It is discovered — it is
    # a directory with a default.nix right beside the ones that are selected — so
    # resolving a host that does not select it proves discovery never reads a body.
    unselectedAggregationIsInert =
      (resolve {
        aggregation.workstation.enable = true;
        users.alice = {
          definition = ./users/alice.nix;
          home.enable = true;
          aggregation.desk.enable = true;
        };
      }).inv.host;

    # ── Provider diagnostics ───────────────────────────────────────────────────
    missingProvider = (resolve { dendrites.notifications.enable = true; }).inv.host;

    unknownProvider =
      (resolve {
        dendrites.notifications = {
          enable = true;
          provider = "nope";
        };
      }).inv.host;

    providerOnSingleImpl =
      (resolve {
        dendrites.systemonly = {
          enable = true;
          provider = "mako";
        };
      }).inv.host;

    # ── Halves ─────────────────────────────────────────────────────────────────
    # A module has no lane to be missing. Selected where it has nothing to say,
    # it applies an empty half: homeonly has no system half, so the host gets
    # nothing and its users get the home half.
    homeOnlyModuleSelectedForTheSystemAppliesAnEmptySystemHalf = assembled {
      dendrites.homeonly.enable = true;
      users.alice = homeUser "alice" { };
    };

    # The same for a home-only provider.
    homeOnlyProviderSelectedForTheSystemAppliesAnEmptySystemHalf = assembled {
      dendrites.notifications = {
        enable = true;
        provider = "mako";
      };
      users.alice = homeUser "alice" { };
    };

    # systemonly has no home half: a user selecting it applies the system half
    # and their own home gets nothing.
    systemOnlyModuleSelectedByAUserAppliesItsSystemHalf = assembled {
      users.alice = homeUser "alice" { dendrites.systemonly.enable = true; };
    };

    # ── Unknown names ──────────────────────────────────────────────────────────
    unknownDendrite = (resolve { dendrites.frobnicate.enable = true; }).inv.host;

    unknownAggregation = (resolve { aggregation.frobnicate.enable = true; }).inv.host;

    # A provider selector an aggregation does not own is a missing option, not a
    # silently ignored line. This is the case the gate step's freeform attrset
    # defers rather than swallows.
    unknownAggregationSelector =
      (resolve {
        aggregation.workstation = {
          enable = true;
          compositor.provider = "hyprland";
        };
      }).inv.host;

    # ── The host interface: provider choices under the aggregation ─────────────
    # The host names its implementation on the aggregation that owns the
    # dendrite, and needs no top-level dendrites override to do it.
    aggregationProviderSelector =
      (resolve {
        aggregation.workstation = {
          enable = true;
          notifications.provider = "herald";
        };
      }).inv.dendrites.notifications.provider;

    # A top-level selection still outranks the aggregation's mkDefault.
    hostOverridesAggregationProvider =
      (resolve {
        aggregation.workstation.enable = true;
        dendrites.notifications.provider = "herald";
      }).inv.dendrites.notifications.provider;

    # Two aggregations naming the same dendrite on the same terms merge into ONE
    # selection — they do not instantiate it twice: one wrapped module for
    # notifications and one for systemonly, and no more.
    aggregationsMergeOnSharedDendrite =
      let
        r = resolve {
          aggregation.workstation.enable = true;
          aggregation.annex.enable = true;
        };
      in
      r.inv.dendrites.notifications.provider == "dunst"
      && builtins.length (builtins.filter (m: lib.hasPrefix "habit:" (m.key or "")) r.modules) == 2;

    # Two aggregations choosing different providers for it collide; import order
    # never picks a winner.
    conflictingAggregationProviders =
      (resolve {
        aggregation.workstation.enable = true;
        aggregation.kiosk.enable = true;
      }).inv.dendrites.notifications.provider;

    # false beats a default true.
    hostDisablesAggregationMember =
      (resolve {
        aggregation.workstation.enable = true;
        dendrites.systemonly.enable = false;
      }).inv.dendrites
        ? systemonly;

    # A preference that rides along reaches the platform pass as a module, not as
    # something the selection pass evaluated.
    aggregationRidesPlatformSettings =
      (evalAssembled { mod.aggregation.workstation.enable = true; }).networking.hostName;

    # ── A backend-specific aggregation is not dragged in by its sibling ───────
    # An aggregation can hold the members only one provider of a provider-bearing
    # dendrite can run, precisely so a host that answers that provider
    # with something else never evaluates them. `backend`'s only member throws
    # on import: selecting the provider-bearing aggregation beside it, and
    # forcing the whole resolution, must still succeed.
    backendAggregationIsInert =
      (resolve {
        users.alice = {
          definition = ./users/alice.nix;
          home.enable = true;
          aggregation.desk = {
            enable = true;
            notifications.provider = "dunst";
          };
        };
      }).inv.host;

    # The landmine is real: selecting the backend aggregation does reach it.
    backendAggregationIsReachable =
      (resolve {
        users.alice = {
          definition = ./users/alice.nix;
          home.enable = true;
          aggregation.backend.enable = true;
        };
      }).inv.host;

    # ── Scopes ─────────────────────────────────────────────────────────────────
    # The same aggregation one scope down: a user turning it on gets its home
    # membership, and the system scope stays empty — the two halves of one
    # aggregation reach different evaluators.
    userAggregationContributesHomeMembers =
      let
        r = resolve {
          users.alice = {
            definition = ./users/alice.nix;
            home.enable = true;
            aggregation.desk.enable = true;
          };
        };
      in
      r.inv.users.alice.dendrites.notifications.provider == "dunst" && r.inv.dendrites == { };

    # A user outranks the aggregation that attached them, independently of the
    # system selection.
    userOverridesAggregationProvider =
      (resolve {
        users.alice = {
          definition = ./users/alice.nix;
          home.enable = true;
          aggregation.desk = {
            enable = true;
            notifications.provider = "mako";
          };
        };
      }).inv.users.alice.dendrites.notifications.provider;

    # ── Users ──────────────────────────────────────────────────────────────────
    # Selection is per scope: two users, same capability, different providers,
    # each recorded in its own scope. Only the selection and its inventory are
    # read; building the module list refuses this (below).
    twoUserScopes =
      let
        inv = composition.inventoryOf {
          hostName = "fixture";
          selection = select {
            users.alice = homeUser "alice" {
              dendrites.notifications = {
                enable = true;
                provider = "mako";
              };
            };
            users.bob = homeUser "bob" { dendrites.notifications = dunst; };
          };
        };
      in
      "${inv.users.alice.dendrites.notifications.provider}+${inv.users.bob.dendrites.notifications.provider}";

    # ── Routing ────────────────────────────────────────────────────────────────
    # The host's selection reaches every user with Home Manager on, a user's
    # reaches that user, and a user reached both ways receives it once. The
    # system half applies once however many selected it. Each result is what
    # landed in the system and in each user's home, as `fixture.marks`.
    hostSelectionReachesEveryHomeUser = assembled {
      dendrites.notifications = dunst;
      users.alice = homeUser "alice" { };
      users.bob = homeUser "bob" { };
    };

    userSelectionReachesThatUserOnly = assembled {
      users.alice = homeUser "alice" { dendrites.notifications = dunst; };
      users.bob = homeUser "bob" { };
    };

    hostAndUserSelectionApplyOnce = assembled {
      dendrites.notifications = dunst;
      users.alice = homeUser "alice" { dendrites.notifications = dunst; };
      users.bob = homeUser "bob" { };
    };

    usersSelectingOneModuleApplyItsSystemHalfOnce = assembled {
      users.alice = homeUser "alice" { dendrites.notifications = dunst; };
      users.bob = homeUser "bob" { dendrites.notifications = dunst; };
    };

    # One system takes one implementation of a capability: selectors that name
    # different providers are refused, naming every claimant, whether the
    # disagreement is the host's with a user or one user's with another.
    hostAndUserWithDifferentProvidersAreRefused = assembled {
      dendrites.notifications = dunst;
      users.alice = homeUser "alice" {
        dendrites.notifications = {
          enable = true;
          provider = "herald";
        };
      };
    };

    usersWithDifferentProvidersAreRefused = assembled {
      users.alice = homeUser "alice" {
        dendrites.notifications = {
          enable = true;
          provider = "mako";
        };
      };
      users.bob = homeUser "bob" { dendrites.notifications = dunst; };
    };

    # A user without Home Manager has no home to receive it.
    hostSelectionSkipsAUserWithoutHomeManager = assembled {
      dendrites.notifications = dunst;
      users.alice = homeUser "alice" { };
      users.bob = homeUser "bob" { home.enable = false; };
    };

    # With no Home Manager user nothing is emitted under `home-manager`: the
    # platform declares no such option, so an emitted empty set would fail.
    hostSelectionWithoutHomeUsersEmitsNoHomeHalf = marksOf (evalAssembled {
      platform = [ systemFixtures ];
      mod.dendrites.notifications = dunst;
    });

    # A user's module is the account on the system and, in `habit.home`, that
    # user's home alone. bob has Home Manager off, so his module has no home.
    userModuleRoutesItsHalves =
      let
        c = evalAssembled {
          mod.users = {
            alice = homeUser "alice" { };
            bob = homeUser "bob" { home.enable = false; };
          };
        };
        accounts = builtins.concatStringsSep "," (lib.attrNames c.fixture.account);
        homes = builtins.concatStringsSep "," (lib.attrNames c.home-manager.users);
        aliceHome = lib.boolToString c.home-manager.users.alice.fixture.home.alice;
      in
      "accounts=${accounts} alice=${aliceHome} homes=${homes}";

    # ── Home Manager absence ───────────────────────────────────────────────────
    # A home selection with the user's home switched off is a configuration
    # error.
    homeSelectionWithoutHomeManager = mkHost {
      users.alice = {
        definition = ./users/alice.nix;
        home.enable = false;
        dendrites.notifications = {
          enable = true;
          provider = "mako";
        };
      };
    };

    # A host whose users all have it off resolves cleanly and wires no Home
    # Manager at all: on a platform without its module the evaluation succeeds,
    # and the account is still created.
    homeManagerAbsent =
      let
        c = evalAssembled {
          platform = [ systemFixtures ];
          mod = {
            dendrites.systemonly.enable = true;
            users.bob = homeUser "bob" { home.enable = false; };
          };
        };
      in
      "${marksOf c} accounts=${builtins.concatStringsSep "," (lib.attrNames c.fixture.account)}";

    # ── habit.selected ─────────────────────────────────────────────────────────
    # Every evaluation sees its own scope: the system eval what the host
    # selected, each user's home what that user selected, and unselected names
    # are there as disabled.
    selectedFollowsEachScope =
      let
        c = evalAssembled {
          mod = {
            dendrites.systemonly.enable = true;
            dendrites.notifications = dunst;
            users.alice = homeUser "alice" { dendrites.homeonly.enable = true; };
            users.bob = homeUser "bob" { };
          };
        };
        home = n: selectedBy c.home-manager.users.${n};
      in
      "sys=${selectedBy c} alice=${home "alice"} bob=${home "bob"}";

    selectedHoldsEveryCatalogueName =
      let
        c = evalAssembled { mod.dendrites.systemonly.enable = true; };
      in
      "${builtins.concatStringsSep "," (lib.attrNames c.habit.selected)} landmine=${lib.boolToString c.habit.selected.landmine.enable}";

    # The constructor writes it, nobody else: a second definition is refused in
    # the system eval and in a user's home alike.
    selectedIsReadOnlyInTheSystemEval =
      (evalAssembled {
        args.extraModules = [ { habit.selected.systemonly.enable = true; } ];
      }).habit.selected.systemonly.enable;

    selectedIsReadOnlyInAUsersHome =
      (evalAssembled {
        mod.users.alice = homeUser "alice" {
          home.config = {
            habit.selected.systemonly.enable = true;
          };
        };
      }).home-manager.users.alice.habit.selected.systemonly.enable;

    # ── What is not a module ───────────────────────────────────────────────────
    # A lane record is a module whose keys are options that do not exist, so it
    # fails where the system half is evaluated, in the module system's words.
    laneRecordIsRefusedWhereTheSystemHalfIsEvaluated =
      (evalAssembled {
        platform = [ systemFixtures ];
        args.registry = registryWithModules;
        mod.dendrites.laneRecord.enable = true;
      }).fixture.marks;

    # A module that declares options, selected once, is an ordinary module.
    selectedModuleDeclaresItsOptions =
      let
        c = evalAssembled {
          platform = [ systemFixtures ];
          args.registry = registryWithModules;
          mod.dendrites.declares.enable = true;
        };
      in
      lib.boolToString c.fixture.declared;

    # The home half is a thunk nobody reads while no user receives it: a host
    # without Home Manager users never forces `habit.home`, and a user who does
    # receive it reads it.
    hostWithoutHomeUsersNeverForcesAHomeHalf =
      let
        c = evalAssembled {
          platform = [ systemFixtures ];
          args.registry = registryWithModules;
          mod.dendrites.homeThrows.enable = true;
        };
      in
      marksOf c;

    homeHalfIsReadWhenAUserReceivesIt =
      let
        c = evalAssembled {
          args.registry = registryWithModules;
          mod = {
            dendrites.homeThrows.enable = true;
            users.alice = homeUser "alice" { };
          };
        };
      in
      marksOf c.home-manager.users.alice;

    # The same file selected AND imported as itself is two copies of one
    # module: the wrapper's key is not the file's, so nothing de-duplicates them
    # and the module system refuses the second declaration.
    selectedAndImportedTwiceIsRefused =
      let
        c = evalAssembled {
          platform = [ systemFixtures ];
          args = {
            registry = registryWithModules;
            extraModules = [ ./dendrites/declares ];
          };
          mod.dendrites.declares.enable = true;
        };
      in
      lib.boolToString c.fixture.declared;

    # ── Host assembly ──────────────────────────────────────────────────────────
    # Only the strandedHome guard is forced here; nixosSystem is not evaluated,
    # so these cases stay cheap.
    mkHost =
      mod:
      (composition.mkNixosHost {
        nixpkgs = {
          lib.nixosSystem = _: throw "nixosSystem must not be evaluated by a selection case";
        };
        hostName = "fixture";
        inherit registry;
        host = selecting mod;
        homeManagerModule = { };
      }).inventory.host;
  };

  # ── Override records ───────────────────────────────────────────────────────
  # A record is a capability-scoped fix. These cases drive `overridesFor`
  # directly: it is the whole of the matching contract, and the platform pass
  # only spends what it hands back.
  #
  # The fixture set is written out rather than discovered, so a case can swap in
  # one deliberately broken record; a consumer's registry is plain data.
  overrides = {
    allhosts = ./overrides/allhosts.nix;
    confined = ./overrides/confined.nix;
    homely = ./overrides/homely.nix;
    tripwire = ./overrides/tripwire.nix;
  };

  bad = name: { ${name} = ./badrecords + "/${name}.nix"; };

  # The constructor's catalogue with one deliberately broken aggregation body
  # beside the fixture ones; `enabled` is the aggregation the host selects.
  badBody =
    {
      name,
      enabled ? name,
    }:
    (composition.evalSelection {
      registry = registry // {
        aggregations = registry.aggregations // {
          ${name} = ./badaggregations + "/${name}";
        };
      };
      host = selecting { aggregation.${enabled}.enable = true; };
    }).aggregation.${enabled}.enable;

  # The constructor's registry plus one record that matches a selected target,
  # for the case that witnesses WHERE the hook's modules land: the record's
  # `system` module and the hook's module define the same list option, and a
  # list option's definitions merge in module-list order, so the merged order
  # is the position.
  registryWithOverrides = registry // {
    overrides = {
      allhosts = ./overrides/allhosts.nix;
    };
  };

  applyOverrides =
    {
      mod,
      host ? "alpha",
      records ? overrides,
    }:
    composition.overridesFor {
      inherit (registry) catalogue;
      overrides = records;
      knownHosts = [
        "alpha"
        "beta"
      ];
      hostName = host;
      selection = select mod;
    };

  matchedOn = args: builtins.concatStringsSep "," (applyOverrides args).matched;

  systemPair = {
    dendrites.systemonly.enable = true;
    dendrites.notifications = {
      enable = true;
      provider = "dunst";
    };
  };

  alicePicksNotifications = {
    users.alice = {
      definition = ./users/alice.nix;
      home.enable = true;
      dendrites.notifications = {
        enable = true;
        provider = "mako";
      };
    };
  };
in
selectionCases
// rec {
  # An aggregation body is checked when it is read, and it is read only when
  # selected: the same broken bodies, unselected, are never looked at.
  aggregationMisspeltHalf = badBody { name = "misspeltHalf"; };
  aggregationSystemKey = badBody { name = "systemKey"; };
  aggregationHomeKey = badBody { name = "homeKey"; };
  aggregationListHalf = badBody { name = "listHalf"; };
  aggregationFunctionBody = badBody { name = "functionBody"; };
  unselectedBadBodyIsInert = badBody {
    name = "misspeltHalf";
    enabled = "workstation";
  };

  # A record with no `hosts` reaches every host that selected a target — and
  # nothing else: `confined` is beta-only, `homely` and `tripwire` target
  # capabilities this host did not select.
  overrideMatchesSelectedTarget = matchedOn {
    mod = {
      dendrites.systemonly.enable = true;
    };
  };

  # Same selection, the other host. The host filter admits beta, so `confined`
  # applies there; `homely` joins because notifications is selected too. The
  # order is record name, never the filesystem.
  overrideHostFilterAdmits = matchedOn {
    mod = systemPair;
    host = "beta";
  };

  # Alpha selects exactly the same things and still does not see `confined`.
  overrideHostFilterExcludes = matchedOn { mod = systemPair; };

  # `confined` names two dendrites and beta selected both. A record applies
  # once, not once per target it hit.
  overrideAppliesOnceForTwoTargets = builtins.length (
    builtins.filter (n: n == "confined")
      (applyOverrides {
        mod = systemPair;
        host = "beta";
      }).matched
  );

  # A record never selects anything. Targeting a capability nobody chose is a
  # record that does not apply, not a capability that gets installed.
  overrideNeedsSelectedTarget = builtins.length (applyOverrides { mod = { }; }).matched;

  # A matched `system` module reaches the platform pass as a module — the
  # constructor hands it over, it does not evaluate it.
  overrideSystemModuleApplies =
    let
      r = applyOverrides {
        mod = {
          dendrites.systemonly.enable = true;
        };
      };
    in
    builtins.head ((builtins.head r.system) { }).fixture.marks;

  # A capability only a USER selected still matches, and the overlay it carries
  # is host-scoped: `useGlobalPkgs` means a home configuration draws from the
  # host package set, so there is no separate home one to patch.
  overrideHomeOnlySelectionIsHostScoped =
    let
      r = applyOverrides { mod = alicePicksNotifications; };
    in
    ((builtins.head r.overlays) { } { }).fixture-homely;

  # A record's `home` module rides exactly the users its target's home half
  # reaches: when a user selected the target, that user alone. bob is on the
  # same matched host and gets nothing.
  overrideHomeModuleReachesOnlyTheSelectingUser =
    let
      r = applyOverrides {
        mod = {
          users = alicePicksNotifications.users // {
            bob = {
              definition = ./users/bob.nix;
              home.enable = true;
            };
          };
        };
      };
    in
    "${toString (builtins.length r.home.alice)}:${toString (builtins.length r.home.bob)}";

  # When the host selected the target its home half goes to every user, and so
  # does the record's `home` module.
  overrideHomeModuleReachesEveryUserForAHostSelectedTarget =
    let
      r = applyOverrides {
        mod = {
          dendrites.notifications = {
            enable = true;
            provider = "dunst";
          };
          users.alice = {
            definition = ./users/alice.nix;
            home.enable = true;
          };
          users.bob = {
            definition = ./users/bob.nix;
            home.enable = true;
          };
        };
      };
    in
    "${toString (builtins.length r.home.alice)}:${toString (builtins.length r.home.bob)}";

  # Where that module lands: in the home of the user who selected the target,
  # and in nobody else's.
  overrideHomeModuleLandsInTheSelectingUsersHome =
    let
      c = evalAssembled {
        args.registry = registry // {
          overrides.homely = ./overrides/homely.nix;
        };
        mod.users = {
          alice = homeUser "alice" { };
          bob = homeUser "bob" { dendrites.notifications = dunst; };
        };
      };
      homeOf =
        n: builtins.concatStringsSep "+" (lib.sort lib.lessThan c.home-manager.users.${n}.fixture.marks);
    in
    "bob=${homeOf "bob"} alice=${homeOf "alice"}";

  # Position inside one user's home, later reading first: the module a selected
  # dendrite contributes, then the matched record's `home` module, then the
  # `module` of the aggregation's home half.
  homeModulesKeepTheirPosition =
    let
      c = evalAssembled {
        args.registry = registry // {
          overrides.homely = ./overrides/homely.nix;
        };
        mod.users.alice = homeUser "alice" { aggregation.homesettings.enable = true; };
      };
    in
    builtins.concatStringsSep "," c.home-manager.users.alice.fixture.marks;

  # tripwire's overlay and system module both throw. Nothing here selects
  # `homeonly`, so forcing the whole result proves an unmatched record's
  # functions are never called — the metadata above them is read on every host,
  # and that is the whole of the boundary.
  overrideUnmatchedBodiesAreInert = builtins.deepSeq (applyOverrides { mod = systemPair; }) true;

  # The complement, so the case above is not passing for the wrong reason: when
  # a user does select `homeonly`, tripwire matches and its overlay really is
  # the throwing one.
  overrideMatchedBodyIsCallable =
    let
      r = applyOverrides {
        mod = {
          users.alice = {
            definition = ./users/alice.nix;
            home.enable = true;
            dendrites.homeonly.enable = true;
          };
        };
      };
    in
    (builtins.head r.overlays) { } { };

  # ── Record schema diagnostics ──────────────────────────────────────────────
  # Validation is not conditional on matching: a typo fails on every host, so a
  # broken record cannot hide on the machines it would not have applied to.
  overrideUnknownField = matchedOn {
    mod = { };
    records = bad "unknownfield";
  };

  overrideNoTarget = matchedOn {
    mod = { };
    records = bad "notarget";
  };

  overrideStrayTarget = matchedOn {
    mod = { };
    records = bad "straytarget";
  };

  overrideStrayHost = matchedOn {
    mod = { };
    records = bad "strayhost";
  };

  overrideCarriesNothing = matchedOn {
    mod = { };
    records = bad "empty";
  };

  # ── The two constructor hooks ─────────────────────────────────────────────
  # A `selectionModules` module is a module of `habit` and joins the scan in
  # BOTH selection steps, so an option it declares is a key the host can set —
  # the constructor never heard of it.
  selectionModuleFieldIsVisible =
    (mkModules {
      host = {
        habit.tag = "sonata";
      };
      selectionModules = [ declareTag ];
    }).selection.tag;

  # The same host module without the hook: not an option, so the host cannot
  # carry the key. This is the complement — the hook is what declares it, and a
  # host is not silently allowed to invent one.
  selectionModuleFieldIsUnknownWithoutIt =
    (mkModules {
      host = {
        habit.tag = "sonata";
      };
    }).selection.tag;

  # The platform evaluation reads the same host module, so it declares the hook's
  # option too: the key the scan read is a key the platform evaluation holds.
  selectionModuleFieldIsDeclaredInThePlatformEvaluation =
    (evalAssembled {
      host = {
        habit.tag = "sonata";
      };
      args.selectionModules = [ declareTag ];
    }).habit.tag;

  # A hook that declares a name habit keeps for itself is refused, naming the
  # hook's file. `dendrites` is declared by the selection schema; `home` is
  # declared nowhere, which is why a name list is checked rather than a clash.
  selectionModuleReservedNameDendrites =
    (mkModules { selectionModules = [ ./hooks/reservedDendrites.nix ]; }).inventory.host;

  selectionModuleReservedNameHome =
    (mkModules { selectionModules = [ ./hooks/reservedHome.nix ]; }).inventory.host;

  # The gate step is what decides which aggregation BODIES the select step
  # imports. A hook module that enables an aggregation is therefore observable
  # as work done in the gate pass only: the body's own MEMBERSHIP is what the
  # resolved inventory shows, and a body the gate pass never selected is never
  # imported, so a hook handed to the select pass alone contributes nothing
  # here. `notifications` and `systemonly` are exactly what
  # `aggregations/workstation` writes into the selection.
  selectionModuleDrivesTheGatePass =
    let
      r = mkModules {
        selectionModules = [
          {
            aggregation.workstation.enable = true;
          }
        ];
      };
    in
    "${builtins.concatStringsSep "," r.inventory.aggregation}:${builtins.concatStringsSep "," (builtins.attrNames r.inventory.dendrites)}";

  # `extraModulesFor` is handed the RESOLVED selection, and what it returns
  # lands in the platform pass — once, for the host that selected the capability
  # it asks about, and not for the one that did not.
  extraModulesForLandsOnlyWhenSelected =
    let
      marker = {
        fixtureMarker = "extraModulesFor";
      };
      wantsSystemonly = sel: lib.optional sel.dendrites.systemonly.enable marker;
      markerCount =
        args:
        builtins.length (
          builtins.filter (m: builtins.isAttrs m && m ? fixtureMarker) (mkModules args).modules
        );
      selected = markerCount {
        host = selecting { dendrites.systemonly.enable = true; };
        extraModulesFor = wantsSystemonly;
      };
      unselected = markerCount {
        host = { };
        extraModulesFor = wantsSystemonly;
      };
    in
    "${toString selected}:${toString unselected}";

  # The hook's argument is the WHOLE resolved selection — `selection.catalogue`
  # included, and a catalogue path is a body the hook can `import` itself. That
  # is deliberate: narrowing it would take the resolved selectors out of a
  # caller's reach. The discipline is the caller's, so it is pinned here: an
  # unselected catalogue path imported from the hook throws as soon as the
  # module list is forced, which is where a caller notices.
  extraModulesForCanReachTheCatalogue =
    let
      r = mkModules { extraModulesFor = sel: [ (import sel.catalogue.landmine) ]; };
    in
    forceEach r.modules r.inventory.host;

  # Position, not just presence. Every module of the host's own is merged by
  # list order: a selected module sits first, then the hook's modules with
  # `extraModules`, then the matched records' `system` modules, then the host's
  # own module — so a record or the host can still outrank what came before. A
  # list option the selected module, the hook's module and a matched record all
  # define merges in module-list order (a later module's definition reads
  # first), which is what makes the merged order a witness of the position
  # rather than of each being merely present.
  extraModulesForKeepsItsPosition =
    let
      # The platform vocabulary the fixture modules write into. A real caller's
      # own modules declare it; the constructor knows none of it.
      vocabulary = {
        options.assertions = assertionsOption;
        options.fixture.marks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        options.nixpkgs.overlays = lib.mkOption {
          type = lib.types.listOf lib.types.anything;
          default = [ ];
        };
      };
      hook = {
        config.fixture.marks = [ "hook" ];
      };
      r = mkModules {
        registry = registryWithOverrides;
        host = selecting { dendrites.systemonly.enable = true; };
        extraModules = [ vocabulary ];
        extraModulesFor = _: [ hook ];
      };
    in
    builtins.concatStringsSep "," (lib.evalModules { inherit (r) modules; }).config.fixture.marks;

  # `habit.home` is read from a module's own top level only, and is declared
  # nowhere: a nested imported file's is an option that does not exist, naming
  # that file.
  nestedImportedHabitHomeIsRefused = failedAssertions (evalAssembled {
    platform = [ systemFixtures ];
    args.registry = registryWithModules;
    mod.dendrites.nestedHome.enable = true;
  });

  # ── The scan (lib/scan.nix) ─────────────────────────────────────────────────
  # The host is one module the platform evaluates whole. Selection reads only
  # its `habit.*` keys: the fixtures under hosts/ put platform settings that
  # throw, and imports that throw, beside them.
  scanOf =
    host: args:
    composition.evalSelection (
      {
        inherit registry host;
      }
      // args
    );

  scanSummary =
    sel:
    "host=${enabledIn sel.dendrites} groups=${
      builtins.concatStringsSep "," (lib.attrNames (lib.filterAttrs (_: a: a.enable) sel.aggregation))
    } alice=${enabledIn (sel.users.alice or { dendrites = { }; }).dendrites}";

  scanReadsHabitKeysAndNothingElse = scanSummary (scanOf ./hosts/scanned.nix { });

  # importThrows.nix sits in the host's `imports`: the scan reads the host
  # without it, and the platform evaluation, which does follow it, reaches it.
  # Selection keys written at the top level of the host rather than under
  # `habit` select nothing in the scan and are the platform's problem: they are
  # options that do not exist there.
  topLevelSelectionKeysAreRefusedByThePlatformEvaluation =
    (evalAssembled {
      platform = [ systemFixtures ];
      host = {
        dendrites.systemonly.enable = true;
      };
    }).fixture.marks;

  scanDoesNotFollowImports = scanSummary (scanOf ./hosts/importsLandmine.nix { });

  platformEvaluationFollowsImports =
    (evalAssembled { host = ./hosts/importsLandmine.nix; }).habit.selected.systemonly.enable;

  scanDropsImportsGuardedByConfig = scanSummary (scanOf ./hosts/guardedImports.nix { });

  # A head with no named formals gets every argument, so the poison reaches it.
  scanReadsAHostWithAnArgsHead = scanSummary (scanOf ./hosts/argsHead.nix { });

  scanLeavesAGuardWithoutHabitKeysUnforced = scanSummary (scanOf ./hosts/mkMergeGuarded.nix { });

  scanTypoIsAnOptionThatDoesNotExist = scanSummary (scanOf ./hosts/typo.nix { });

  scanTypoSuggestsTheKeyItMeant = scanSummary (scanOf ./hosts/typo.nix { });

  # A `habit` key that depends on platform configuration is refused by name, in
  # every shape the condition can take.
  scanPoisonsAHabitKeyUnderMkIf = scanSummary (scanOf ./hosts/mkIfHabitKey.nix { });
  scanPoisonsAMkIfAroundConfig = scanSummary (scanOf ./hosts/mkIfConfigKey.nix { });
  scanPoisonsAMkIfAroundTheHost = scanSummary (scanOf ./hosts/mkIfTopLevel.nix { });
  scanPoisonsHabitItselfUnderMkIf = scanSummary (scanOf ./hosts/mkIfHabit.nix { });
  scanPoisonsPkgs = scanSummary (scanOf ./hosts/usesPkgs.nix { });

  scanPoisonsOptions = scanSummary (scanOf ./hosts/usesOptions.nix { });
  scanPoisonsOsConfig = scanSummary (scanOf ./hosts/usesOsConfig.nix { });

  # `require` is `imports` by its old name.
  scanDropsRequire = scanSummary (scanOf ./hosts/requires.nix { });

  # An argument nothing provides throws where it is read: used in a `habit` key
  # it is named, used only in `imports` it is never missed.
  scanNamesAMissingHostArgument = scanSummary (scanOf ./hosts/usesMissingArg.nix { });
  scanDropsImportsThatNeedAnArgumentItLacks = scanSummary (scanOf ./hosts/missingArg.nix { });

  # The caller's `specialArgs` reach the host unpoisoned, and its `lib` is the
  # host's `lib`.
  scanTakesTheCallersSpecialArgs = builtins.concatStringsSep "," (
    lib.attrNames
      (scanOf ./hosts/takesSpecialArgs.nix {
        specialArgs.username = "carol";
      }).users
  );

  scanTakesTheCallersLib = builtins.concatStringsSep "," (
    lib.attrNames
      (scanOf ./hosts/readsLib.nix {
        specialArgs.lib = lib // {
          marker = "caller";
        };
      }).users
  );

  # The platform evaluation declares every key the host wrote, and none of them
  # is flagged: each holds what the scan read.
  platformHoldsWhatTheScanRead = failedAssertions (evalAssembled {
    host = ./hosts/setsEveryKey.nix;
  });

  # A key a file the host imports sets is invisible to the scan; the platform
  # evaluation sees it and one assertion names it.
  selectionInAnImportedFileFailsAnAssertion = failedAssertions (evalAssembled {
    host = ./hosts/importsSelection.nix;
  });

  selectionInAnImportedFileIsNamed = failedAssertions (evalAssembled {
    host = ./hosts/importsSelection.nix;
  });

  providerInAnImportedFileFailsAnAssertion = failedAssertions (evalAssembled {
    host = ./hosts/importsProvider.nix;
  });

  userInAnImportedFileFailsAnAssertion = failedAssertions (evalAssembled {
    host = ./hosts/importsUser.nix;
  });

  # Every `habit` key a file other than the host's writes is refused, whatever
  # it holds: a hook's key, a user's `home.config` (a module, with no value to
  # compare), and a key the host selects itself.
  hookKeyInAnImportedFileFailsAnAssertion = failedAssertions (evalAssembled {
    host = ./hosts/importsHookKey.nix;
    args.selectionModules = [ declareTag ];
  });

  homeConfigInAnImportedFileFailsAnAssertion = failedAssertions (evalAssembled {
    host = ./hosts/importsHomeConfig.nix;
  });

  aKeyAnImportedFileRepeatsIsStillRefused = failedAssertions (evalAssembled {
    host = ./hosts/importsWhatTheHostSelects.nix;
  });

  # A module written inline in `imports` has the host's file name, so the value
  # is what catches it.
  inlineImportIsCaughtByItsValue = failedAssertions (evalAssembled {
    host = ./hosts/importsInline.nix;
  });

  # A host that sets its own `_file`, in the module or in what its function
  # returns, is filed under that name; its keys are still the host's.
  hostWithItsOwnFileIsClean = failedAssertions (evalAssembled { host = ./hosts/ownFile.nix; });

  hostFunctionWithItsOwnFileIsClean = failedAssertions (evalAssembled {
    host = ./hosts/ownFileFromAFunction.nix;
  });

  # An imported file with no `habit` key is ordinary platform configuration.
  importedFileWithoutHabitKeysIsQuiet =
    let
      c = evalAssembled { host = ./hosts/importsPlain.nix; };
    in
    "${failedAssertions c}:${marksOf c}";

  hostIsTheLastModule = lib.boolToString (
    lib.hasSuffix "hosts/importsPlain.nix" (
      toString (lib.last (mkModules { host = ./hosts/importsPlain.nix; }).modules)
    )
  );

  # The module list's tail, read through a list option: a later module's
  # definition reads first, so this is the host, the selected aggregation's
  # module, the matched record's `system` module, then the selected capability.
  aggregationModuleSitsJustBeforeTheHost = marksOf (evalAssembled {
    host = ./hosts/marksItself.nix;
    args.registry = registryWithOverrides;
  });

  # With both hooks left out, the module list and the resolved inventory are the
  # ones the constructor assembles without hooks — which is what
  # makes every expectation above a consumer's, unchanged. The module list is
  # compared element for element, not by count: a same-length list with a
  # different member is a change, and the fingerprint says which.
  hookDefaultsChangeNothing =
    let
      mod = {
        dendrites.systemonly.enable = true;
      };
      base = mkModules { host = selecting mod; };
      spelled = mkModules {
        host = selecting mod;
        selectionModules = [ ];
        extraModulesFor = _: [ ];
      };
    in
    "${if fingerprint base.modules == fingerprint spelled.modules then "same" else "differ"}:${
      lib.boolToString (builtins.toJSON base.inventory == builtins.toJSON spelled.inventory)
    }";

  # `mkNixosHost` is `mkNixosModules` plus `nixosSystem` and nothing else: the
  # stub here hands back exactly what it was given, so the two paths can be
  # compared instead of assumed equal — the module list element for element (an
  # equal count would not notice a swap), and the specialArgs as JSON.
  mkHostPassesTheModulesThrough =
    let
      mod = {
        dendrites.systemonly.enable = true;
      };
      viaHost = composition.mkNixosHost {
        nixpkgs = {
          lib.nixosSystem = args: args;
        };
        hostName = "fixture";
        inherit registry;
        host = selecting mod;
        homeManagerModule = { };
      };
      direct = mkModules { host = selecting mod; };
    in
    "${if fingerprint viaHost.system.modules == fingerprint direct.modules then "same" else "differ"}:${
      lib.boolToString (builtins.toJSON viaHost.system.specialArgs == builtins.toJSON direct.specialArgs)
    }";

  # ── The wrapper (lib/lanes.nix) ────────────────────────────────────────────
  # Stub platforms assembled from three pieces: a freeform system that accepts
  # any key, a declared `sys` option, and a `home-manager.users` whose users are
  # freeform submodules, so a home half lands where Home Manager's would. The
  # closed platform has no freeform piece, so an undeclared option is an error
  # as on a real host; the bare one also has no Home Manager.
  lanes = import ../../lib/lanes.nix { inherit lib; };

  freeformPiece.freeformType = lib.types.lazyAttrsOf lib.types.anything;

  sysPiece.options.sys = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
  };

  homePiece.options.home-manager.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule { freeformType = lib.types.lazyAttrsOf lib.types.anything; }
    );
    default = { };
  };

  openPlatform = [
    freeformPiece
    sysPiece
    homePiece
  ];
  closedPlatform = [
    sysPiece
    homePiece
  ];
  platformWithoutHomeManager = [ sysPiece ];

  evalWith =
    platform: modules:
    (lib.evalModules {
      specialArgs = { inherit lib; };
      modules = platform ++ modules;
    }).config;

  wrapped =
    {
      file,
      system ? true,
      homeFor ? [ ],
    }:
    lanes.wrap {
      name = lib.removeSuffix ".nix" file;
      path = ./lanes + "/${file}";
      inherit system homeFor;
    };

  # The module bare, and wrapped with the system half on and no home user:
  # both must yield one system configuration.
  differentialOn =
    platform: file:
    let
      bare = removeAttrs (evalWith platform [ (./lanes + "/${file}") ]) [ "_module" ];
      through = removeAttrs (evalWith platform [ (wrapped { inherit file; }) ]) [ "_module" ];
    in
    if bare == through then
      "same:true:${builtins.concatStringsSep "," (builtins.attrNames bare)}"
    else
      throw "${file}: the wrapped module configures differently from the bare one";

  differential = differentialOn openPlatform;

  showAttrs =
    attrs:
    builtins.concatStringsSep "," (
      lib.mapAttrsToList (n: v: "${n}:${v}") (removeAttrs attrs [ "_module" ])
    );

  landing =
    {
      file,
      platform ? openPlatform,
      system ? true,
      homeFor ? [ "alice" ],
      extra ? [ ],
    }:
    let
      config = evalWith platform ([ (wrapped { inherit file system homeFor; }) ] ++ extra);
    in
    "sys=${showAttrs config.sys} home=${showAttrs (config.home-manager.users.alice or { })}";

  wrapFunctionModule = differential "function.nix";
  wrapAttrsModule = differential "attrs.nix";
  wrapOptionsAndConfigModule = differential "optionsConfig.nix";
  wrapShorthandModule = differential "shorthand.nix";

  # `freeformType` is what lets the closed platform accept `free`, and `meta`
  # rides along: both must reach the module system as the author wrote them.
  wrapFreeformTypeAndMeta = differentialOn closedPlatform "freeformMeta.nix";

  splitPlain = landing { file = "plain.nix"; };
  splitMkIf = landing { file = "mkif.nix"; };
  splitMkIfFalseDropsBothHalves = landing { file = "mkifFalse.nix"; };
  splitMkMerge = landing { file = "mkmerge.nix"; };
  splitMkIfOfMkMerge = landing { file = "ifmerge.nix"; };

  # Two definitions of one freeform value would conflict at equal priority; the
  # override beats the plain one only if both halves carry its priority.
  splitMkOverride = landing {
    file = "override.nix";
    extra = [
      {
        sys.k = "other";
        home-manager.users.alice.k = "other";
      }
    ];
  };

  splitNeverForcesACondition =
    (lanes.split "test" (lib.mkIf (throw "the condition was forced") { habit.home = { }; })).home._type;

  splitHabitUnderMkIf = landing { file = "habitIf.nix"; };
  splitUnknownHabitKey = landing { file = "habitTypo.nix"; };
  splitConfigNotAttrs = landing { file = "nonAttrsConfig.nix"; };
  splitUnsplittableType = landing { file = "orderConfig.nix"; };

  wrapKeyIsTheNameAndFileIsTheAuthors =
    let
      m = wrapped { file = "ownFile.nix"; };
    in
    "${m.key} ${m._file}";

  # `needsArg` takes an argument only `_module.args` supplies: the module
  # system finds it by the wrapper's formals, which are the module's own.
  wrapKeepsTheModulesFormals = landing {
    file = "needsArg.nix";
    extra = [ { _module.args.extraThing = "supplied"; } ];
  };

  # No user receives the home half, so nobody reads it: the throw is never
  # reached. With a user the same module reaches it.
  wrapHomeWithoutAReaderIsNeverRead = landing {
    file = "homeThrows.nix";
    homeFor = [ ];
  };

  wrapHomeWithAReaderIsRead = landing { file = "homeThrows.nix"; };

  # A dropped system half takes the module's `imports` with it: the import
  # throws, so it is untouched when the system is off and reached when on.
  wrapSystemOffAppliesNothingOfTheSystem = landing {
    file = "systemOff.nix";
    system = false;
  };

  wrapSystemOnImports = landing { file = "systemOff.nix"; };

  # A system half that does not apply is not emitted, so an option the platform
  # does not declare is no error there; applied, it is.
  wrapSystemOffEmitsNoSystemOptions = landing {
    file = "nonexistent.nix";
    platform = closedPlatform;
    system = false;
  };

  # The module's `freeformType` is the module system's to fold, so it holds with
  # the system half off: another module's undeclared key is still accepted.
  wrapFreeformTypeSurvivesSystemOff = landing {
    file = "freeformOnly.nix";
    platform = closedPlatform;
    system = false;
    extra = [ { loose.x = "1"; } ];
  };

  wrapSystemOnRefusesAnUndeclaredOption = landing {
    file = "nonexistent.nix";
    platform = closedPlatform;
  };

  # With no home user nothing is emitted under `home-manager`, so a platform
  # without Home Manager evaluates; a home user there is the error it guards.
  wrapNoHomeUserEmitsNothingWithoutHomeManager = landing {
    file = "plain.nix";
    platform = platformWithoutHomeManager;
    homeFor = [ ];
  };

  wrapHomeUserNeedsHomeManager = landing {
    file = "plain.nix";
    platform = platformWithoutHomeManager;
  };

  wrapNotAModule = landing { file = "notModule.nix"; };
  wrapUnsupportedTopLevelAttribute = landing { file = "unsupportedAttr.nix"; };
  splitHabitNotAttrs = landing { file = "habitNotAttrs.nix"; };

  # Selection belongs to the host: a dendrite's own `habit.dendrites` is a key
  # habit does not read, and says so naming the file.
  selectionKeyInsideADendriteIsRefused = landing { file = "habitSelects.nix"; };

  # ── Merging registries (lib/catalogues.nix) ────────────────────────────────
  # Two sources that share no name merge into the union; one that shares a name
  # is refused naming the name and every source that defines it, so neither
  # side wins by position.
  catalogues = import ../../lib/catalogues.nix { inherit lib; };

  sourceA = {
    name = "alpha";
    catalogue = {
      homeonly = ./dendrites/homeonly;
      notifications = ./dendrites/notifications;
    };
    aggregations = {
      desk = ./aggregations/desk;
    };
    overrides = {
      allhosts = ./overrides/allhosts.nix;
    };
  };

  sourceB = {
    name = "beta";
    catalogue = {
      landmine = ./dendrites/landmine;
      systemonly = ./dendrites/systemonly;
    };
    aggregations = {
      kiosk = ./aggregations/kiosk;
    };
    overrides = {
      confined = ./overrides/confined.nix;
    };
  };

  sourceClashing = {
    name = "gamma";
    catalogue = {
      notifications = ./dendrites/notifications;
    };
    aggregations = {
      desk = ./aggregations/desk;
    };
    overrides = {
      allhosts = ./overrides/allhosts.nix;
    };
  };

  mergeRegistriesCatalogueUnion = builtins.concatStringsSep "," (
    lib.attrNames
      (catalogues.mergeRegistries [
        sourceA
        sourceB
      ]).catalogue
  );

  mergeRegistriesKeepsEveryValue =
    let
      merged =
        (catalogues.mergeRegistries [
          sourceA
          sourceB
        ]).catalogue;
    in
    lib.boolToString (merged == sourceA.catalogue // sourceB.catalogue);

  mergeRegistriesIsOrderFree =
    let
      ab = catalogues.mergeRegistries [
        sourceA
        sourceB
      ];
      ba = catalogues.mergeRegistries [
        sourceB
        sourceA
      ];
    in
    lib.boolToString (ab == ba);

  mergeRegistriesCatalogueClash =
    (catalogues.mergeRegistries [
      sourceA
      sourceB
      sourceClashing
    ]).catalogue;

  mergeRegistriesSourceWithoutCatalogue = builtins.concatStringsSep "," (
    lib.attrNames
      (catalogues.mergeRegistries [
        sourceA
        { name = "bare"; }
      ]).catalogue
  );

  mergeRegistriesAggregationsUnion = builtins.concatStringsSep "," (
    lib.attrNames
      (catalogues.mergeRegistries [
        sourceA
        sourceB
      ]).aggregations
  );

  mergeRegistriesAggregationsClash =
    (catalogues.mergeRegistries [
      sourceA
      sourceClashing
    ]).aggregations;

  mergeRegistriesOverridesUnion = builtins.concatStringsSep "," (
    lib.attrNames
      (catalogues.mergeRegistries [
        sourceA
        sourceB
      ]).overrides
  );

  mergeRegistriesOverridesClash =
    (catalogues.mergeRegistries [
      sourceA
      sourceClashing
    ]).overrides;

  # A clash is reported by the field it is in; the fields that do not clash
  # stay readable.
  mergeRegistriesFieldsAreIndependent =
    let
      merged = catalogues.mergeRegistries [
        sourceA
        {
          name = "delta";
          overrides = {
            allhosts = ./overrides/allhosts.nix;
          };
        }
      ];
    in
    "${builtins.concatStringsSep "," (lib.attrNames merged.catalogue)}:${
      lib.boolToString (builtins.tryEval merged.overrides).success
    }";

  # A merged registry is an ordinary registry: selection runs over it and
  # imports only what the host selected.
  mergedRegistrySelects =
    let
      selection = composition.evalSelection {
        registry = catalogues.mergeRegistries [
          sourceA
          sourceB
        ];
        host = selecting {
          dendrites.systemonly.enable = true;
        };
      };
    in
    lib.boolToString (
      lib.hasSuffix "/dendrites/systemonly" (
        composition.inventoryOf {
          hostName = "fixture";
          inherit selection;
        }
      ).dendrites.systemonly.source
    );

  mergeRegistriesThreeOwners =
    (catalogues.mergeRegistries [
      sourceA
      sourceClashing
      {
        name = "delta";
        catalogue = {
          notifications = ./dendrites/notifications;
        };
      }
    ]).catalogue;

  mergeSourceNotAnAttrset =
    (catalogues.mergeRegistries [
      sourceA
      null
    ]).catalogue;

  mergeSourceWithoutName =
    (catalogues.mergeRegistries [
      sourceA
      { catalogue = { }; }
    ]).catalogue;

  mergeSourcesShareAName =
    (catalogues.mergeRegistries [
      sourceA
      (sourceB // { name = "alpha"; })
    ]).catalogue;

  mergeSourceUnknownField =
    (catalogues.mergeRegistries [
      sourceA
      {
        name = "typo";
        aggregation = { };
      }
    ]).catalogue;

  mergeFieldNotAnAttrset =
    (catalogues.mergeRegistries [
      sourceA
      {
        name = "nulled";
        catalogue = null;
      }
    ]).catalogue;

  # The platform pass's `nixpkgs.overlays`, in application order, for a host
  # selecting two dendrites and one override record whose overlay sets the same
  # attribute (`tag`) as the dendrites' and the caller's.
  overlaysApplied =
    let
      tagged = tag: [ (_: _: { inherit tag; }) ];
      r = mkModules {
        registry = {
          catalogue = {
            overlayone = ./dendrites/overlayone;
            overlaytwo = ./dendrites/overlaytwo;
          };
          aggregations = { };
          overrides.overlaytag = ./overrides/overlaytag.nix;
        };
        host = selecting {
          dendrites.overlayone.enable = true;
          dendrites.overlaytwo.enable = true;
        };
        overlays = tagged "caller";
        extraModules = [
          {
            options.assertions = assertionsOption;
            options.nixpkgs.overlays = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
          }
        ];
      };
    in
    (lib.evalModules { inherit (r) modules; }).config.nixpkgs.overlays;

  # The caller's `overlays` land after every selected dendrite's, in the list a
  # platform evaluator concatenates. The dendrites' overlays are thereby applied
  # before the caller's, so a dendrite's `prev` carries none of the caller's
  # packages. A matched override record's overlay lands between the dendrites'
  # and the caller's.
  overlayOrder = builtins.concatStringsSep "," (
    map (
      o:
      let
        tag = (o { } { }).tag;
      in
      if lib.hasPrefix "overlay" tag then "dendrite" else tag
    ) overlaysApplied
  );

  # Applied in that order, the last overlay to set `tag` wins. Restricted to the
  # named tags, this is the winner between those overlays alone.
  winnerAmong =
    tags:
    (lib.foldl' (prev: o: prev // o prev prev) { } (
      lib.filter (o: lib.elem (o { } { }).tag tags) overlaysApplied
    )).tag;

  recordOverlayBeatsDendrite = winnerAmong [
    "overlayone"
    "overlaytwo"
    "record"
  ];

  callerOverlayBeatsRecord = winnerAmong [
    "record"
    "caller"
  ];

  # ── The examples (examples/) ───────────────────────────────────────────────
  # Each example's `default.nix` is called as a consumer's flake would call it:
  # habit's exports unapplied, a `nixpkgs` whose lib carries `nixosSystem`, and
  # Home Manager. The NixOS tree is the one this suite's own `lib` came from,
  # so a real `nixosSystem` evaluates against it and nothing is fetched. Home
  # Manager is not in that tree: `homeManagerStub` stands in for it, so the
  # system half still evaluates for real and each user's home is a submodule
  # that collects what was routed to it.
  habit.lib = {
    composition = import ../../lib/composition.nix;
    catalogues = import ../../lib/catalogues.nix;
  };

  nixosSystem =
    let
      nixpkgsTree = dirOf (dirOf (builtins.unsafeGetAttrPos "evalModules" lib).file);
    in
    args:
    import (nixpkgsTree + "/nixos/lib/eval-config.nix") (
      {
        inherit lib;
        system = null;
      }
      // args
    );

  home-manager.nixosModules.home-manager = homeManagerStub;

  example =
    dir:
    import dir {
      inherit habit home-manager;
      nixpkgs.lib = lib // {
        inherit nixosSystem;
      };
    };

  # The module list an example hands `nixosSystem`, without evaluating NixOS.
  exampleModules =
    dir:
    (import dir {
      inherit habit home-manager;
      nixpkgs.lib = lib // {
        nixosSystem = args: args;
      };
    }).system.modules;

  # The example's own registry and host with one catalogue entry swapped for a
  # body that throws on import, and the module list forced element by element:
  # a wrapped module is a lazy list element, so a length alone would never reach
  # it. `selectionModules` join the scan beside the host.
  workstationWithLandmine =
    selectionModules:
    let
      own = import ../../examples/workstation/registry.nix;
      resolved = composition.mkNixosModules {
        hostName = "desk";
        registry = own // {
          catalogue = own.catalogue // {
            printing = ./dendrites/landmine;
          };
        };
        host = ../../examples/workstation/hosts/desk.nix;
        inherit selectionModules;
        homeManagerModule = home-manager.nixosModules.home-manager;
      };
    in
    forceEach resolved.modules (builtins.length resolved.modules);

  # A single-file dendrite: the inventory names the file that answered.
  exampleMinimalInventory =
    let
      inv = (example ../../examples/minimal).inventory;
    in
    "${inv.host}:${
      builtins.concatStringsSep "," (lib.mapAttrsToList (n: d: "${n}=${baseNameOf d.source}") inv.dendrites)
    }";

  exampleMinimalModules = fingerprint (exampleModules ../../examples/minimal);

  # habit's own entries of a real NixOS evaluation's `assertions`: NixOS's
  # others are not forced, since some need a store to answer.
  habitAssertionsOf =
    system:
    failedAssertions {
      assertions = lib.concatMap (d: d.value) (
        lib.filter (
          d: d.file == toString ../../lib/composition.nix
        ) system.options.assertions.definitionsWithLocations
      );
    };

  exampleMinimalAssertionsHold = habitAssertionsOf (example ../../examples/minimal).system;

  # One fails for a host whose selection sits in a file it imports.
  realSystemFailsTheAssertionForAnImportedSelection =
    habitAssertionsOf
      (composition.mkNixosHost {
        nixpkgs.lib = lib // {
          inherit nixosSystem;
        };
        hostName = "box";
        registry = import ../../examples/minimal/registry.nix;
        host = ./hosts/importsSshOnARealSystem.nix;
        homeManagerModule = home-manager.nixosModules.home-manager;
      }).system;

  exampleMinimalConfig =
    let
      inherit ((example ../../examples/minimal).system) config;
    in
    "${config.networking.hostName} ssh=${lib.boolToString config.services.openssh.enable}";

  exampleWorkstationInventory =
    let
      inv = (example ../../examples/workstation).inventory;
      names = d: builtins.concatStringsSep "," (lib.attrNames d);
    in
    "${names inv.dendrites} alice=${names inv.users.alice.dendrites}/${inv.users.alice.dendrites.notifications.provider}";

  exampleWorkstationModules = fingerprint (exampleModules ../../examples/workstation);

  exampleWorkstationConfig =
    let
      inherit ((example ../../examples/workstation).system) config;
      home = config.home-manager.users.alice;
    in
    builtins.concatStringsSep " " [
      config.networking.hostName
      "bluetooth=${lib.boolToString config.hardware.bluetooth.enable}"
      "printing=${lib.boolToString config.services.printing.enable}"
      "layout=${config.services.xserver.xkb.layout}"
      "alice=${lib.boolToString config.users.users.alice.isNormalUser}"
      "dunst=${lib.boolToString (home.services.dunst.enable or false)}"
      "mako=${lib.boolToString (home.services.mako.enable or false)}"
    ];

  # `habit.selected` in the example's real system evaluation and in alice's
  # home: the host's own scope in one, hers in the other.
  exampleWorkstationSelected =
    let
      inherit ((example ../../examples/workstation).system) config;
    in
    "sys=${selectedBy config} alice=${selectedBy config.home-manager.users.alice}";

  # `printing` is a member of `desktop` and the host switched it off: with its
  # body replaced by one that throws on import, the whole module list is still
  # built. The complement turns it back on above the host's `false`, and the
  # same body is reached.
  exampleWorkstationSwitchedOffIsNeverImported = workstationWithLandmine [ ];

  exampleWorkstationSwitchedBackOnIsImported = workstationWithLandmine [
    { dendrites.printing.enable = lib.mkForce true; }
  ];

  exampleMergedInventory =
    let
      inv = (example ../../examples/merged).inventory;
    in
    "${builtins.concatStringsSep "," inv.aggregation}:${builtins.concatStringsSep "," (lib.attrNames inv.dendrites)}";

  exampleMergedModules = fingerprint (exampleModules ../../examples/merged);

  exampleMergedConfig =
    let
      inherit ((example ../../examples/merged).system) config;
    in
    builtins.concatStringsSep " " [
      "git=${lib.boolToString config.programs.git.enable}"
      "ssh=${lib.boolToString config.services.openssh.enable}"
      "tmux=${lib.boolToString config.programs.tmux.enable}"
    ];

  # The example's two sources and a third that also defines `ssh`.
  exampleMergedClash =
    (catalogues.mergeRegistries [
      (import ../../examples/merged/shared/registry.nix // { name = "shared"; })
      (import ../../examples/merged/personal/registry.nix // { name = "personal"; })
      {
        name = "upstream";
        catalogue.ssh = ../../examples/minimal/dendrites/ssh.nix;
      }
    ]).catalogue;
}
