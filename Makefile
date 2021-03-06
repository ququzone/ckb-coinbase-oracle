TARGET := riscv64-unknown-elf
CC := $(TARGET)-gcc
LD := $(TARGET)-gcc
OBJCOPY := $(TARGET)-objcopy
CFLAGS := -O3 -Ideps/molecule -I deps/secp256k1/src -I deps/secp256k1 -I deps/ckb-c-std-lib -I c -I build -Wall -Werror -Wno-nonnull-compare -Wno-unused-function -g
LDFLAGS := -Wl,-static -fdata-sections -ffunction-sections -Wl,--gc-sections
SECP256K1_SRC := deps/secp256k1/src/ecmult_static_pre_context.h
MOLC := moleculec
MOLC_VERSION := 0.4.1
PROTOCOL_HEADER := c/protocol.h
PROTOCOL_SCHEMA := c/blockchain.mol
PROTOCOL_VERSION := d75e4c56ffa40e17fd2fe477da3f98c5578edcd1
PROTOCOL_URL := https://raw.githubusercontent.com/nervosnetwork/ckb/${PROTOCOL_VERSION}/util/types/schemas/blockchain.mol

# docker pull nervos/ckb-riscv-gnu-toolchain:bionic-20190702
BUILDER_DOCKER := nervos/ckb-riscv-gnu-toolchain@sha256:7b168b4b109a0f741078a71b7c4dddaf1d283a5244608f7851f5714fbad273ba

all: specs/cells/always_success specs/cells/coinbase_oracle

all-via-docker: ${PROTOCOL_HEADER}
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER} bash -c "cd /code && make"

specs/cells/always_success: c/always_success.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	$(OBJCOPY) --only-keep-debug $@ $(subst specs/cells,build,$@.debug)
	$(OBJCOPY) --strip-debug --strip-all $@

specs/cells/coinbase_oracle: c/coinbase_oracle.c ${PROTOCOL_HEADER} build/secp256k1_data_info.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	$(OBJCOPY) --only-keep-debug $@ $(subst specs/cells,build,$@.debug)
	$(OBJCOPY) --strip-debug --strip-all $@

build/secp256k1_data_info.h: build/dump_secp256k1_data
	$<

build/dump_secp256k1_data: c/dump_secp256k1_data.c $(SECP256K1_SRC)
	mkdir -p build
	gcc $(CFLAGS) -o $@ $<

$(SECP256K1_SRC):
	cd deps/secp256k1 && \
		./autogen.sh && \
		CC=$(CC) LD=$(LD) ./configure --with-bignum=no --enable-ecmult-static-precomputation --enable-endomorphism --enable-module-recovery --host=$(TARGET) && \
		make src/ecmult_static_pre_context.h src/ecmult_static_context.h

generate-protocol: check-moleculec-version ${PROTOCOL_HEADER}

check-moleculec-version:
	test "$$(${MOLC} --version | awk '{ print $$2 }' | tr -d ' ')" = ${MOLC_VERSION}

${PROTOCOL_HEADER}: ${PROTOCOL_SCHEMA}
	${MOLC} --language c --schema-file $< > $@

${PROTOCOL_SCHEMA}:
	curl -L -o $@ ${PROTOCOL_URL}

clean:
	rm -rf specs/cells/always_success
	rm -rf specs/cells/coinbase_oracle
	rm -rf build/secp256k1_data_info.h build/dump_secp256k1_data
	rm -rf specs/cells/secp256k1_data
	rm -rf build/*.debug
	cd deps/secp256k1 && [ -f "Makefile" ] && make clean

dist: clean all

.PHONY: all all-via-docker dist clean
