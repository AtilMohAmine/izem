# Define the compiler and flags
NIMBLE = nimble
NIM_FLAGS = -d:release --mm:orc --threads:on --opt:speed
LDFLAGS = -ljavascriptcoregtk-4.0
CFLAGS = -I/usr/include/webkitgtk-4.0
OUTDIR = ./

# Define the source and target files
SRC = ./src/runtime.nim

# Default target
all: compile

# Install dependencies
deps:
	$(NIMBLE) install -y

# Compile the source code
compile:
	@mkdir -p $(OUTDIR)
	$(NIMBLE) c  $(NIM_FLAGS) --passL:"$(LDFLAGS)" --passC:"$(CFLAGS)" --outdir:$(OUTDIR) --out:izem $(SRC)

# Compile the source code for debugging
debug:
	@mkdir -p $(OUTDIR)
	$(NIMBLE) c -d:debug --passL:"$(LDFLAGS)" --passC:"$(CFLAGS)" --outdir:$(OUTDIR) --out:izem $(SRC)

# Phony targets
.PHONY: all deps compile debug
