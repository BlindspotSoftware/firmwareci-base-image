TARGETS = base chipsec

all: $(TARGETS)

$(TARGETS):
	nix build .#$@ --out-link $@

clean:
	rm -f $(TARGETS)

.NOTPARALLEL: all $(TARGETS)
.PHONY: all clean $(TARGETS)