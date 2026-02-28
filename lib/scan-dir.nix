# scan-dir.nix — Scan a directory for .nix files and subdirectories with default.nix
#
# Returns: { name = { path, type }; ... }
#   type is "file" for foo.nix, "directory" for foo/default.nix
#
# - foo.nix → name "foo", type "file"
# - foo/default.nix → name "foo", type "directory"
# - foo.nix takes precedence over foo/ (same as blueprint)
# - default.nix at the root is ignored
# - Non-.nix files are ignored

let
  inherit (builtins)
    attrNames
    filter
    head
    listToAttrs
    match
    pathExists
    readDir
    ;

  matchNixFile = match "(.+)\\.nix$";

  scanDir = path:
    if !pathExists path then
      { }
    else
      let
        entries = readDir path;
        names = attrNames entries;

        # Collect .nix files (excluding default.nix)
        nixFiles = listToAttrs (filter (x: x != null) (map (name:
          let
            m = matchNixFile name;
          in
          if entries.${name} == "regular" && m != null && name != "default.nix" then
            {
              name = head m;
              value = {
                path = path + "/${name}";
                type = "file";
              };
            }
          else
            null
        ) names));

        # Collect directories with default.nix
        dirs = listToAttrs (filter (x: x != null) (map (name:
          if entries.${name} == "directory" && pathExists (path + "/${name}/default.nix") then
            {
              inherit name;
              value = {
                path = path + "/${name}";
                type = "directory";
              };
            }
          else
            null
        ) names));

      in
      # .nix files take precedence over directories
      dirs // nixFiles;

in
scanDir
