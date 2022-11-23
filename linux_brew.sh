#!/usr/bin/env bash
export USER_LOCAL=$HOME/.local
export CURL_VERSION=7.74.0
export GIT_VERSION=2.30.0
export BASH_PROFILE=$HOME/.bash_profile
wget https://curl.se/download/curl-$CURL_VERSION.tar.gz
wget https://github.com/git/git/archive/v$GIT_VERSION.tar.gz
tar xf curl-$CURL_VERSION.tar.gz
tar xf v$GIT_VERSION.tar.gz
cd curl-$CURL_VERSION
./configure --prefix=$USER_LOCAL
make install
cd git-$GIT_VERSION
make configure
./configure --prefix=$USER_LOCAL
make install
echo 'export PATH=$PATH:'$USER_LOCAL/bin >> $BASH_PROFILE
echo 'export HOMEBREW_DEVELOPER=1' >> $BASH_PROFILE
echo 'export HOMEBREW_CURL_PATH='$USER_LOCAL/bin/curl >> $BASH_PROFILE
echo 'export HOMEBREW_GIT_PATH='$USER_LOCAL/bin/git >> $BASH_PROFILE
source $BASH_PROFILE
