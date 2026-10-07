{ osConfig, ... }:
{
  habit.dendrites.systemonly.enable = osConfig.services.x.enable;
}
