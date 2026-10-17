# lib/composition.nix — the constructor.
#
# `mkDefault` sets definition PRIORITY; it cannot decide imports. `mkIf` cannot
# keep an imported module's declarations out of the graph that imported them.
# So selection is resolved FIRST, by ordinary `lib.evalModules` over a tiny
# schema that knows nothing about NixOS, and the platform import list is
# assembled from the result.
#
# The host is one module, and the platform evaluates it whole. Selection reads
# only its `habit.*` keys (lib/scan.nix): the platform's own arguments are
# poisoned, its `imports` are not followed and every other key is never forced.
#
# Selection itself runs in two steps, because the host interface nests provider
# choices under the aggregation that owns them
# (`habit.aggregation.shell.compositor.provider`) and those option names come
# from the aggregation's own body:
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
# deciding — that is the circular import this split exists to prevent. The
# platform evaluation declares the same `habit.*` options inert (a key nobody
# wrote is null) and one assertion fails a key the scan could not have seen: one
# set in a file the host imports.
#
# Nothing here knows any consumer's vocabulary. Two hooks keep it that way as a
# host grows fields the constructor has never heard of:
#
#   selectionModules — modules of `habit` itself, joining the scan in BOTH
#                      steps and the platform evaluation, so an option they
#                      declare is `habit.<option>`, a key the host can set and
#                      the gate step can read.
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
  scan = import ./scan.nix { inherit lib; };

  # A flag the host writes. The scan reads it as a bool that is `default` until
  # written; the platform evaluation declares the same key inert, null until
  # written, so a value written in a file the scan never read is told from none.
  flag =
    inert: default: description:
    mkOption (
      {
        inherit description;
      }
      // (
        if inert then
          {
            type = types.nullOr types.bool;
            default = null;
          }
        else
          {
            type = types.bool;
            inherit default;
          }
      )
    );

  # A user's flag: null is no opinion, so an explicit `false` (an opt-out) is
  # told from one never written. The scan and the platform read it the same way.
  optFlag =
    description:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      inherit description;
    };

  # A catalogue entry: a path (a file, or a directory's `default.nix`), or a
  # module value, an attrset or a function. A value is itself the module; a path
  # is imported only when selection reads it. Path-like comes first, so an
  # attrset that coerces to a path (a derivation, a flake input) stays a path.
  isValue = entry: !types.path.check entry && (lib.isAttrs entry || lib.isFunction entry);

  entryType = types.mkOptionType {
    name = "catalogue entry";
    description = "a path, an attrset module or a function module";
    check = entry: types.path.check entry || isValue entry;
  };

  # One selection scope: for each catalogued capability, whether it is selected
  # here and which implementation answers. Generated per catalogue name, so an
  # unknown dendrite fails as an option that does not exist, naming the file
  # that asked for it.
  selectionScope =
    {
      catalogue,
      inert,
      tristate ? false,
    }:
    lib.mapAttrs (
      name: _:
      mkOption {
        type = types.submodule {
          options = {
            enable =
              if tristate then
                optFlag "Select ${name} in this scope. `false` withholds the home half the host sent."
              else
                flag inert false "Select ${name} in this scope.";
            system = flag inert true "Apply the system half of ${name} for this selection. Off asks for its home half alone.";
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
    if !types.path.check path then
      throw "aggregation '${name}' is a ${builtins.typeOf path}, not a path; a body is a file or a directory holding a default.nix"
    else
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
      inert,
      tristate ? false,
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
              enable =
                let
                  description =
                    if body == null then
                      "Select the ${name} aggregation in this scope."
                    else
                      body.description or "Select the ${name} aggregation in this scope.";
                in
                if tristate then optFlag description else flag inert false description;
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
          # select step is where they are typed. The platform evaluation never
          # reads a body and keeps them as written.
          // lib.optionalAttrs (bodies == null) {
            freeformType = types.attrsOf types.anything;
          }
        );
        default = { };
        description = "Selection of the ${name} aggregation.";
      }
    ) aggregations;

  # What one selected aggregation contributes to one scope: its membership.
  # Membership is `mkDefault`, so an ordinary selection outranks it, two
  # aggregations naming the same member merge, and two that choose different
  # providers for it collide on `dendrites.<name>.provider` rather than letting
  # import order pick a winner. The body carries no gate of its own: it is data,
  # and this is the only place it is wrapped. A half's `module` is data too, and
  # the platform pass places it (`aggregationModules`).
  aggregationConfig =
    {
      bodies,
      scope,
      root,
      hostGroups ? [ ],
    }:
    lib.mapAttrsToList (
      name: body:
      let
        half = halfOf body scope;
        cfg = root.aggregation.${name};
      in
      mkIf (groupOn hostGroups name cfg.enable) {
        dendrites =
          lib.genAttrs (half.members or [ ]) (_: {
            enable = mkDefault true;
          })
          // lib.mapAttrs (member: _: {
            enable = mkDefault true;
            provider = mkDefault cfg.${member}.provider;
          }) (half.providers or { });
      }
    ) bodies;

  knownBodies = bodies: if bodies == null then { } else bodies;

  # Whether a group is on in a scope. A user's `enable` is null where nothing was
  # written; there the host's selection of the group reaches the user as the
  # user's own would. An explicit `false` withholds it. The host's groups are
  # `hostGroups` (the gate step's answer), and a host's own `enable` is a bool.
  groupOn = hostGroups: name: enable: enable == true || (enable == null && lib.elem name hostGroups);

  # The keys a host writes under `habit`. `inert` declares the same ones for the
  # platform evaluation, where nothing reads a body and a key nobody wrote is
  # null.
  habitOptions =
    {
      catalogue,
      aggregations,
      bodies,
      inert,
      scope,
      hostGroups ? [ ],
    }:
    {
      dendrites = selectionScope { inherit catalogue inert; };

      aggregation = aggregationScope {
        inherit
          aggregations
          bodies
          inert
          scope
          ;
      };

      users = mkOption {
        default = { };
        description = "Users attached to this host, and what each selects for its own home.";
        type = types.attrsOf (
          types.submoduleWith {
            shorthandOnlyDefinesConfig = true;
            specialArgs = {
              inherit lib hostGroups;
              scope = "home";
            };
            modules = [
              (
                { config, hostGroups, ... }:
                {
                  options = {
                    definition = mkOption (
                      {
                        description = "The user's module: its own settings are the account, its `habit.home` is the user's home.";
                      }
                      // (
                        if inert then
                          {
                            type = types.nullOr types.path;
                            default = null;
                          }
                        else
                          { type = types.path; }
                      )
                    );
                    home.enable = flag inert false "Give this user a Home Manager configuration. Off means no Home Manager module is imported for them at all.";
                    home.config = mkOption {
                      type = types.deferredModule;
                      default = { };
                      description = "Extra home settings for this user, evaluated only in their Home Manager configuration.";
                    };
                    dendrites = selectionScope {
                      inherit catalogue inert;
                      tristate = true;
                    };
                    aggregation = aggregationScope {
                      inherit aggregations bodies inert;
                      scope = "home";
                      tristate = true;
                    };
                  };

                  # The host's groups reach a user only where it has a home.
                  config = mkMerge (aggregationConfig {
                    bodies = knownBodies bodies;
                    scope = "home";
                    root = config;
                    hostGroups = lib.optionals config.home.enable hostGroups;
                  });
                }
              )
            ];
          }
        );
      };
    };

  # `habit` is one submodule, so a key beside the ones it declares
  # (`habit.dendrtes`) is an option that does not exist, naming the host file,
  # and never reaches the freeform sink that swallows the host's platform
  # settings. The hooks' modules are modules of it.
  habitType =
    scope: modules:
    types.submoduleWith {
      shorthandOnlyDefinesConfig = true;
      specialArgs = { inherit lib scope; };
      inherit modules;
    };

  # The schema one selection step evaluates. `bodies = null` is the gate step.
  # Everything the host module sets besides `habit` lands in the freeform sink
  # and is never read.
  mkSchema =
    {
      catalogue,
      aggregations,
      bodies ? null,
      hostGroups ? [ ],
      selectionModules ? [ ],
      scope ? "system",
    }:
    {
      freeformType = types.lazyAttrsOf types.raw;

      options.habit = mkOption {
        type = habitType scope (
          [
            (
              { config, ... }:
              {
                options =
                  habitOptions {
                    inherit
                      catalogue
                      aggregations
                      bodies
                      hostGroups
                      scope
                      ;
                    inert = false;
                  }
                  // {
                    catalogue = mkOption {
                      type = types.attrsOf entryType;
                      readOnly = true;
                      description = "Named entry per capability: a path, or a module value. The constructor reads it back in the platform pass.";
                    };
                  };

                config = mkMerge (
                  [ { inherit catalogue; } ]
                  ++ aggregationConfig {
                    bodies = knownBodies bodies;
                    inherit scope;
                    root = config;
                  }
                );
              }
            )
          ]
          ++ selectionModules
        );
        default = { };
        description = "What this host selects.";
      };
    };

  # ── The platform pass ──────────────────────────────────────────────────────
  # Only what selection resolved is imported. A catalogue entry that was never
  # enabled is never `import`ed, and an unchosen provider target is never read.

  # Resolve one enabled capability to the module that answers it: a path, or a
  # module value, with the name that labels a value in errors (`valueName`) and
  # the inventory's `source`. A provider set is the one entry read to find out
  # which: it is data naming the provider targets, and only the chosen target is
  # looked at further. The entry is read here only because it is selected.
  implOf =
    catalogue: name: provider:
    let
      entry = catalogue.${name};
      isValueEntry = isValue entry;
      set = if isValueEntry then entry else import entry;
      providers = if lib.isAttrs set then set.providers or null else null;
      names = lib.concatStringsSep ", " (lib.attrNames providers);
      extra = lib.attrNames (removeAttrs set [ "providers" ]);
    in
    if providers != null then
      if extra != [ ] then
        throw "dendrite '${name}': a provider set takes only `providers`; it also has ${lib.concatStringsSep ", " extra}"
      else if !lib.isAttrs providers then
        throw "dendrite '${name}': `providers` is a ${builtins.typeOf providers}, not an attrset of provider targets"
      else if provider == null then
        throw "dendrite '${name}' is enabled but chose no provider; available providers: ${names}"
      else if !(providers ? ${provider}) then
        throw "dendrite '${name}' has no provider '${provider}'; available providers: ${names}"
      else
        targetOf name provider providers.${provider} (sourceOf name entry)
    else if provider != null then
      throw "dendrite '${name}' has a single implementation and takes no provider (got '${provider}')"
    else
      {
        path = if isValueEntry then null else entry;
        value = if isValueEntry then entry else null;
        valueName = name;
        source = sourceOf name entry;
      };

  # The chosen provider's target: a path, imported as it is, or a module value,
  # applied under the dendrite's key. A value is named `<name>.<provider>`. A
  # target that is itself a provider set is refused: a provider is a module.
  targetOf =
    name: provider: target: setSource:
    let
      targetName = "${name}.${provider}";
    in
    if !entryType.check target then
      throw "dendrite '${name}' provider '${provider}' is a ${builtins.typeOf target}; a provider is a path or a module value"
    else if isValue target && lib.isAttrs target && target ? providers then
      throw "dendrite '${name}' provider '${provider}' is a provider set; a provider is a path or a module value"
    else if isValue target then
      {
        path = null;
        value = target;
        valueName = targetName;
        source = sourceOf targetName target;
      }
    else
      {
        path = target;
        value = null;
        valueName = name;
        source = setSource;
      };

  # Where a catalogue entry is named: a path by its file, a value by its `_file`,
  # and a value without one by its catalogue name.
  sourceOf =
    name: entry:
    if !isValue entry then
      toString entry
    else if lib.isAttrs entry && entry ? _file then
      toString entry._file
    else
      "<value '${name}'>";

  # `habit.selected`: what one scope resolved, a read-only option in the
  # evaluation that scope's modules run in. It is written from selection data
  # and never reads configuration, so it cannot recurse into the selection.
  selectedModule = selected: {
    _file = toString ./composition.nix;
    options.selected = mkOption {
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
    config.selected = lib.mapAttrs (_: d: { inherit (d) enable provider; }) selected;
  };

  # `habit` in an evaluation the platform runs. `selected` is the scope's own;
  # `modules` add the rest of what that evaluation declares under `habit`.
  habitOption =
    scope: selected: modules:
    mkOption {
      type = habitType scope ([ (selectedModule selected) ] ++ modules);
      default = { };
      description = "habit's own keys in this evaluation.";
    };

  # The paths under `written` whose value `held` does not have. A null is a key
  # nobody wrote.
  unseen =
    prefix: written: held:
    lib.concatLists (
      lib.mapAttrsToList (
        name: value:
        let
          path = "${prefix}.${name}";
          heldValue = held.${name} or null;
        in
        if value == null then
          [ ]
        else if lib.isAttrs value then
          unseen path value (if lib.isAttrs heldValue then heldValue else { })
        else
          lib.optional (value != heldValue) path
      ) (removeAttrs written [ "_module" ])
    );

  # The attribute paths a definition writes, without forcing a value: a wrapped
  # value (`mkIf`, a module) is one key.
  writtenPaths =
    prefix: value:
    if lib.isAttrs value && !(value ? _type) then
      lib.concatLists (lib.mapAttrsToList (name: v: writtenPaths "${prefix}.${name}" v) value)
    else
      [ prefix ];

  # The host module is the platform's own, so the platform evaluation sees every
  # `habit.*` key written anywhere, including the files the host imports, which
  # the scan never reads. The keys are declared here inert and one assertion
  # fails each the scan did not see: without it an imported file's `enable =
  # true` would be absorbed and select nothing. A key written by a file other
  # than the host's is one. A module written inline in the host's own `imports`
  # shares its file, so only its value, which selection does not hold, gives it
  # away; `habit.users.<user>.home.config` has no value to compare, and a file
  # of its own is the only way to catch it.
  platformHabit =
    {
      selection,
      registry,
      hostFile,
      selectionModules,
      scope,
    }:
    {
      config,
      options,
      ...
    }:
    let
      fromFiles = lib.concatMap (
        d:
        map (path: {
          inherit path;
          file = d.file;
        }) (writtenPaths "habit" d.value)
      ) (lib.filter (d: d.file != hostFile) options.habit.definitionsWithLocations);
      # A user's `enable` is held to what the scan read, not what selection
      # resolved: a group's membership is not written by anyone.
      scannedEnable = name: section: key: selection.scanned.users.${name}.${section}.${key}.enable;
      unseenKeys = unseen "habit" {
        inherit (config.habit) dendrites aggregation;
        users = lib.mapAttrs (_: u: u // { home = removeAttrs u.home [ "config" ]; }) config.habit.users;
      } {
        inherit (selection) dendrites aggregation;
        users = lib.mapAttrs (
          name: u:
          u
          // {
            dendrites = lib.mapAttrs (n: d: d // { enable = scannedEnable name "dendrites" n; }) u.dendrites;
            aggregation = lib.mapAttrs (g: a: a // { enable = scannedEnable name "aggregation" g; }) u.aggregation;
          }
        ) selection.users;
      };
      inline = map (path: {
        inherit path;
        file = hostFile;
      }) (lib.subtractLists (map (key: key.path) fromFiles) unseenKeys);
    in
    {
      _file = toString ./composition.nix;

      options.habit = habitOption scope selection.dendrites (
        [
          {
            options = habitOptions {
              inherit (registry) catalogue aggregations;
              inherit scope;
              bodies = null;
              inert = true;
            };
          }
        ]
        ++ selectionModules
      );

      config.assertions = map (key: {
        assertion = false;
        message = "`${key.path}` is set in ${key.file} but the host scan never saw it (scans do not follow `imports`)";
      }) (fromFiles ++ inline);
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
    if !types.path.check path then
      throw "override record '${name}' is a ${builtins.typeOf path}, not a path; a record is a file"
    else
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
  # `overlay` then applies once, however many of its targets were selected.
  #
  # A record's `system` module follows its target's system half: it applies
  # once when some selection of a target has `system = true`, and not when every
  # one asked for the home half alone.
  #
  # A record's `home` module rides exactly the users its target's home half
  # reaches: every user with a home when the host selected the target, the
  # selecting user alone when a user did. The fix then travels with the thing
  # it fixes. A standalone home has no users: its own selection is the one
  # that matches, and `standalone` holds the `home` modules it applies to
  # itself.
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
      hostChoice = lib.unique (enabledNames selection.dendrites ++ lib.attrNames selection.hostHome);
      # What reaches a user's home: the host's dendrites less the ones it opted
      # out of, and the user's own.
      homeTargetsOf = u: lib.filter (d: !u.dendrites.${d}.optOut) hostChoice ++ homeOf u;
      here = lib.unique (hostChoice ++ lib.concatMap homeOf (lib.attrValues selection.users));
      withSystem = scope: lib.filter (name: scope.${name}.system) (enabledNames scope);
      systemHere = lib.unique (
        lib.filter (n: selection.dendrites.${n}.system) hostChoice
        ++ lib.concatMap (u: withSystem u.dendrites) (lib.attrValues selection.users)
      );

      admitsHost = r: r.hosts == null || lib.elem hostName r.hosts;
      hits = names: r: lib.any (d: lib.elem d names) r.dendrites;

      forHost = lib.filter (r: admitsHost r && hits here r) records;
      forSystem = lib.filter (r: admitsHost r && hits systemHere r) records;
      carried = field: rs: lib.concatMap (r: lib.optional (r ? ${field}) r.${field}) rs;
    in
    {
      overlays = carried "overlay" forHost;
      system = carried "system" forSystem;
      home = lib.mapAttrs (
        _: u: carried "home" (lib.filter (r: admitsHost r && hits (homeTargetsOf u) r) records)
      ) selection.users;
      standalone = carried "home" forHost;
      matched = map (r: r.name) forHost;
    };

  # What a class changes is its scope. A `system` class applies a module's
  # system half, takes users, and sends the home half to each user's Home
  # Manager. A `home` class is a Home Manager configuration: the system half is
  # dropped, and the home half is imported into the configuration itself.
  scopeOf = {
    nixos = "system";
    darwin = "system";
    home = "home";
  };

  # A selection module is a module of `habit`, so what it declares is
  # `habit.<name>`. These are habit's own, and a hook declaring one would
  # shadow it or be shadowed by it. The refusal names the file that declared it.
  reservedNames = [
    "dendrites"
    "aggregation"
    "users"
    "selected"
    "home"
  ];

  refuseReservedNames =
    scope: hooks: result:
    let
      declared =
        removeAttrs
          (lib.evalModules {
            modules = hooks ++ [ { _module.check = false; } ];
            specialArgs = { inherit lib scope; };
          }).options
          [ "_module" ];
      clashing = lib.intersectLists reservedNames (lib.attrNames declared);
      name = lib.head clashing;
    in
    if clashing != [ ] then
      throw "selection module ${
        lib.head declared.${name}.declarations
      } declares habit.${name}; habit reserves ${lib.concatStringsSep ", " reservedNames}"
    else
      result;
in
rec {
  inherit
    mkSchema
    implOf
    overridesFor
    ;

  # Gate, then select. Ordinary lib.evalModules both times — no NixOS, no
  # package set, nothing that could depend on the result. The host module goes in
  # as the scan reads it (lib/scan.nix), beside the schema and the hooks'
  # modules. The result is what the host wrote under `habit`, resolved.
  #
  # An aggregation body is DATA (`members`, `providers`, `module`), so it has no
  # way to enable another aggregation: the gate step's answer is the select
  # step's answer, and no recursion machinery is needed to say so.
  evalSelection =
    {
      registry,
      host,
      specialArgs ? { },
      selectionModules ? [ ],
      scope ? "system",
    }:
    let
      inherit (registry) catalogue aggregations;

      hostModule = scan.scanModule { inherit host specialArgs; };

      eval =
        {
          bodies,
          hostGroups,
        }:
        (lib.evalModules {
          modules = [
            (mkSchema {
              inherit
                catalogue
                aggregations
                bodies
                hostGroups
                selectionModules
                scope
                ;
            })
            hostModule
          ];
        }).config.habit;

      # The gate step reads no body, so a user's `enable` there is what the host
      # wrote, null where it wrote nothing.
      gate = eval {
        bodies = null;
        hostGroups = [ ];
      };

      chosen = agg: lib.attrNames (lib.filterAttrs (_: a: a.enable == true) agg);

      selected =
        if scope == "home" && lib.attrNames gate.users != [ ] then
          throw "habit: host ${hostModule._file} sets `habit.users`; a standalone home has no users, the host module is the home itself"
        else
          lib.unique (
            chosen gate.aggregation ++ lib.concatMap (u: chosen u.aggregation) (lib.attrValues gate.users)
          );

      # A host's group reaches every user with a home as if each had selected it.
      hostGroups = chosen gate.aggregation;

      resolved = eval {
        bodies = lib.genAttrs selected (name: readBody name aggregations.${name});
        inherit hostGroups;
      };

      homeHalfOf = g: halfOf (readBody g aggregations.${g}) "home";
      homeMembersOfGroups =
        gs:
        lib.concatMap (
          g:
          let
            half = homeHalfOf g;
          in
          (half.members or [ ]) ++ lib.attrNames (half.providers or { })
        ) gs;

      # The home half a host group sends to its users: each member, and the
      # provider its group names for it (null where none). A host-sent member's
      # system half is the host's, so this is what it applies when no user's
      # home claim is active.
      hostHome = lib.genAttrs (lib.unique (homeMembersOfGroups hostGroups)) (
        n: lib.findFirst (p: p != null) null (map (g: ((homeHalfOf g).providers or { }).${n} or null) hostGroups)
      );

      # What a user's own `enable` resolves to once the host's groups are in: a
      # bool for selection, `optOut` for an explicit `false`, and `hostSent` for
      # a dendrite that only a host group's home half brought to this user.
      normalizeUser =
        name: u:
        let
          gateUser = gate.users.${name};
          explicit = lib.filter (n: gateUser.dendrites.${n}.enable == true) (lib.attrNames gateUser.dendrites);
          ownGroups = lib.filter (g: gateUser.aggregation.${g}.enable == true) (lib.attrNames gateUser.aggregation);
          hostOnlyGroups = lib.filter (
            g: lib.elem g hostGroups && gateUser.aggregation.${g}.enable == null
          ) (lib.attrNames gateUser.aggregation);
          hostSentMembers = homeMembersOfGroups (lib.optionals u.home.enable hostOnlyGroups);
          ownMembers = explicit ++ homeMembersOfGroups ownGroups;
          hostSent = n: lib.elem n hostSentMembers && !(lib.elem n ownMembers);
        in
        u
        // {
          dendrites = lib.mapAttrs (
            n: d:
            let
              on = d.enable == true;
              fromHost = on && hostSent n;
            in
            d
            // {
              enable = on;
              optOut = d.enable == false;
              inherit fromHost;
              # The system half of a host-sent member is the host's to decide.
              system = if fromHost then resolved.dendrites.${n}.system else d.system;
            }
          ) u.dendrites;
          aggregation = lib.mapAttrs (
            g: a:
            a
            // {
              enable = groupOn (lib.optionals u.home.enable hostGroups) g a.enable;
              optOut = a.enable == false;
            }
          ) u.aggregation;
        };
      users = lib.mapAttrs normalizeUser resolved.users;

      neverReached = lib.concatMap (
        name:
        let
          u = users.${name};
          reachedDendrite =
            n: u.home.enable && (resolved.dendrites.${n}.enable || lib.elem n (homeMembersOfGroups (enabledNames u.aggregation)));
          reachedGroup = g: u.home.enable && lib.elem g hostGroups;
        in
        map (
          n: "user '${name}' opts out of dendrite '${n}', which never reached it; remove `habit.users.${name}.dendrites.${n}.enable`"
        ) (lib.filter (n: u.dendrites.${n}.optOut && !reachedDendrite n) (lib.attrNames u.dendrites))
        ++ map (
          g: "user '${name}' opts out of aggregation '${g}', which never reached it; remove `habit.users.${name}.aggregation.${g}.enable`"
        ) (lib.filter (g: u.aggregation.${g}.optOut && !reachedGroup g) (lib.attrNames u.aggregation))
      ) (lib.attrNames users);
    in
    refuseReservedNames scope selectionModules (
      if neverReached != [ ] then
        throw "habit: ${lib.concatStringsSep "; " neverReached}"
      else
        resolved
        // {
          inherit users hostHome;
          # The gate's answer to each user's `enable`, as written: the platform
          # pass checks the host's and imports' writes against it.
          scanned = gate;
        }
    );

  # A host's resolved shape: what it selected and from where, for the system and
  # for each user. Generated from the selection, never maintained by hand.
  inventoryOf =
    { hostName, selection }:
    let
      inherit (selection) catalogue;
      # A file is named by its path and never read here, so the inventory imports
      # nothing the platform pass would not. A value is resolved, which reads no
      # file: a value provider set names its chosen value target.
      sourceOfSelected =
        name: provider:
        if isValue catalogue.${name} then
          (implOf catalogue name provider).source
        else
          sourceOf name catalogue.${name};
      describe =
        selected:
        lib.mapAttrs (name: d: {
          inherit (d) provider system;
          source = sourceOfSelected name d.provider;
        }) (lib.filterAttrs (_: d: d.enable) selected);
      chosen = agg: lib.attrNames (lib.filterAttrs (_: a: a.enable == true) agg);
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
  # One core serves every class. The builders below add the evaluator the caller
  # supplies and nothing else: the list is the whole assembly, so a caller that
  # wants the modules for something other than the evaluator — a test node is
  # one — gets this list rather than a second copy of it.
  mkModules =
    {
      class,
      hostName,
      knownHosts ? [ hostName ],
      registry,
      host,
      homeManagerModule ? null,
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
      scope =
        scopeOf.${class}
          or (throw "unknown class '${class}'; habit builds ${lib.concatStringsSep ", " (lib.attrNames scopeOf)}");
      isHome = scope == "home";

      # What every platform module and every home module receives, and what the
      # scan applies the host to.
      args = specialArgs // {
        inherit system;
        host = hostName;
      };

      selection = evalSelection {
        inherit
          registry
          host
          selectionModules
          scope
          ;
        specialArgs = args;
      };

      # What the module system files the host's definitions under.
      hostFile =
        (scan.scanModule {
          inherit host;
          specialArgs = args;
        })._file;
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

      # The host selects only the home half of a capability, and no user has a
      # home to receive it. A standalone home is its own home and takes none.
      # The users a host dendrite's home half reaches: every user with a home,
      # less those that opted out of this dendrite.
      homeReceivers =
        name: lib.filter (u: !selection.users.${u}.dendrites.${name}.optOut) (lib.attrNames hmUsers);
      homeWithoutUsers = lib.optionals (!isHome) (
        map (
          name:
          if hmUsers == { } then
            "`habit.dendrites.${name}.system = false` selects only the home half of '${name}' but no user has home.enable"
          else
            "`habit.dendrites.${name}.system = false` selects only the home half of '${name}' but every user with home.enable opts out of it"
        ) (lib.filter (name: !selection.dendrites.${name}.system && homeReceivers name == [ ]) (enabledNames selection.dendrites))
      );

      # One wrapped module per selected capability, in catalogue order. The
      # system half applies when some selection of it, the host's or a user's,
      # has `system = true`; one that asks for the home half alone is told
      # apart by `homeOnlyBy`, which the module refuses if it has no home half.
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
              by = "host '${hostName}' `habit.dendrites.${name}.system = false`";
              inherit (selection.dendrites.${name}) provider system;
              users = homeReceivers name;
            }
            ++ lib.concatMap (
              userName:
              let
                d = selection.users.${userName}.dendrites.${name};
              in
              lib.optional d.enable {
                who = if d.fromHost then "host" else "user '${userName}'";
                by =
                  if d.fromHost then
                    "host '${hostName}' `habit.dendrites.${name}.system = false`"
                  else
                    "user '${userName}' of host '${hostName}' `habit.users.${userName}.dendrites.${name}.system = false`";
                inherit (d) provider system;
                users = [ userName ];
              }
            ) (lib.attrNames selection.users)
            # A host-sent member no user's home claim carries (zero home users,
            # or each opted out) still applies its system half: the host sent it.
            ++ lib.optional (
              lib.hasAttr name selection.hostHome
              && !selection.dendrites.${name}.enable
              && !lib.any (u: selection.users.${u}.dendrites.${name}.enable) (lib.attrNames selection.users)
            ) {
              who = "host";
              by = "host '${hostName}' `habit.dendrites.${name}.system = false`";
              provider = selection.hostHome.${name};
              inherit (selection.dendrites.${name}) system;
              users = [ ];
            };
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
              inherit (impl) path value valueName;
              standalone = isHome;
              homeFor = lib.unique (lib.concatMap (c: c.users) claims);
              system = lib.any (c: c.system) claims;
              homeOnlyBy = lib.optionals (!isHome) (map (c: c.by) (lib.filter (c: !c.system) claims));
            }
          )
      ) (lib.attrNames catalogue);

      # A user's module is an account on the system and the start of their home.
      userModules = lib.mapAttrsToList (
        userName: u:
        lanes.wrap {
          name = "user:${userName}";
          path = u.definition;
          standalone = false;
          homeFor = lib.optional u.home.enable userName;
        }
      ) selection.users;

      # The `module` of each selected aggregation's half, in aggregation name
      # order. A body is read again here: the read is cached, and a selected body
      # has already been validated.
      aggregationModules =
        scope: aggregation:
        lib.concatMap (
          name:
          let
            half = halfOf (readBody name registry.aggregations.${name}) scope;
          in
          lib.optional (half ? module) half.module
        ) (enabledNames aggregation);

      userHome = userName: u: {
        imports = [
          { options.habit = habitOption "home" u.dendrites [ ]; }
        ]
        ++ (overrides.home.${userName} or [ ])
        ++ aggregationModules "home" u.aggregation
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
      ++ [
        (platformHabit {
          inherit
            selection
            registry
            hostFile
            selectionModules
            scope
            ;
        })
      ]
      ++ userModules
      ++ dendriteModules
      ++ lib.optional (hmUsers != { }) homeWiring
      ++ extra
      # A record outranks everything the constructor imported on its behalf; the
      # selected aggregations' modules come next, and the host's own module
      # outranks them all. A home takes its records' and groups' home modules
      # for its own.
      ++ (if isHome then overrides.standalone else overrides.system)
      ++ aggregationModules scope selection.aggregation
      ++ [ host ];
    in
    if strandedHome != [ ] then
      throw "host '${hostName}': ${lib.concatStringsSep "; " strandedHome}"
    else if homeWithoutUsers != [ ] then
      throw "host '${hostName}': ${lib.concatStringsSep "; " homeWithoutUsers}"
    else if hmUsers != { } && homeManagerModule == null then
      throw "host '${hostName}': user(s) ${lib.concatStringsSep ", " (lib.attrNames hmUsers)} have home.enable = true but no `homeManagerModule` was given"
    else if isHome && homeManagerModule != null then
      throw "home '${hostName}' was given a `homeManagerModule`; a standalone home is evaluated by Home Manager itself and imports none"
    else
      {
        inherit
          modules
          selection
          ;
        # What a platform evaluator gets; a builder passes it straight to it.
        specialArgs = args;
        # The review surface: what this host resolved, derived from selection
        # and never maintained by hand.
        inventory = inventoryOf { inherit hostName selection; } // {
          overrides = overrides.matched;
        };
      };

  mkNixosModules = args: mkModules (args // { class = "nixos"; });

  # Each builder takes the evaluator's own flake from the caller, since habit
  # reads no input: `nixpkgs`, `darwin` (nix-darwin) or `home-manager`.
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

  mkDarwinHost =
    args@{ darwin, ... }:
    let
      resolved = mkModules (removeAttrs args [ "darwin" ] // { class = "darwin"; });
    in
    {
      inherit (resolved) selection inventory;
      system = darwin.lib.darwinSystem {
        inherit (resolved) modules specialArgs;
      };
    };

  mkHome =
    args@{ home-manager, pkgs, ... }:
    let
      resolved = mkModules (
        removeAttrs args [
          "home-manager"
          "pkgs"
        ]
        // {
          class = "home";
        }
      );
    in
    {
      inherit (resolved) selection inventory;
      home = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        inherit (resolved) modules;
        extraSpecialArgs = resolved.specialArgs;
      };
    };
}
