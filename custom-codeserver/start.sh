#!/usr/bin/env bash
#
# start.sh
#
# Runtime entrypoint for OpenShift AI / RHOAI Workbench.
#
# Goals:
# - Run ONLY code-server (no JupyterLab) as the main service.
# - Bind code-server to port 8888 so OpenShift AI liveness/readiness probes
#   (which expect GET / on 8888) see HTTP 200/302 instead of 404 and mark pod Healthy.
# - Be safe under arbitrary UID (random UID with GID 0).
# - Handle cases where /opt/app-root/src is NOT writable (fallback to /tmp/home).
# - Do not attempt chmod/chgrp at runtime (will fail on root-squashed PVCs).
#
# PVC strategy:
# - In OpenShift AI Workbench, mount your PersistentVolumeClaim at
#   /opt/app-root/workspace
#   This keeps /opt/app-root/src (our default HOME) free and writable for config.
# - Users can store notebooks, code, and data in /opt/app-root/workspace,
#   which is backed by PVC and persists across pod restarts.
#
set -euo pipefail

CODE_PORT="${CODE_PORT:-8888}"
BIND_ADDR="${BIND_ADDR:-0.0.0.0}"

# PRIMARY_HOME defaults to /opt/app-root/src (baked in Dockerfile ENV)
PRIMARY_HOME="${HOME:-/opt/app-root/src}"

# Choose a runtime home directory that is writable.
# If /opt/app-root/src is writable, use it.
# If not (e.g. it's backed by a root-squashed volume), fall back to /tmp/home.
if [ -w "${PRIMARY_HOME}" ]; then
    RUNTIME_HOME="${PRIMARY_HOME}"
else
    RUNTIME_HOME="/tmp/home"
    export HOME="${RUNTIME_HOME}"
    mkdir -p "${RUNTIME_HOME}"
    chmod 700 "${RUNTIME_HOME}" || true
fi

# Ensure the workspace dir exists. This is where PVC should be mounted
# in OpenShift AI Workbench configuration.
mkdir -p /opt/app-root/workspace || true

# code-server stores user config, caches, extensions under $HOME by default.
USER_DATA_DIR="${HOME}/.local/share/code-server"
EXT_DIR="${HOME}/.local/share/code-server/extensions"
mkdir -p "${USER_DATA_DIR}" "${EXT_DIR}" || true

echo "==== OpenShift AI VS Code Workbench ===="
echo "Timestamp: $(date)"
echo "Running as UID: $(id -u) / GID(s): $(id -G)"
echo "HOME=${HOME}"
echo "Workspace (PVC mount point) => /opt/app-root/workspace"
echo "code-server bind ${BIND_ADDR}:${CODE_PORT}"
echo "========================================"

# Launch code-server in the foreground as PID 1 (tini execs this script).
# --auth none: OpenShift AI will front this with oauth-proxy for auth.
# If you run this image outside OpenShift AI, you can set your own auth by
# overriding the CMD / env vars.
exec code-server \
  --bind-addr "${BIND_ADDR}:${CODE_PORT}" \
  --auth none \
  --user-data-dir "${USER_DATA_DIR}" \
  --extensions-dir "${EXT_DIR}" \
  --app-name "OpenShift AI VS Code" \
  2>&1
