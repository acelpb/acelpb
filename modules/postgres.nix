{ lib, pkgs, ... }:
{
  config = {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      authentication = lib.mkBefore ''
        local acfunk acfunk peer map=acfunk
      '';
      identMap = ''
        acfunk jenkins acfunk
      '';
    };
  };
}
