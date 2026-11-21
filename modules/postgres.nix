{ lib, pkgs, ... }:
{
  config = {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      authentication = lib.mkBefore ''
        local acfunk acfunk peer map=acfunk
      '';
      identMap = ''
        acfunk jenkins acfunk
      '';
    };
  };
}
