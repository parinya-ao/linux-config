#!/bin/bash

nix-store --optimize

nix-collect-garbage -d
