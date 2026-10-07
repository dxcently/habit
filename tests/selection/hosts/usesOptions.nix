{ options, ... }:
{
  habit.dendrites.systemonly.enable = options ? services;
}
