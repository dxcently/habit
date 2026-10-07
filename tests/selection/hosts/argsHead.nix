# A head with no named formals receives every argument, the poisoned ones too.
args: {
  habit.dendrites.systemonly.enable = true;

  services.x.package = args.pkgs.hello;
  services.y = args.lib.mkIf args.config.y { a = 1; };
}
