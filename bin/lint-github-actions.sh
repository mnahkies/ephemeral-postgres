#!/usr/bin/env bash

docker run -it --rm -v $PWD:/code ghcr.io/zizmorcore/zizmor:1.26.1@sha256:d1117e5dbd9ee4970644067b534ab6ab50371f3c6f7f4d05446eb603a6e78f48 --pedantic --fix /code

