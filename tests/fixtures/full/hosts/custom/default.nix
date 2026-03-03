# Custom host escape hatch for testing
{
  flake,
  inputs,
  hostName,
}:
{
  class = "nixos";
  value = {
    _type = "test-nixos-system";
    inherit hostName;
  };
}
