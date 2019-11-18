#!/bin/bash

program=$1

if [[ -f "$program" ]]; then
    perl -Mlib=./local/lib/perl5 "$@"
fi


