# lib/composition.nix — the constructor.
#
# `mkDefault` sets definition PRIORITY; it cannot decide imports. `mkIf` cannot
# keep an imported module's declarations out of the graph that imported them.
# So selection is resolved FIRST, by ordinary `lib.evalModules` over a tiny
# schema that knows nothing about NixOS, and the platform import list is
# assembled from the result.
#
# Selection itself runs in two steps, because the host interface nests provider
# choices under the aggregation that owns them
# (`aggregation.shell.compositor.provider`) and those option names come from
# the aggregation's own body:
#
#   gate   — every discovered aggregation declares only `enable`; the rest of
#            its attrset is freeform and ignored. This step answers one
#            question: which aggregations does this host, or one of its users,
#            select?
#   select — the selected bodies are imported, declare their real nested
#            options, and write their membership. Nothing else is read.
#
# The evaluation boundary, stated exactly: a registry's `aggregations` attrset
# names directories without importing them; an aggregation body is imported iff
# the host or one of its users selected it; a dendrite implementation and a
# provider file are imported only in the platform pass, iff selection kept them.
#
# A selection option may never read the NixOS/Home Manager configuration it is
# deciding — that is the circular import this split exists to prevent. Platform
# settings therefore ride `deferredModule` options and are evaluated only in
# the evaluation they were written for.
#
# Nothing here knows any vocabulary. Two hooks keep it that way as a host record
# grows fields the constructor has never heard of:
#
#   selectionModules — modules that join the host's own in BOTH selection steps,
#                      so a field they declare is a field the host record can
#                      set and the gate step can read.
#   extraModulesFor  — a function of the resolved selection returning platform
#                      modules, which is how a gate-pass choice becomes an
#                      import without a gate-pass body import. Its argument is
#                      the whole selection, catalogue values included, so a hook
#                      CAN import a body nothing selected: pass selected paths
#                      only. That discipline is the caller's, and
#                      tests/selection pins it.
#
# Both default to nothing (`[ ]` and `_: [ ]`), and with them at their defaults
# the module list is exactly the one assembled without hooks.
{ lib }:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    mkDefault
    types
    ;

  lanes = import ./lanes.nix { inherit lib; };

  # One selection scope: for each catalogued capability, whether it is selected
  # here and which implementation answers. Generated per catalogue name, so an
  # unknown dendrite fails as an option that does not exist, naming the file
  # that asked for it.
  selectionScope =
    catalogue:
    lib.mapAttrs (
      name: _:
      mkOption {
        type = types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Select ${name} in this scope.";
            };
            provider = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Which implementation of ${name} answers in this scope.";
            };
          };
        };
        default = { };
        description = "Selection of the ${name} dendrite.";
      }
    ) catalogue;

  # ── The aggregation body ───────────────────────────────────────────────────
  # Read only for a selected aggregation. A key the constructor does not read
  # (a misspelt `sytem`, a `member`) would contribute nothing and say nothing,
  # so it fails here, naming the aggregation and its file.
  bodyFields = [
    "description"
    "system"
    "home"
  ];
  halfFields = [
    "members"
    "providers"
    "module"
  ];

  readBody =
    name: path:
    let
      body = import path;
      where = "aggregation '${name}' (${
        toString path + lib.optionalString (lib.pathIsDirectory path) "/default.nix"
      })";
      unknown = lib.subtractLists bodyFields (lib.attrNames body);
      unknownIn = scope: lib.subtractLists halfFields (lib.attrNames (halfOf body scope));
      notAttrs = lib.findFirst (scope: body ? ${scope} && !lib.isAttrs body.${scope}) null [
        "system"
        "home"
      ];
      badHalf = lib.findFirst (scope: unknownIn scope != [ ]) null [
        "system"
        "home"
      ];
    in
    if !lib.isAttrs body then
      throw "${where} is a ${builtins.typeOf body}, not an attrset; a body is an attrset taking only ${lib.concatStringsSep ", " bodyFields}"
    else if unknown != [ ] then
      throw "${where} has unknown field(s): ${lib.concatStringsSep ", " unknown}; a body takes only ${lib.concatStringsSep ", " bodyFields}"
    else if notAttrs != null then
      throw "${where} has `${notAttrs}` as a ${builtins.typeOf body.${notAttrs}}, not an attrset; a half is an attrset taking only ${lib.concatStringsSep ", " halfFields}"
    else if badHalf != null then
      throw "${where} has unknown field(s) in `${badHalf}`: ${lib.concatStringsSep ", " (unknownIn badHalf)}; a half takes only ${lib.concatStringsSep ", " halfFields}"
    else
      body;

  # The half of an aggregation body that answers in one scope: the scope names
  # are the body's own attribute names, `system` and `home`.
  halfOf = body: scope: body.${scope} or { };

  # ── The aggregation interface ──────────────────────────────────────────────
  # `enable` for every discovered aggregation, plus — once the body is in hand —
  # one `<dendrite>.provider` for each provider-bearing member that aggregation
  # groups in this scope. Those nested selectors are the host-facing interface;
  # a single-implementation member gets no provider option at all.
  aggregationScope =
    {
      aggregations,
      bodies,
      scope,
    }:
    lib.mapAttrs (
      name: _:
      let
        body = bodies.${name} or null;
        half = if body == null then { } else halfOf body scope;
      in
      mkOption {
        type = types.submodule (
          {
            options = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description =
                  if body == null then
                    "Select the ${name} aggregation in this scope."
                  else
                    body.description or "Select the ${name} aggregation in this scope.";
              };
            }
            // lib.mapAttrs (member: default: {
              provider = mkOption {
                type = types.nullOr types.str;
                inherit default;
                description = "Which implementation of ${member} the ${name} aggregation selects here.";
              };
            }) (half.providers or { });
          }
          # Gate step: the nested selectors are not declared yet, because the
          # body that names them has not been read. Accept and ignore them; the
          # select step is where they are typed.
          // lib.optionalAttrs (bodies == null) {
            freeformType = types.attrsOf types.anything;
          }
        );
        default = { };
        description = "Selection of the ${name} aggregation.";
      }
    ) aggregations;

  # What one selected aggregation contributes to one scope. Membership is
  # `mkDefault`, so an ordinary selection outranks it, two aggregations naming
  # the same member merge, and two that choose different providers for it
  # collide on `dendrites.<name>.provider` rather than letting import order
  # pick a winner. The body carries no gate of its own: it is data, and this is
  # the only place it is wrapped.
  #
  # A half's `module` rides where its scope's own settings are carried: the
  # host's `nixos` for the system half, the user's `home.config` for the home
  # half. `slot` names that place.
  aggregationConfig =
    {
      bodies,
      scope,
      root,
      slot,
    }:
    lib.mapAttrsToList (
      name: body:
      let
        half = halfOf body scope;
        cfg = root.aggregation.${name};
      in
      mkIf cfg.enable (
        {
          dendrites =
            lib.genAttrs (half.members or [ ]) (_: {
              enable = mkDefault true;
            })
            // lib.mapAttrs (member: _: {
              enable = mkDefault true;
              provider = mkDefault cfg.${member}.provider;
            }) (half.providers or { });
        }
        // lib.optionalAttrs (half ? module) (slot half.module)
      )
    ) bodies;

  # The schema one selection step evaluates. `bodies = null` is the gate step.
  mkSchema =
    {
      catalogue,
      aggregations,
      bodies ? null,
    }:
    { config, ... }:
    let
      known = if bodies == null then { } else bodies;
    in
    {
      options = {
        catalogue = mkOption {
          type = types.attrsOf types.path;
          readOnly = true;
          description = "Named path per capability. The constructor reads it back in the platform pass.";
        };

        dendrites = selectionScope catalogue;

        aggregation = aggregationScope {
          inherit aggregations bodies;
          scope = "system";
        };

        users = mkOption {
          default = { };
          description = "Users attached to this host, and what each selects for its own home.";
          type = types.attrsOf (
            types.submoduleWith {
              shorthandOnlyDefinesConfig = true;
              specialArgs = {
                inherit lib;
                scope = "home";
              };
              modules = [
                (
                  { config, ... }:
                  {
                    options = {
                      definition = mkOption {
                        type = types.path;
                        description = "The user's module: its own settings are the account, its `habit.home` is the user's home.";
                      };
                      home.enable = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Give this user a Home Manager configuration. Off means no Home Manager module is imported for them at all.";
                      };
                      home.config = mkOption {
                        type = types.deferredModule;
                        default = { };
                        description = "Extra home settings for this user, evaluated only in their Home Manager configuration.";
                      };
                      dendrites = selectionScope catalogue;
                      aggregation = aggregationScope {
                        inherit aggregations bodies;
                        scope = "home";
                      };
                    };

                    config = mkMerge (aggregationConfig {
                      bodies = known;
                      scope = "home";
                      root = config;
                      slot = module: { home.config = module; };
                    });
                  }
                )
              ];
            }
          );
        };

        nixos = mkOption {
          type = types.deferredModule;
          default = { };
          description = "This host's own NixOS settings and hardware, deferred until selection is complete.";
        };
      };

      config = mkMerge (
        [ { inherit catalogue; } ]
        ++ aggregationConfig {
          bodies = known;
          scope = "system";
          root = config;
          slot = module: { nixos = module; };
        }
      );
    };

  # ── The platform pass ──────────────────────────────────────────────────────
  # Only what selection resolved is imported. A catalogue entry that was never
  # enabled is never `import`ed, and an unselected provider file is never read.

  # Resolve one enabled capability to the file that answers it. A provider set
  # is the one entry read to find out which: it is data naming provider files.
  implOf =
    catalogue: name: provider:
    let
      entry = import catalogue.${name};
      providers = if lib.isAttrs entry then entry.providers or null else null;
      names = lib.concatStringsSep ", " (lib.attrNames providers);
    in
    if providers != null then
      if provider == null then
        throw "dendrite '${name}' is enabled but chose no provider; available providers: ${names}"
      else if !(providers ? ${provider}) then
        throw "dendrite '${name}' has no provider '${provider}'; available providers: ${names}"
      else
        {
          path = providers.${provider};
          label = "${name}/${provider}";
        }
    else if provider != null then
      throw "dendrite '${name}' has a single implementation and takes no provider (got '${provider}')"
    else
      {
        path = catalogue.${name};
        label = name;
      };

  # `habit.selected`: what one scope resolved, a read-only option in the
  # evaluation that scope's modules run in. It is written from selection data
  # and never reads configuration, so it cannot recurse into the selection.
  selectedModule = scope: {
    _file = toString ./composition.nix;
    options.habit.selected = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption { type = types.bool; };
            provider = mkOption { type = types.nullOr types.str; };
          };
        }
      );
      readOnly = true;
      description = "Which capabilities this scope selected, and the provider that answers each.";
    };
    config.habit.selected = lib.mapAttrs (_: d: { inherit (d) enable provider; }) scope;
  };

  enabledNames = selected: lib.attrNames (lib.filterAttrs (_: d: d.enable) selected);

  # ── Override records ───────────────────────────────────────────────────────
  # Some fixes belong to a CAPABILITY rather than to a host: a package whose
  # upstream build broke, a setting every machine that runs the thing wants. A
  # record names the dendrites it is about and, optionally, the hosts it is
  # confined to; the constructor applies it to the hosts that actually selected
  # one of those dendrites. It does not select anything — a record targeting a
  # capability nobody chose simply never applies.
  #
  # The evaluation boundary here is WEAKER than selection's, and this is the
  # honest statement of it: every host imports every record file, because
  # matching is reading. What stays unevaluated is the work — `overlay` and the
  # modules are functions, and an unmatched record's functions are never
  # called. Keep imports and package computation inside them; metadata that
  # computes defeats this, and the tests prove only the function bodies.
  overrideFields = [
    "dendrites"
    "hosts"
    "overlay"
    "system"
    "home"
  ];

  # Read and validate one record. Typos fail here, naming the record and the
  # file, rather than applying to nothing and looking like a working fix.
  readRecord =
    {
      catalogue,
      knownHosts,
      name,
      path,
    }:
    let
      body = import path;
      where = "override record '${name}' (${toString path})";
      unknown = lib.subtractLists overrideFields (lib.attrNames body);
      targets = body.dendrites or [ ];
      strays = lib.filter (d: !(catalogue ? ${d})) targets;
      hosts = body.hosts or null;
      badHosts = lib.filter (h: !(lib.elem h knownHosts)) (if hosts == null then [ ] else hosts);
      carries = lib.filter (f: body ? ${f}) [
        "overlay"
        "system"
        "home"
      ];
    in
    if unknown != [ ] then
      throw "${where} has unknown field(s): ${lib.concatStringsSep ", " unknown}; a record takes only ${lib.concatStringsSep ", " overrideFields}"
    else if !(lib.isList targets) || targets == [ ] then
      throw "${where} names no dendrites; a record must say which capabilities it is about"
    else if strays != [ ] then
      throw "${where} targets unknown dendrite(s): ${lib.concatStringsSep ", " strays}; every target must be a catalogue name"
    else if badHosts != [ ] then
      throw "${where} is confined to unknown host(s): ${lib.concatStringsSep ", " badHosts}"
    else if carries == [ ] then
      throw "${where} carries nothing to apply; give it an overlay, a system module or a home module"
    else
      {
        inherit name hosts;
        dendrites = targets;
      }
      // lib.getAttrs carries body;

  # Which records apply to this host, and to which of its users.
  #
  # A record matches the HOST when its host filter admits this host and any
  # dendrite it targets was selected here — for the system OR by one of its
  # users, because `useGlobalPkgs` means a home configuration draws from the
  # host's own package set and there is no separate home one to fix. Its
  # `overlay` and `system` module then apply once, however many of its targets
  # were selected.
  #
  # A record's `home` module rides exactly the users its target's home half
  # reaches: every user with a home when the host selected the target, the
  # selecting user alone when a user did. The fix then travels with the thing
  # it fixes.
  #
  # Order is record name, so what the list holds does not depend on the
  # filesystem. Overlays then compose the ordinary Nix way, each seeing the
  # previous one as `prev`: later wins on the same attribute, and there is no
  # overlap detection beyond that.
  overridesFor =
    {
      catalogue,
      overrides,
      knownHosts,
      hostName,
      selection,
    }:
    let
      records = lib.mapAttrsToList (
        name: path:
        readRecord {
          inherit
            catalogue
            knownHosts
            name
            path
            ;
        }
      ) overrides;

      homeOf = u: enabledNames u.dendrites;
      hostChoice = enabledNames selection.dendrites;
      here = lib.unique (hostChoice ++ lib.concatMap homeOf (lib.attrValues selection.users));

      admitsHost = r: r.hosts == null || lib.elem hostName r.hosts;
      hits = names: r: lib.any (d: lib.elem d names) r.dendrites;

      forHost = lib.filter (r: admitsHost r && hits here r) records;
      carried = field: rs: lib.concatMap (r: lib.optional (r ? ${field}) r.${field}) rs;
    in
    {
      overlays = carried "overlay" forHost;
      system = carried "system" forHost;
      home = lib.mapAttrs (
        _: u: carried "home" (lib.filter (r: admitsHost r && hits (hostChoice ++ homeOf u) r) records)
      ) selection.users;
      matched = map (r: r.name) forHost;
    };
in
rec {
  inherit
    mkSchema
    implOf
    overridesFor
    ;

  # Gate, then select. Ordinary lib.evalModules both times — no NixOS, no
  # package set, nothing that could depend on the result.
  #
  # An aggregation body is DATA (`members`, `providers`, `nixos`), so it has no
  # way to enable another aggregation: the gate step's answer is the select
  # step's answer, and no recursion machinery is needed to say so.
  evalSelection =
    { registry, modules }:
    let
      inherit (registry) catalogue aggregations;

      eval =
        bodies:
        (lib.evalModules {
          modules = [
            (mkSchema { inherit catalogue aggregations bodies; })
          ]
          ++ modules;
          specialArgs = {
            inherit lib;
            scope = "system";
          };
        }).config;

      gate = eval null;

      chosen = agg: lib.attrNames (lib.filterAttrs (_: a: a.enable) agg);

      selected = lib.unique (
        chosen gate.aggregation ++ lib.concatMap (u: chosen u.aggregation) (lib.attrValues gate.users)
      );
    in
    eval (lib.genAttrs selected (name: readBody name aggregations.${name}));

  # A host's resolved shape: what it selected and from where, for the system and
  # for each user. Generated from the selection, never maintained by hand.
  inventoryOf =
    { hostName, selection }:
    let
      inherit (selection) catalogue;
      describe =
        selected:
        lib.mapAttrs (name: d: {
          inherit (d) provider;
          source = toString catalogue.${name};
        }) (lib.filterAttrs (_: d: d.enable) selected);
      chosen = agg: lib.attrNames (lib.filterAttrs (_: a: a.enable) agg);
    in
    {
      host = hostName;
      aggregation = chosen selection.aggregation;
      dendrites = describe selection.dendrites;
      users = lib.mapAttrs (_: u: {
        definition = toString u.definition;
        home = u.home.enable;
        aggregation = chosen u.aggregation;
        dendrites = describe u.dendrites;
      }) selection.users;
    };

  # The platform pass. Assemble the module list from the resolved selection.
  #
  # `mkNixosHost` calls this and adds nothing to it: the list below is the whole
  # assembly, so a caller that wants the modules for something other than
  # `nixosSystem` — a test node is one — gets this list rather than a second
  # copy of it.
  mkNixosModules =
    {
      hostName,
      knownHosts ? [ hostName ],
      registry,
      hostModules,
      homeManagerModule,
      specialArgs ? { },
      extraModules ? [ ],
      # Package overlays the CALLER provides — the base package set.
      #
      # They do NOT reach a selected module's `prev`: that module is applied
      # BEFORE these, so inside its overlay `prev` carries none of the caller's
      # packages and reading one aborts with a missing attribute. A module
      # therefore builds what it replaces with a FRESH `callPackage`, naming
      # every argument it needs, and never inherits one from this base. A
      # caller's overlay that replaces a name a selected module also replaces
      # must step aside for a name `prev` already carries, or it overrides the
      # module's value.
      overlays ? [ ],
      selectionModules ? [ ],
      extraModulesFor ? (_: [ ]),
      system ? "x86_64-linux",
    }:
    let
      selection = evalSelection {
        inherit registry;
        modules = hostModules ++ selectionModules;
      };
      inherit (selection) catalogue;

      # `extraModules` and the gate-pass hook's answer, in that order: a module
      # from the hook merges and outranks exactly as one the caller passed in.
      extra = extraModules ++ extraModulesFor selection;

      # Capability-scoped fixes, resolved once selection is final and applied
      # before anything evaluates a package set.
      overrides = overridesFor {
        inherit
          catalogue
          knownHosts
          hostName
          selection
          ;
        overrides = registry.overrides or { };
      };

      # Home Manager is wired only where a user actually asked for it; a host
      # with no home user never imports it. Asking for a home dendrite with the
      # user's home switched off is a configuration error, not a quiet no-op.
      args = specialArgs // {
        inherit system;
        host = hostName;
      };

      hmUsers = lib.filterAttrs (_: u: u.home.enable) selection.users;
      strandedHome = lib.concatMap (
        userName:
        let
          u = selection.users.${userName};
          wanted = enabledNames u.dendrites;
        in
        lib.optional (!u.home.enable && wanted != [ ])
          "user '${userName}' has home.enable = false but selects home dendrites: ${lib.concatStringsSep ", " wanted}"
      ) (lib.attrNames selection.users);

      # One wrapped module per selected capability, in catalogue order. The
      # system half applies wherever it was selected, by the host or by a user.
      # The home half goes to every home user when the host selected it and to
      # the selecting user alone when a user did; a user it reaches by both
      # routes gets it once. One system takes one implementation, so every
      # selector must name the same provider: two implementations would both
      # apply their system halves.
      dendriteModules = lib.concatMap (
        name:
        let
          claims =
            lib.optional selection.dendrites.${name}.enable {
              who = "host";
              inherit (selection.dendrites.${name}) provider;
              users = lib.attrNames hmUsers;
            }
            ++ lib.concatMap (
              userName:
              let
                d = selection.users.${userName}.dendrites.${name};
              in
              lib.optional d.enable {
                who = "user '${userName}'";
                inherit (d) provider;
                users = [ userName ];
              }
            ) (lib.attrNames selection.users);
          providers = lib.unique (map (c: c.provider) claims);
          claimants = lib.concatStringsSep "; " (
            map (c: "${c.who}: ${if c.provider == null then "no provider" else c.provider}") claims
          );
          impl = implOf catalogue name (lib.head providers);
        in
        if lib.length providers > 1 then
          throw "dendrite '${name}' is selected with different providers (${claimants}); one system takes one implementation"
        else
          lib.optional (claims != [ ]) (
            lanes.wrap {
              inherit name;
              inherit (impl) path;
              system = true;
              homeFor = lib.unique (lib.concatMap (c: c.users) claims);
            }
          )
      ) (lib.attrNames catalogue);

      # A user's module is an account on the system and the start of their home.
      userModules = lib.mapAttrsToList (
        userName: u:
        lanes.wrap {
          name = "user:${userName}";
          path = u.definition;
          system = true;
          homeFor = lib.optional u.home.enable userName;
        }
      ) selection.users;

      userHome = userName: u: {
        imports = [
          (selectedModule u.dendrites)
        ]
        ++ (overrides.home.${userName} or [ ])
        ++ [ u.home.config ];
      };

      homeWiring = {
        imports = [ homeManagerModule ];
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          backupFileExtension = "backup";
          extraSpecialArgs = args;
          users = lib.mapAttrs userHome hmUsers;
        };
      };

      modules =
        lib.optional (overlays != [ ]) { nixpkgs.overlays = overlays; }
      # A list option's definitions merge in reverse list order, so a module
      # placed here is applied after the selected modules' overlays and before
      # the caller's: a record's fix wins over a selected module's, and the
      # consumer's own overlays keep the last word. The host's own overlays are
      # applied first and lose to all of them unless the host orders them later
      # with `lib.mkAfter`.
      ++ lib.optional (overrides.overlays != [ ]) { nixpkgs.overlays = overrides.overlays; }
      ++ [ (selectedModule selection.dendrites) ]
      ++ userModules
      ++ dendriteModules
      ++ lib.optional (hmUsers != { }) homeWiring
      ++ extra
      # A record outranks everything the constructor imported on its behalf; the
      # host's own module still outranks the record.
      ++ overrides.system
      ++ [ selection.nixos ];
    in
    if strandedHome != [ ] then
      throw "host '${hostName}': ${lib.concatStringsSep "; " strandedHome}"
    else
      {
        inherit
          modules
          selection
          ;
        # What a platform evaluator gets; `mkNixosHost` passes it straight to
        # `nixosSystem`.
        specialArgs = args;
        # The review surface: what this host resolved, derived from selection
        # and never maintained by hand.
        inventory = inventoryOf { inherit hostName selection; } // {
          overrides = overrides.matched;
        };
      };

  mkNixosHost =
    args@{ nixpkgs, ... }:
    let
      resolved = mkNixosModules (removeAttrs args [ "nixpkgs" ]);
    in
    {
      inherit (resolved) selection inventory;
      system = nixpkgs.lib.nixosSystem {
        inherit (resolved) modules specialArgs;
      };
    };
}
