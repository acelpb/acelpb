
deploy:
	rsync -r -z . ac:/etc/nixos
	ssh ac "sudo nixos-rebuild switch --upgrade"

cleanup:
	ssh ac "sudo nix-collect-garbage -d"
