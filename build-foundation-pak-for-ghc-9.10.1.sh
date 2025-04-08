set -x -e

foundationPak=`pwd`

unpack_ghc_source_code_and_add_hadrian_to_git() {(
  tar xf ghc-9.10.1-src.tar.xz

  cd ghc-9.10.1/hadrian
  git init
  set +e
  git add *
  git commit -am "original"
)}

patch_hadrian_source_code() {(
  cd ghc-9.10.1/hadrian
  git am < $foundationPak/patch/ghc-9.10.1/hadrian/0001-wpc-9.10.1.patch

  mkdir deps

  cd deps
  stack unpack Cabal-3.10.3.0
  git init
  set +e
  git add *
  git commit -am "original"
  set -e

  git am < $foundationPak/patch/ghc-9.10.1/Cabal-3.10.3.0/0001-wpc.patch
)}

build_stage2_ghc() {(
  # does not compile with ghc 9.10.1
  # let's try ghc 9.6.6 - it works ; USE THIS VERSION
  cd ghc-9.10.1
  ./boot.source
  ./configure
  hadrian/build-stack -j
)}

build_wpc_plugin_with_stage2_ghc() {(
  STAGE2_GHC=`pwd`/ghc-9.10.1/_build/stage1/bin/ghc
  git clone https://github.com/zlonast/ghc-whole-program-compiler-project.git
  cd ghc-whole-program-compiler-project/wpc-plugin
  git checkout 097745f5515178d44cbf84aea301b444945e9d89

  echo "packages: *.cabal external-stg-syntax" > cabal.project
  echo "with-compiler: $STAGE2_GHC" >> cabal.project

  # ghcup set 9.10.1
  cabal build
  # ghcup set 9.6.6
  ln -s `find . -type f -name 'libwpc-plugin.so' -o -name 'libwpc-plugin.dylib' -o -name 'libwpc-plugin.dll' | head -1`
)}

patch_hadrian_set_final_stage_to_stage3() {(
  cd ghc-9.10.1/hadrian
  git am < $foundationPak/patch/ghc-9.10.1/hadrian/0002-set-final-stage-to-stage3.patch
)}

build_stage3_ghc_with_wpc_plugin() {(
  WORK_DIR=`pwd`
  cd ghc-9.10.1
  WPC_PLUGIN_GHC_OPTS="stage2.*.ghc.*.opts += -fplugin-trustworthy -fplugin-library=$WORK_DIR/ghc-whole-program-compiler-project/wpc-plugin/libwpc-plugin.so;wpc-plugin-unit;WPC.Plugin;[]"
  hadrian/build-stack -j "$WPC_PLUGIN_GHC_OPTS"
  hadrian/build-stack -j foundation-pak --docs=none "$WPC_PLUGIN_GHC_OPTS"
)}

mkdir -p foundation-pak-ghc-9.10.1-wpc
cd foundation-pak-ghc-9.10.1-wpc

ghcup set ghc 9.6.6

### install_ghc_build_tools ###
cabal install --overwrite-policy=always alex-3.5.1.0 zip-cmd-1.0.1

### download_ghc_source_code ###
wget https://downloads.haskell.org/~ghc/9.10.1/ghc-9.10.1-src.tar.xz

unpack_ghc_source_code_and_add_hadrian_to_git
patch_hadrian_source_code
build_stage2_ghc
build_wpc_plugin_with_stage2_ghc
patch_hadrian_set_final_stage_to_stage3
build_stage3_ghc_with_wpc_plugin

ghcup set 9.10.1

echo "output foundation pak and ghc-9.10.1 wpc bindist"

ls -lah `pwd`/ghc-9.10.1/_build/foundation-pak/*.tar.*
ls -lah `pwd`/ghc-9.10.1/_build/bindist/ghc-9.10.1-x86_64-unknown-linux/bin/ghc
