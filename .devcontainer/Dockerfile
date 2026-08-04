# syntax=docker/dockerfile:1
#
# Base image for the Digital Twin dev container.
#
# This exists (instead of referencing the base image directly in
# devcontainer.json) because some devcontainer features install their
# tooling via `npm install` during the feature-installation build steps,
# which run *before* postCreateCommand executes. On networks where the
# public npm registry isn't reachable, those feature installs fail unless
# npm is already pointed at the internal package feed proxy by the time
# the feature scripts run. Setting the registry via ENV here guarantees it
# is in effect for every later build layer (including feature layers) and
# at container runtime, without depending on postCreateCommand timing.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV NPM_CONFIG_REGISTRY=https://packagefeedproxy.microsoft.io/npm/
ENV PIP_INDEX_URL=https://packagefeedproxy.microsoft.io/pypi/simple