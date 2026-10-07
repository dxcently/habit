# The host as the selection pass reads it. The host is one module that is also
# the platform's own, so selection and NixOS read the same file: this applies it
# to the caller's arguments with the platform's own replaced by values that
# throw, and drops its `imports`. What survives is the literal `habit.*` the
# host wrote, beside platform settings nobody forces.
{ lib }:
let
  inherit (lib)
    attrNames
    filter
    functionArgs
    genAttrs
    isAttrs
    isFunction
    ;

  platformArguments = [
    "config"
    "pkgs"
    "options"
    "osConfig"
  ];

  # What the module system calls a module that was not given as a file.
  unknownFile = "<unknown-file>";

  fileOf =
    module:
    if isAttrs module then
      module._file or unknownFile
    else if isFunction module then
      unknownFile
    else
      toString module;

  scanModule =
    { host, specialArgs }:
    let
      raw = if isAttrs host || isFunction host then host else import host;

      # What the messages name: known before the host is applied. A module that
      # names its own `_file` is the module system's to name; one whose function
      # returns it can only be named once applied, which `_file` below does.
      file = if isAttrs raw then raw._file or (fileOf host) else fileOf host;
      formals = if isFunction raw then functionArgs raw else { };

      # The module system's own precedence: `lib` is the caller's to override.
      provided = {
        inherit lib;
      }
      // specialArgs;

      # An argument the host takes that nothing provides throws when it is
      # read, so a host that only uses it under `imports` still scans.
      missing = genAttrs (filter (name: !formals.${name} && !(provided ? ${name})) (attrNames formals)) (
        name:
        throw "habit: host ${file} takes argument(s) ${name} which the scan does not provide; pass them in specialArgs"
      );

      args =
        provided
        // missing
        // genAttrs platformArguments (
          name:
          throw "habit: host ${file} reads `${name}` while selection is being read; selection may not depend on platform configuration"
        );

      module = if isFunction raw then raw args else raw;
    in
    if !isAttrs module then
      throw "habit: host ${file} does not look like a module, got ${builtins.typeOf module}"
    else if module ? _type then
      {
        _file = file;
        config = module;
      }
    else
      removeAttrs module [
        "imports"
        "require"
      ]
      // {
        _file = module._file or file;
      };
in
{
  inherit fileOf scanModule;
}
