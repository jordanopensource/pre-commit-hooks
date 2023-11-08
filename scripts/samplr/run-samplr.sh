#!/usr/bin/env bash

###############################
########### CREDITS: ##########
# https://github.com/unmultimedio/samplr#5-set-up-a-githook-optional
########## MODIFIED: ##########
# t.hamoudi
######### MAINTAINED: #########
#  admin@josa.ngo
###############################

###############################
# Prerequisites
# - samplr v0.2.1
###############################
###### INSTALLATION GUIDE #####
# https://github.com/unmultimedio/samplr/blob/master/INSTALL.md
###############################

set -e

# Run samplr command to generate sample files
samplr
# List all changed and not-ignored files, with a filename that matches with ".sample", and add it to the commit
git ls-files -mo --exclude-standard | grep "\.sample" | xargs git add
