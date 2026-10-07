# Everything a host writes besides `habit` is platform configuration, and the
# scan forces none of it: each line below throws, or needs a platform argument,
# if it is ever evaluated. Its `imports` throw too.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./importThrows.nix
    (import ./importThrows.nix)
  ];

  habit.dendrites.systemonly.enable = true;
  habit.dendrites.homeonly.enable = false;
  habit.aggregation.workstation.enable = true;
  habit.aggregation.workstation.notifications.provider = "herald";
  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    dendrites.homeonly.enable = true;
  };

  services.foo.package = pkgs.hello;
  services.bar.enable = config.x;
  networking.hostName = throw "the scan forced networking.hostName";
  environment.etc."a".text = throw "the scan forced environment.etc";
  programs = throw "the scan forced a whole top-level key";
  services.z = lib.mkIf config.services.q.enable { a = pkgs.hello.out; };
  system.stateVersion = "26.11";
}
