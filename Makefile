TARGETS = base-x86_64 base-aarch64

all: $(TARGETS)

base-x86_64:
	nix build .#packages.x86_64-linux.base --out-link $@

base-aarch64:
ifeq ($(shell uname -m),x86_64)
	echo "Cross compiling. Limiting vCPUs in QEMU to 8."
	nix build .#base-aarch64 --cores 8 --out-link $@
else
	nix build .#packages.aarch64-linux.base --out-link $@
endif

clean:
	rm -f $(TARGETS)

.NOTPARALLEL: all $(TARGETS)
.PHONY: all clean $(TARGETS)
