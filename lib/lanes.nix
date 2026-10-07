# habit's one wrapper: a selected dendrite is a plain module, and this derives
# its system half and its home half. `wrap` is the entry; `leaves` is exposed
# for the suite.
{ lib }:
let
  inherit (lib)
    any
    attrNames
    concatMap
    genAttrs
    isAttrs
    isFunction
    mkIf
    mkMerge
    mkOverride
    optional
    optionalAttrs
    optionals
    ;
  inherit (builtins) intersectAttrs;

  moduleKeys = [
    "_class"
    "_file"
    "key"
    "disabledModules"
    "imports"
    "options"
    "config"
    "meta"
    "freeformType"
  ];
  shorthandKeys = [
    "_class"
    "_file"
    "key"
    "disabledModules"
    "require"
    "imports"
    "meta"
    "freeformType"
  ];

  # nixpkgs' `unifyModuleSyntax` is deprecated for external use (lib/modules.nix
  # at nixpkgs e554fab), so its shorthand rules are mirrored here. `meta` and
  # `freeformType` stay module-level keys for the module system to fold.
  unify =
    where: file: m:
    let
      common = {
        _file = toString (m._file or file);
        _class = m._class or null;
        disabledModules = m.disabledModules or [ ];
      }
      // intersectAttrs {
        meta = null;
        freeformType = null;
      } m;
      unsupported = removeAttrs m moduleKeys;
    in
    if !isAttrs m then
      throw "${where}: does not look like a module, got ${builtins.typeOf m}"
    else if m ? config || m ? options then
      if unsupported != { } then
        throw "${where}: has an unsupported top-level attribute: ${toString (attrNames unsupported)}; put configuration under `config`"
      else
        common
        // {
          imports = m.imports or [ ];
          options = m.options or { };
          config = m.config or { };
        }
    else
      common
      // {
        imports = m.require or [ ] ++ m.imports or [ ];
        options = { };
        config = removeAttrs m shorthandKeys;
      };

  # The plain values under a tree of `mkIf`, `mkOverride` and `mkMerge`, each
  # with the properties that cover it, outermost first; `leaf` makes the entry.
  # A condition is never forced: it stays in its property.
  leaves =
    leaf: covers: value:
    let
      type = value._type or null;
    in
    if type == "if" || type == "override" then
      leaves leaf (covers ++ [ value ]) value.content
    else if type == "merge" then
      concatMap (leaves leaf covers) value.contents
    else
      [ (leaf covers value) ];

  cover =
    covers: value:
    lib.foldr (
      c: inner: if c._type == "if" then mkIf c.condition inner else mkOverride c.priority inner
    ) value covers;

  # One plain config: what the system gets, and the `habit.home` value.
  configLeaf =
    where: covers: c:
    let
      h = c.habit or { };
      unknown = removeAttrs h [ "home" ];
    in
    if !isAttrs c then
      throw "${where}: config must be an attribute set, got ${builtins.typeOf c}"
    else if c ? _type then
      throw "${where}: config is a `${c._type}` value habit cannot split"
    else if !isAttrs h then
      throw "${where}: `habit` must be an attribute set holding `home`, got ${builtins.typeOf h}"
    else if h ? _type then
      throw "${where}: `habit` is a `${h._type}` value; write habit.home as a plain attribute"
    else if unknown != { } then
      throw "${where}: unknown habit key(s): ${toString (attrNames unknown)}; only `home` is read"
    else
      {
        inherit covers;
        sys = removeAttrs c [ "habit" ];
        home = h.home or { };
      };

  # One module of a home half, covered at its `config`. `imports` and `options`
  # are read before any condition is, so a condition cannot cover them: a module
  # that has them under one is refused. A path is the module it names.
  homeLeaf =
    where: file: covers: home:
    let
      isModuleFile = builtins.isPath home;
      module = if isModuleFile then import home else home;
      covered =
        m:
        let
          u = unify where (if isModuleFile then toString home else file) m;
        in
        if any (c: c._type == "if") covers && (u.imports != [ ] || u.options != { }) then
          throw "${where}: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it"
        else
          u // { config = cover covers u.config; };
    in
    if isFunction module then
      lib.setFunctionArgs (args: covered (module args)) (lib.functionArgs module)
    else
      covered module;

  # `standalone`: the evaluation is itself the home, so the system half is
  # dropped, its `imports` with it, and the home half is imported. Otherwise the
  # system half applies and the home half goes to the users in `homeFor`. A half
  # that does not apply is not emitted at all, never gated by `mkIf`: `mkIf
  # false` still defines its options, an error for one the platform does not
  # declare (every option under `home-manager` without Home Manager's module).
  wrap =
    {
      name,
      path,
      standalone,
      homeFor,
    }:
    let
      file = toString (if lib.pathIsDirectory path then path + "/default.nix" else path);
      where = "${file} (habit module '${name}')";
      raw = import path;
      build =
        module:
        let
          m = unify where file module;
          cs = leaves (configLeaf where) [ ] m.config;
          sys = mkMerge (map (c: cover c.covers c.sys) cs);

          # Never a conditional definition: a priority on a user's definition
          # would filter every other module's home half for that user away. A
          # function, so a submodule type that reads an attribute set as
          # `config` alone does not take its `imports` for an option.
          home = _: {
            imports = concatMap (c: leaves (homeLeaf "${where} `habit.home`" file) c.covers c.home) cs;
          };
        in
        m
        // {
          key = "habit:${name}";
          imports = optionals (!standalone) m.imports ++ optional standalone home;
          config = mkMerge [
            (optionalAttrs (!standalone) sys)
            (optionalAttrs (homeFor != [ ]) {
              home-manager.users = genAttrs homeFor (_: home);
            })
          ];
        };
    in
    if isFunction raw then
      lib.setFunctionArgs (args: build (raw args)) (lib.functionArgs raw)
    else
      build raw;
in
{
  inherit leaves wrap;
}
