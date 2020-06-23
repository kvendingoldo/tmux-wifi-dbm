#!/bin/bash

clear
while x=1
  do /System/Library/PrivateFrameworks/Apple*.framework/Versions/Current/Resources/airport -I \
    | grep CtlRSSI \
    | sed -e 's/^.*://g' \
    | xargs -I SIGNAL printf "\rSIGNAL"
  sleep 0.5
done
