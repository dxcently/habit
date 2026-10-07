# habit's one wrapper: a selected dendrite is a plain module, and this derives
# its system half and its home half. `wrap` is the entry; `split` is exposed
# for the suite.
{ lib }:
let
  inherit (lib)
    attrNames
    genAttrs
    isAttrs
    isFunction
    mkIf
    mkMerge
    mkOverride
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

  # Walks the `_type` structure of a config and never forces a condition: an
  # `if` wraps both halves, so each half carries the condition into whatever
  # evaluates it.
  split =
    where: c:
    let
      both = f: p: {
        sys = f p.sys;
        home = f p.home;
      };
    in
    if !isAttrs c then
      throw "${where}: config must be an attribute set, got ${builtins.typeOf c}"
    else if c ? _type then
      if c._type == "if" then
        both (mkIf c.condition) (split where c.content)
      else if c._type == "override" then
        both (mkOverride c.priority) (split where c.content)
      else if c._type == "merge" then
        let
          parts = map (split where) c.contents;
        in
        {
          sys = mkMerge (map (p: p.sys) parts);
          home = mkMerge (map (p: p.home) parts);
        }
      else
        throw "${where}: config is a `${c._type}` value habit cannot split"
    else
      let
        h = c.habit or { };
        unknown = removeAttrs h [ "home" ];
      in
      if !isAttrs h then
        throw "${where}: `habit` must be an attribute set holding `home`, got ${builtins.typeOf h}"
      else if h ? _type then
        throw "${where}: `habit` is a `${h._type}` value; write habit.home as a plain attribute"
      else if unknown != { } then
        throw "${where}: unknown habit key(s): ${toString (attrNames unknown)}; only `home` is read"
      else
        {
          sys = removeAttrs c [ "habit" ];
          home = h.home or { };
        };

  # `system` says whether the system half applies; `homeFor` lists the users
  # whose home receives the home half. A half that does not apply is not
  # emitted at all, never gated by `mkIf`: `mkIf false` still defines its
  # options, an error for one the platform does not declare (every option
  # under `home-manager` on a host without Home Manager's module).
  wrap =
    {
      name,
      path,
      system,
      homeFor,
    }:
    let
      file = toString path;
      where = "${file} (habit module '${name}')";
      raw = import path;
      build =
        module:
        let
          m = unify where file module;
          p = split where m.config;
        in
        m
        // {
          key = "habit:${name}";
          imports = optionals system m.imports;
          config = mkMerge [
            (optionalAttrs system p.sys)
            (optionalAttrs (homeFor != [ ]) {
              home-manager.users = genAttrs homeFor (_: p.home);
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
  inherit split wrap;
}
