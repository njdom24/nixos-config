final: prev: {
  # TODO: https://github.com/NixOS/nixpkgs/pull/530692
  rpcs3 = prev.rpcs3.overrideAttrs (old: {
    buildInputs = map (dep:
      if dep == prev.glew
      then prev.glew.override { enableEGL = false; }
      else dep
    ) old.buildInputs;
  });
}
