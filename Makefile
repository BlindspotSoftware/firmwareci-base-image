TARGETS = base-x86_64 base-aarch64

all: $(TARGETS)

base-x86_64:
	nix build .#packages.x86_64-linux.base --out-link $@

base-aarch64:
	nix build .#packages.aarch64-linux.base --out-link $@

clean:
	rm -f $(TARGETS)

.NOTPARALLEL: all $(TARGETS)
.PHONY: all clean $(TARGETS)
