# NixOS module that takes publisher args
{ flake, inputs }:
# Returns the wrapped module — closes over publisher's flake/inputs
{ ... }:
{
  _publisherFlake = flake;
  _publisherInputs = inputs;
}
