# -----------------------------------------------------------------------------
#
# (c) 2009-2012 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://ghc.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://ghc.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Create compiler configuration
#
# The 'echo' commands simply spit the values of various make variables
# into Config.hs, whence they can be compiled and used by GHC itself

# This is just to avoid generating a warning when generating deps
# involving RtsFlags.h
compiler_stage1_MKDEPENDC_OPTS = -DMAKING_GHC_BUILD_SYSTEM_DEPENDENCIES
compiler_stage2_MKDEPENDC_OPTS = -DMAKING_GHC_BUILD_SYSTEM_DEPENDENCIES
compiler_stage3_MKDEPENDC_OPTS = -DMAKING_GHC_BUILD_SYSTEM_DEPENDENCIES

compiler_stage1_C_FILES_NODEPS = compiler/parser/cutils.c

# This package doesn't pass the Cabal checks because include-dirs
# points outside the source directory. This isn't a real problem, so
# we just skip the check.
compiler_NO_CHECK = YES

ifneq "$(BINDIST)" "YES"
compiler/main/Config.hs : rts/build/config.hs-incl

compiler/stage1/build/PlatformConstants.o: $(includes_GHCCONSTANTS_HASKELL_TYPE)
compiler/stage2/build/PlatformConstants.o: $(includes_GHCCONSTANTS_HASKELL_TYPE)
compiler/stage3/build/PlatformConstants.o: $(includes_GHCCONSTANTS_HASKELL_TYPE)
compiler/stage1/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_EXPORTS)
compiler/stage2/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_EXPORTS)
compiler/stage3/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_EXPORTS)
compiler/stage1/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_WRAPPERS)
compiler/stage2/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_WRAPPERS)
compiler/stage3/build/DynFlags.o: $(includes_GHCCONSTANTS_HASKELL_WRAPPERS)
endif

# -----------------------------------------------------------------------------
# Configuration

compiler_stage1_CONFIGURE_OPTS += --flags=stage1
compiler_stage2_CONFIGURE_OPTS += --flags=stage2
compiler_stage3_CONFIGURE_OPTS += --flags=stage3

ifeq "$(GhcThreaded)" "YES"
# We pass THREADED_RTS to the stage2 C files so that cbits/genSym.c will bring
# the threaded version of atomic_inc() into scope.
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-optc-DTHREADED_RTS
endif

ifeq "$(GhcWithNativeCodeGen)" "YES"
compiler_stage1_CONFIGURE_OPTS += --flags=ncg
compiler_stage2_CONFIGURE_OPTS += --flags=ncg
endif

ifeq "$(GhcWithInterpreter)" "YES"
compiler_stage2_CONFIGURE_OPTS += --flags=ghci

ifeq "$(GhcEnableTablesNextToCode) $(GhcUnregisterised)" "YES NO"
# Should GHCI be building info tables in the TABLES_NEXT_TO_CODE style
# or not?
# XXX This should logically be a CPP option, but there doesn't seem to
# be a flag for that
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DGHCI_TABLES_NEXT_TO_CODE
endif

# Should the debugger commands be enabled?
ifeq "$(GhciWithDebugger)" "YES"
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DDEBUGGER
endif

endif

ifeq "$(TargetOS_CPP)" "openbsd"
compiler_CONFIGURE_OPTS += --ld-options=-E
endif

ifeq "$(GhcUnregisterised)" "NO"
else
compiler_CONFIGURE_OPTS += --ghc-option=-DNO_REGS
endif

ifneq "$(GhcWithSMP)" "YES"
compiler_CONFIGURE_OPTS += --ghc-option=-DNOSMP
compiler_CONFIGURE_OPTS += --ghc-option=-optc-DNOSMP
endif

ifeq "$(WITH_TERMINFO)" "NO"
compiler_stage2_CONFIGURE_OPTS += --flags=-terminfo
endif

# Careful optimisation of the parser: we don't want to throw everything
# at it, because that takes too long and doesn't buy much, but we do want
# to inline certain key external functions, so we instruct GHC not to
# throw away inlinings as it would normally do in -O0 mode.
# Since GHC version 7.8, we need -fcmm-sink to be
# passed to the compiler. This is required on x86 to avoid the
# register allocator running out of stack slots when compiling this
# module with -fPIC -dynamic.
# See #8182 for all the details
compiler/stage1/build/Parser_HC_OPTS += -O0 -fno-ignore-interface-pragmas -fcmm-sink
compiler/stage2/build/Parser_HC_OPTS += -O0 -fno-ignore-interface-pragmas -fcmm-sink
compiler/stage3/build/Parser_HC_OPTS += -O0 -fno-ignore-interface-pragmas -fcmm-sink

ifeq "$(GhcProfiled)" "YES"
# If we're profiling GHC then we want SCCs.  However, adding -auto-all
# everywhere tends to give a hard-to-read profile, and adds lots of
# overhead.  A better approach is to proceed top-down; identify the
# parts of the compiler of interest, and then add further cost centres
# as necessary.  Turn on -fprof-auto for individual modules like this:

# compiler/main/DriverPipeline_HC_OPTS += -fprof-auto
compiler/main/GhcMake_HC_OPTS        += -fprof-auto
compiler/main/GHC_HC_OPTS            += -fprof-auto

# or alternatively add {-# OPTIONS_GHC -fprof-auto #-} to the top of
# modules you're interested in.

# We seem to still build the vanilla libraries even if we say
# --disable-library-vanilla, but installation then fails, as Cabal
# doesn't copy the vanilla .hi files, but ghc-pkg complains about
# their absence when we register the package. So for now, we just
# leave the vanilla libraries enabled.
# compiler_stage2_CONFIGURE_OPTS += --disable-library-vanilla
compiler_stage2_CONFIGURE_OPTS += --ghc-pkg-option=--force
endif

compiler_stage3_CONFIGURE_OPTS := $(compiler_stage2_CONFIGURE_OPTS)

compiler_stage1_CONFIGURE_OPTS += --ghc-option=-DSTAGE=1
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DSTAGE=2
compiler_stage3_CONFIGURE_OPTS += --ghc-option=-DSTAGE=3
compiler_stage2_HADDOCK_OPTS += --optghc=-DSTAGE=2

compiler/stage1/package-data.mk : compiler/ghc.mk
compiler/stage2/package-data.mk : compiler/ghc.mk
compiler/stage3/package-data.mk : compiler/ghc.mk

# -----------------------------------------------------------------------------
# And build the package

compiler_PACKAGE = ghc

# Don't do splitting for the GHC package, it takes too long and
# there's not much benefit.
compiler_stage1_SplitObjs = NO
compiler_stage2_SplitObjs = NO
compiler_stage3_SplitObjs = NO
compiler_stage1_SplitSections = NO
compiler_stage2_SplitSections = NO
compiler_stage3_SplitSections = NO

# if stage is set to something other than "1" or "", disable stage 1
# See Note [Stage1Only vs stage=1] in mk/config.mk.in.
ifneq "$(filter-out 1,$(stage))" ""
compiler_stage1_NOT_NEEDED = YES
endif
# if stage is set to something other than "2" or "", disable stage 2
ifneq "$(filter-out 2,$(stage))" ""
compiler_stage2_NOT_NEEDED = YES
endif
# stage 3 has to be requested explicitly with stage=3
ifneq "$(stage)" "3"
compiler_stage3_NOT_NEEDED = YES
endif
$(eval $(call build-package,compiler,stage1,0))
$(eval $(call build-package,compiler,stage2,1))
$(eval $(call build-package,compiler,stage3,2))

# We only want to turn keepCAFs on if we will be loading dynamic
# Haskell libraries with GHCi. We therefore filter the object file
# out for non-dynamic ways.
define keepCAFsForGHCiDynOnly
# $1 = stage
# $2 = way
ifeq "$$(findstring dyn, $2)" ""
compiler_stage$1_$2_C_OBJS := $$(filter-out %/keepCAFsForGHCi.$$($2_osuf),$$(compiler_stage$1_$2_C_OBJS))
endif
endef
$(foreach w,$(compiler_stage1_WAYS),$(eval $(call keepCAFsForGHCiDynOnly,1,$w)))
$(foreach w,$(compiler_stage2_WAYS),$(eval $(call keepCAFsForGHCiDynOnly,2,$w)))
$(foreach w,$(compiler_stage3_WAYS),$(eval $(call keepCAFsForGHCiDynOnly,3,$w)))

# after build-package, because that adds --enable-library-for-ghci
# to compiler_stage*_CONFIGURE_OPTS:
# We don't build the GHCi library for the ghc package. We can load it
# the .a file instead, and as object splitting isn't on for the ghc
# package this isn't much slower.However, not building the package saves
# a significant chunk of disk space.
compiler_stage1_CONFIGURE_OPTS += --disable-library-for-ghci
compiler_stage2_CONFIGURE_OPTS += --disable-library-for-ghci
compiler_stage3_CONFIGURE_OPTS += --disable-library-for-ghci

# after build-package, because that sets compiler_stage1_HC_OPTS:
ifeq "$(V)" "0"
compiler_stage1_HC_OPTS += $(filter-out -Rghc-timing,$(GhcHcOpts)) $(GhcStage1HcOpts)
compiler_stage2_HC_OPTS += $(filter-out -Rghc-timing,$(GhcHcOpts)) $(GhcStage2HcOpts)
compiler_stage3_HC_OPTS += $(filter-out -Rghc-timing,$(GhcHcOpts)) $(GhcStage3HcOpts)
else
compiler_stage1_HC_OPTS += $(GhcHcOpts) $(GhcStage1HcOpts)
compiler_stage2_HC_OPTS += $(GhcHcOpts) $(GhcStage2HcOpts)
compiler_stage3_HC_OPTS += $(GhcHcOpts) $(GhcStage3HcOpts)
endif

ifneq "$(BINDIST)" "YES"

$(compiler_stage1_depfile_haskell) : compiler/stage1/$(PLATFORM_H)
$(compiler_stage2_depfile_haskell) : compiler/stage2/$(PLATFORM_H)
$(compiler_stage3_depfile_haskell) : compiler/stage3/$(PLATFORM_H)

COMPILER_INCLUDES_DEPS += $(includes_H_CONFIG)
COMPILER_INCLUDES_DEPS += $(includes_H_PLATFORM)
COMPILER_INCLUDES_DEPS += $(includes_GHCCONSTANTS)
COMPILER_INCLUDES_DEPS += $(includes_GHCCONSTANTS_HASKELL_TYPE)
COMPILER_INCLUDES_DEPS += $(includes_GHCCONSTANTS_HASKELL_WRAPPERS)
COMPILER_INCLUDES_DEPS += $(includes_GHCCONSTANTS_HASKELL_EXPORTS)
COMPILER_INCLUDES_DEPS += $(includes_DERIVEDCONSTANTS)

$(compiler_stage1_depfile_haskell) : $(COMPILER_INCLUDES_DEPS) $(PRIMOP_BITS_STAGE1)
$(compiler_stage2_depfile_haskell) : $(COMPILER_INCLUDES_DEPS) $(PRIMOP_BITS_STAGE2)
$(compiler_stage3_depfile_haskell) : $(COMPILER_INCLUDES_DEPS) $(PRIMOP_BITS_STAGE3)

$(foreach way,$(compiler_stage1_WAYS),\
      compiler/stage1/build/PrimOp.$($(way)_osuf)) : $(PRIMOP_BITS_STAGE1)
$(foreach way,$(compiler_stage2_WAYS),\
      compiler/stage2/build/PrimOp.$($(way)_osuf)) : $(PRIMOP_BITS_STAGE2)
$(foreach way,$(compiler_stage3_WAYS),\
      compiler/stage3/build/PrimOp.$($(way)_osuf)) : $(PRIMOP_BITS_STAGE3)


# GHC itself doesn't know about the above dependencies, so we have to
# switch off the recompilation checker for that module:
compiler/prelude/PrimOp_HC_OPTS  += -fforce-recomp

ifeq "$(DYNAMIC_GHC_PROGRAMS)" "YES"
compiler/utils/Util_HC_OPTS += -DDYNAMIC_GHC_PROGRAMS
endif

endif
