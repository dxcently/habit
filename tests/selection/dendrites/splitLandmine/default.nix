# Both halves, and a system half whose import throws: the import is reached only
# when the system half applies.
{
  imports = [ ../landmine ];
  fixture.marks = [ "splitlandmine" ];
  habit.home.fixture.marks = [ "splitlandmine" ];
}
