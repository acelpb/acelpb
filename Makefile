build-tools:
	podman build -t acelpb-nix-tools -f Containerfile .
dev:
	rsync -r -z . ac:/etc/nixos
	cd ../nixpkgs && git push acelpb --force
	ssh ac "sudo nixos-rebuild switch --upgrade --show-trace -I nixpkgs=~/src/nixpkgs"
deploy:
	rsync -r -z . ac:/etc/nixos
	ssh ac "sudo nixos-rebuild switch --upgrade"
cleanup:
	ssh ac "sudo nix-collect-garbage -d"


deploy2:
	rsync -r -z . ac2:/etc/nixos
	ssh ac2 "sudo nixos-rebuild switch --upgrade"
