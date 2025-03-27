#!/bin/sh

#set -e

CURRENT_DIR=$PWD
# locate
if [ -z "$BASH_SOURCE" ]; then
    SCRIPT_DIR=`dirname "$(readlink -f $0)"`
elif [ -e '/bin/zsh' ]; then
    F=`/bin/zsh -c "print -lr -- $BASH_SOURCE(:A)"`
    SCRIPT_DIR=`dirname $F`
elif [ -e '/usr/bin/realpath' ]; then
    F=`/usr/bin/realpath $BASH_SOURCE`
    SCRIPT_DIR=`dirname $F`
else
    F=$BASH_SOURCE
    while [ -h "$F" ]; do F="$(readlink $F)"; done
    SCRIPT_DIR=`dirname $F`
fi

cd $SCRIPT_DIR

build_example() {
    printf "\n$1:\n"
    cargo build --release --example $1 && \
    du -sh target/release/examples/$1
}

build_examples() {
    for F in $@; do build_example "${F%.*}"; done
}

cargo build --release && \
du -sh target/release/sqld && \
du -sh target/release/bottomless-cli && \
build_examples `ls libsql/examples`
