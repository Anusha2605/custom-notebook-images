#FROM registry.redhat.io/rhoai/odh-workbench-jupyter-minimal-cpu-py312-rhel9@sha256:a8cfef07ffc89d99acfde08ee879cc87aaa08e9a369e0cf7b36544b61b3ee3c7
FROM registry.redhat.io/rhoai/odh-workbench-jupyter-minimal-cpu-py311-rhel9@sha256:2b00a5b676b07d4fd6ab894d5dcaeb5bf88ef35bde76cbf3b4c0951987e5aad6
# Copying custom packages
COPY Pipfile.lock ./

# Install packages and cleanup
# (all commands are chained to minimize layer size)
RUN echo "Installing softwares and packages" && \
    # Install Python packages \
    micropipenv install && \
    rm -f ./Pipfile.lock \
    # Fix permissions to support pip in OpenShift environments \
    chmod -R g+w /opt/app-root/lib/python3.9/site-packages && \
    fix-permissions /opt/app-root -P

WORKDIR /opt/app-root/src

ENTRYPOINT ["start-notebook.sh"]
