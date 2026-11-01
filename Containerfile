FROM nixos/nix

RUN echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf && \
    nix profile install \
        nixpkgs#nixfmt \
        nixpkgs#statix \
        nixpkgs#deadnix && \
    mkdir -p /usr/local/bin && ln -s /root/.nix-profile/bin/bash /usr/local/bin/bash && \
    echo 'eval $(ssh-agent -a /tmp/ssh-agent.sock -s) > /dev/null && ssh-add 2>/dev/null' >> /root/.bashrc
