# Tests for transpose
let
  prelude = import ./prelude.nix;
  inherit (prelude._internal) transpose;
in
{
  # Single system, single category
  testSingleSystemSingleCategory = {
    expr = transpose {
      x86_64-linux = {
        packages = { hello = "hello-pkg"; };
      };
    };
    expected = {
      packages = {
        x86_64-linux = { hello = "hello-pkg"; };
      };
    };
  };

  # Multiple systems, multiple categories
  testMultiSystemMultiCategory = {
    expr = transpose {
      x86_64-linux = {
        packages = { hello = "hello-x86"; };
        checks = { test = "test-x86"; };
      };
      aarch64-linux = {
        packages = { hello = "hello-aarch"; };
        checks = { test = "test-aarch"; };
      };
    };
    expected = {
      packages = {
        x86_64-linux = { hello = "hello-x86"; };
        aarch64-linux = { hello = "hello-aarch"; };
      };
      checks = {
        x86_64-linux = { test = "test-x86"; };
        aarch64-linux = { test = "test-aarch"; };
      };
    };
  };

  # Category present in only some systems
  testPartialCategory = {
    expr = transpose {
      x86_64-linux = {
        packages = { hello = "hello-x86"; };
        checks = { test = "test-x86"; };
      };
      aarch64-linux = {
        packages = { hello = "hello-aarch"; };
      };
    };
    expected = {
      packages = {
        x86_64-linux = { hello = "hello-x86"; };
        aarch64-linux = { hello = "hello-aarch"; };
      };
      checks = {
        x86_64-linux = { test = "test-x86"; };
        aarch64-linux = {};
      };
    };
  };

  # Empty input
  testEmpty = {
    expr = transpose {};
    expected = {};
  };
}
