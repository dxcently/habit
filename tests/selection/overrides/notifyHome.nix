# A record that carries only a home half, targeting the notifications
# capability: it rides the home of every user the capability reaches.
{
  dendrites = [ "notifications" ];
  home = _: { fixture.marks = [ "notify" ]; };
}
