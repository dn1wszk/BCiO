#!/usr/bin/env bash

dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
progdir=$(readlink -f $dir/circuit-synthesis/.cabal-sandbox/bin)

$progdir/circuit-synthesis $@
