# Define the compiler and flags
NIM = nim
NIM_FLAGS = -d:release --mm:orc --threads:on --opt:speed
LDFLAGS = -ljavascriptcoregtk-4.0
CFLAGS = -I/usr/include/webkitgtk-4.0
OUTDIR = ./

# Define the source and target files
SRC = ./src/runtime.nim

# Default target
all: compile

# Compile the source code
compile:
	@mkdir -p $(OUTDIR)
	$(NIM) c $(NIM_FLAGS) --passL:"$(LDFLAGS)" --passC:"$(CFLAGS)" --outdir:$(OUTDIR) $(SRC)

# Phony targets
.PHONY: all compile
