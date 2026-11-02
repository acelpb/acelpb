_: {
  config = {

    networking.firewall.allowedUDPPorts = [ 19132 ];

    virtualisation.oci-containers.containers.minecraft-bedrock = {
      image = "itzg/minecraft-bedrock-server";
      autoStart = true;
      environment = {
        EULA = "TRUE";
        SERVER_NAME = "acelpb";
        GAMEMODE = "survival";
        DIFFICULTY = "normal";
      };
      volumes = [ "/var/lib/minecraft-bedrock:/data" ];
      ports = [ "19132:19132/udp" ];
    };

  };
}
