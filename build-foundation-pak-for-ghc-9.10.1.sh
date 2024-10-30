set -x -e

install_ghc_build_tools() {
  stack --resolver lts-20.24 install alex-3.5.1.0 zip-cmd-1.0.1
  read -p "install ghc 9.6.6 then press ENTER"
}

download_ghc_source_code() {
  wget https://downloads.haskell.org/~ghc/9.10.1/ghc-9.10.1-src.tar.xz
}

unpack_ghc_source_code_and_add_hadrian_to_git() {(
  tar xf ghc-9.10.1-src.tar.xz

  cd ghc-9.10.1/hadrian
  git init
  set +e
  git add *
  git commit -am "original"
)}

build_stage2_ghc() {(
  # does not compile with ghc 9.10.1
  # let's try ghc 9.6.6 - it works ; USE THIS VERSION
  cd ghc-9.10.1
  ./boot.source
  ./configure
  hadrian/build-stack -j
)}

patch_hadrian_source_code() {(
  cd ghc-9.10.1/hadrian
  git am < ../../../patch/ghc-9.10.1/hadrian/0001-wpc-9.10.1.patch

  mkdir deps

  cd deps
  stack unpack Cabal-3.10.3.0
  git init
  set +e
  git add *
  git commit -am "original"
  set -e

  git am < ../../../../patch/ghc-9.10.1/Cabal-3.10.3.0/0001-wpc.patch
)}

patch_hadrian_set_final_stage_to_stage3() {(
  cd ghc-9.10.1/hadrian
  git am < ../../../patch/ghc-9.10.1/hadrian/0002-set-final-stage-to-stage3.patch
)}

build_stage3_ghc_with_wpc_plugin() {(
  WORK_DIR=`pwd`
  cd ghc-9.10.1
  WPC_PLUGIN_GHC_OPTS="stage2.*.ghc.*.opts += -fplugin-trustworthy -fplugin-library=$WORK_DIR/ghc-whole-program-compiler-project/wpc-plugin/libwpc-plugin.so;wpc-plugin-unit;WPC.Plugin;[]"
  hadrian/build-stack -j "$WPC_PLUGIN_GHC_OPTS"
  hadrian/build-stack -j foundation-pak --docs=none "$WPC_PLUGIN_GHC_OPTS"
)}

todo_wpc_plugin_build(){
  # todo build wpc-plugin with stage1 ghc
  echo "TODO: checkout and build wpc-plugin with stage1 ghc"
  pwd
  echo "place it to /home/csaba/haskell/grin-compiler/ghc-whole-program-compiler-project/wpc-plugin/libwpc-plugin.so"
  read -p "Then press ENTER"
}

build_wpc_plugin_with_stage2_ghc() {(
  STAGE2_GHC=`pwd`/ghc-9.10.1/_build/stage1/bin/ghc
  git clone https://github.com/grin-compiler/ghc-whole-program-compiler-project.git
  cd ghc-whole-program-compiler-project/wpc-plugin
  # wpc-plugin for GHC 9.10.1
  git checkout b55126d3360346708ae0ae4abf82fa77adac7ce5

  echo "packages: *.cabal external-stg-syntax" > cabal.project
  echo "with-compiler: $STAGE2_GHC" >> cabal.project

  cabal build
  ln -s `find . -type f -name 'libwpc-plugin.so' -o -name 'libwpc-plugin.dylib' -o -name 'libwpc-plugin.dll' | head -1`
)}

mkdir -p foundation-pak-ghc-9.10.1-wpc
cd foundation-pak-ghc-9.10.1-wpc

install_ghc_build_tools
download_ghc_source_code
unpack_ghc_source_code_and_add_hadrian_to_git
patch_hadrian_source_code
build_stage2_ghc
build_wpc_plugin_with_stage2_ghc
patch_hadrian_set_final_stage_to_stage3
build_stage3_ghc_with_wpc_plugin

############
# output foundation pak and ghc-9.2.7-wpc bindist
############

ls -lah `pwd`/ghc-9.10.1/_build/foundation-pak/*.tar.*
