.PHONY: build-tools deploy cleanup

build-tools:
	podman build -t acelpb-nix-tools -f Containerfile .
deploy:
	rsync -r -z --exclude .git --exclude .claude . ac:/etc/nixos
	ssh ac "sudo nixos-rebuild switch --upgrade"
cleanup:
	ssh ac "sudo nix-collect-garbage -d"
