# Entries that pin where the read boundary sits. An entry is read to weak head
# normal form to learn its kind, so an entry that is itself `throw` throws on
# read. Its attributes, and a function's body, are not forced unless selected.
{
  thrownAttrs = {
    _file = throw "file read";
    providers = throw "providers read";
    config = throw "config read";
  };
}
