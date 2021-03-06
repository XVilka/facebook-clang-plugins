# Copyright (c) 2014, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.

.PHONY: clean all test all_ast_samples

LEVEL=..
include $(LEVEL)/Makefile.common

HEADERS+=SimplePluginASTAction.h FileUtils.h FileServices.h AttrParameterVectorStream.h
OBJS+=SimplePluginASTAction.o FileUtils.o FileServices.o AttrParameterVectorStream.o

# ASTExporter
HEADERS+=atdlib/ATDWriter.h ASTExporter.h
OBJS+=ASTExporter.o

# Json
PLUGINS+=JsonASTExporter
EXTS+=.json

# Yojson
PLUGINS+=YojsonASTExporter
EXTS+=.yjson

# biniou
BINIOU_PLUGIN=BiniouASTExporter
PLUGINS+=$(BINIOU_PLUGIN)
EXTS+=.biniou

all: build/FacebookClangPlugin.dylib build/record_copied_file

# hook to optional external sources
include $(LEVEL)/Makefile.extra
ifneq "$(EXTRA_DIR)" ""
include $(EXTRA_DIR)/Makefile.include
endif

include $(LEVEL)/Makefile.rules

CLANG_FRONTEND=$(CLANG) -fsyntax-only -Xpreprocessor -detailed-preprocessing-record -Xclang -load -Xclang $(shell pwd)/build/FacebookClangPlugin.dylib

build/FacebookClangPlugin.dylib: $(OBJS:%=build/%) $(HEADERS)
	@mkdir -p build
	$(CXX) $(LDFLAGS_DYLIB) -o $@ $(OBJS:%=build/%) -lz -lpthread -lm

build/record_copied_file: build/record_copied_file.o build/FileServices.o $(HEADERS)
	@mkdir -p build
	$(CXX) $(CFLAGS) -o $@ build/record_copied_file.o build/FileServices.o

# Experimental tool. This requires clang static libraries.
AST_EXPORTER_OBJS=ast_exporter_bin.o SimplePluginASTAction.o FileUtils.o FileServices.o AttrParameterVectorStream.o
build/ast_exporter_bin: $(AST_EXPORTER_OBJS:%=build/%) $(HEADERS)
	@mkdir -p build
	$(CXX) $(LDFLAGS) $(LLVM_CXXFLAGS) $(CLANG_TOOL_LIBS) $(LLVM_LDFLAGS) -lz -lpthread -lm -o $@ $(AST_EXPORTER_OBJS:%=build/%)

TEST_DIRS=tests
ifneq "$(EXTRA_DIR)" ""
TEST_DIRS+=$(EXTRA_DIR)/tests
endif

OUT_TEST_FILES=${TEST_DIRS:%=%/*/*.out}

# To make sharing of test files easier, each source file should be
# found either in 'tests' or '$(EXTRA_DIR)/tests'. A plugin will only
# use the source files for which a .exp file exists in the
# corresponding subdirectory.
ifneq "$(EXTRA_DIR)" ""
EXPFILES_FORMULA=tests/$$P/*.exp "$(EXTRA_DIR)"/tests/$$P/*.exp
SRCFILE_FORMULA=$$(ls {tests,"$(EXTRA_DIR)"/tests}/$$(basename $$TEST) 2>/dev/null || true)
FILTERFILE_FORMULA=$$(ls {tests,"$(EXTRA_DIR)"/tests}/$${P}/filter.sh 2>/dev/null || true)
else
EXPFILES_FORMULA=tests/$$P/*.exp
SRCFILE_FORMULA=tests/$$(basename $$TEST)
FILTERFILE_FORMULA=tests/$${P}/filter.sh
endif

test: build/FacebookClangPlugin.dylib
	@for P in $(PLUGINS); do                                                        \
	   if [ "$$P" == "BiniouASTExporter" ] && ! hash bdump 2>/dev/null;             \
	   then continue;                                                               \
	   fi;                                                                          \
	   echo "-- $$P --";                                                            \
	   export CLANG_FRONTEND_PLUGIN__AST_WITH_POINTERS=0;                           \
	   rm -rf build/tmp_$$P;                                                        \
	   mkdir -p build/tmp_$$P;                                                      \
	   for EXPFILE in $(EXPFILES_FORMULA); do                                       \
	     TEST=$${EXPFILE%.exp};                                                     \
	     EXTRA_FLAGS="";                                                            \
	     case "$(SRCFILE_FORMULA)" in                                               \
	     *.m )                                                                      \
	       if [ "$$(uname)" != "Darwin" ]; then                                     \
	         printf "[~] %s skipped (non-Darwin architecture detected)\n"           \
	           "$$(basename $(SRCFILE_FORMULA))";                                   \
	         continue;                                                              \
	       fi;                                                                      \
	       EXTRA_FLAGS="-ObjC -fblocks";                                            \
	       ;;                                                                       \
	     *.cpp )                                                                    \
	       EXTRA_FLAGS="--std=c++11";                                               \
	       ;;                                                                       \
	     *.mm )                                                                     \
	       EXTRA_FLAGS="--std=c++11 -ObjC++ -fblocks";                              \
	       ;;                                                                       \
	     esac;                                                                      \
	     $(RUNTEST) "$$TEST" $(FILTERFILE_FORMULA)                                  \
	       $(CLANG_FRONTEND) $$EXTRA_FLAGS -Xclang -plugin -Xclang $$P              \
	       -Xclang -plugin-arg-$$P -Xclang -                                        \
	       -Xclang -plugin-arg-$$P -Xclang USE_TEMP_DIR_FOR_DEDUPLICATION=build/tmp_$$P \
	       -c $(SRCFILE_FORMULA);                                                   \
	   done;                                                                        \
	done
	@if [ ! $$KEEP_TEST_OUTPUTS ]; then rm -f $(OUT_TEST_FILES); fi

record-test-outputs:
	@$(MAKE) DEBUG=1 KEEP_TEST_OUTPUTS=1 test || true
	@for F in $(OUT_TEST_FILES); do cp $$F $${F%.out}.exp; done
	@rm -f $(OUT_TEST_FILES)

clean:
	@rm -rf build/* $(OUT_TEST_FILES)

# -- AST samples for specific end-to-end tests --

REGULAR_SOURCES=$(wildcard tests/*.m) $(wildcard tests/*.c) $(wildcard tests/*.cpp)
AST_SAMPLE_FILES=ASTExporter.cpp $(REGULAR_SOURCES:tests/%=%)
all_ast_samples: $(AST_SAMPLE_FILES:%=build/ast_samples/%.json.gz) $(AST_SAMPLE_FILES:%=build/ast_samples/%.yjson.gz)

# dump samples files in Yojson using ASTExporter.cpp
YJ_DUMPER_ARGS=-Xclang -plugin -Xclang YojsonASTExporter -Xclang -plugin-arg-YojsonASTExporter -Xclang

build/ast_samples/%.cpp.yjson: %.cpp build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(CFLAGS) -Wno-ignored-qualifiers -I. $(YJ_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.cpp.yjson: tests/%.cpp build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) --std=c++11 $(YJ_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.c.yjson: tests/%.c build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(YJ_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.m.yjson: tests/%.m build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(YJ_DUMPER_ARGS) $@ -c $<

# dump sample files in Yojson using ASTExporter.cpp
J_DUMPER_ARGS=-Xclang -plugin -Xclang JsonASTExporter -Xclang -plugin-arg-JsonASTExporter -Xclang

build/ast_samples/%.cpp.json: %.cpp build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(CFLAGS) -Wno-ignored-qualifiers -I. $(J_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.cpp.json: tests/%.cpp build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) --std=c++11 $(J_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.c.json: tests/%.c build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(J_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.m.json: tests/%.m build/FacebookClangPlugin.dylib
	@mkdir -p build/ast_samples
	@$(CLANG_FRONTEND) $(J_DUMPER_ARGS) $@ -c $<

build/ast_samples/%.gz: build/ast_samples/%
	@gzip -f -k $<

# generate a preprocessed version of ASTExporter.cpp where ATD directives can be read
# we do not include the C/C++ headers to avoid parsing issues with the 'traditional' cpp (needed for precisely expanding our /// comments)
build/ASTExporter.h.p: ASTExporter.h
	@mkdir -p build
	@cat $< | grep -v '#include *["<][^.]*\(\.h\)\?[">]' | $(ATD_CPP) -I$(CLANG_PREFIX)/include > $@
