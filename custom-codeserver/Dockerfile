# ---------- Base image ----------
ARG BASE_IMAGE=registry.redhat.io/rhoai/odh-workbench-codeserver-datascience-cpu-py311-rhel9@sha256:755f8dacf495f6abb29233edb422ca473ba82cc23370d4fcbaa4f938e90a9c25
FROM ${BASE_IMAGE}

# ---------- Version arguments ----------
ARG TINI_VERSION=0.19.0
ARG MAMBA_VERSION=1.5.8
ARG ENABLE_CUDA=true

USER root

# ---------- Install OS packages and tini ----------
RUN dnf -y install \
      diffutils nano krb5-workstation java-17-openjdk java-17-openjdk-devel maven && \
    curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 \
      -o /usr/bin/tini && chmod +x /usr/bin/tini && \
    dnf clean all && rm -rf /var/cache/dnf

RUN localedef -f UTF-8 -i en_US en_US.UTF-8 || true
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ---------- Copy JDBC driver ----------
COPY ojdbc17.jar /opt/java/ojdbc17.jar

#---------- Add code server extension -------------#
COPY --chown=1001:0 ./utils /opt/app-root/bin/utils/

# Create and install the extensions though build-time on a temporary directory. Later this directory will copied on the `/opt/app-root/src/.local/share/code-server/extensions` via run-code-server.sh file when it starts up.
RUN for ext in \
    "cweijan.dbclient-jdbc-1.4.2.vsix" \
    "ms-azuretools.vscode-containers-2.1.0.vsix" \
#    "ms-python.vscode-pylance-2025.8.1.vsix" \
    "cweijan.vscode-mysql-client2-8.4.2.vsix" \
    "ms-azuretools.vscode-docker-2.0.0.vsix" \
    "redhat.vscode-yaml-1.19.1.vsix" \
    "eamodio.gitlens-17.7.0.vsix" \
    "ms-mssql.mssql-1.9.0.vsix" \
    "yzhang.markdown-all-in-one-3.6.2.vsix" \

    ; do \
        code-server --extensions-dir /opt/app-root/extensions-temp --install-extension /opt/app-root/bin/utils/$ext || true ; \
    done

# ---------- Environment variables ----------
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk \
    PATH=$JAVA_HOME/bin:/opt/conda/envs/ds/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH \
    CLASSPATH=/opt/java/ojdbc17.jar:$CLASSPATH \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    MAMBA_ROOT_PREFIX=/opt/conda \
    MAMBA_EXE=/usr/local/bin/micromamba

#------------ Git configuration defaults -----------#
RUN git config --system --add safe.directory '*' && \
    git lfs install --system --skip-repo

# ---------- Install micromamba ----------
RUN curl -fsSL https://micromamba.snakepit.net/api/micromamba/linux-64/${MAMBA_VERSION} \
      | tar -xvjf - bin/micromamba && \
    mv bin/micromamba /usr/local/bin/micromamba && chmod +x /usr/local/bin/micromamba && \
    micromamba shell init -s bash -p ${MAMBA_ROOT_PREFIX} >/dev/null 2>&1 || true

COPY environment.yml /tmp/environment.yml

# ---------- Create ds environment ----------
RUN micromamba create -y -n ds -f /tmp/environment.yml && \
    micromamba run -n ds pip install --no-cache-dir \
      numpy pandas scipy scikit-learn matplotlib seaborn ipywidgets xgboost lightgbm black ruff && \
    if [ "${ENABLE_CUDA}" = "true" ]; then \
      micromamba run -n ds pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 torch torchvision; \
    else \
      micromamba run -n ds pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch torchvision; \
    fi && \
    micromamba run -n ds python -m ipykernel install --sys-prefix --name ds --display-name "Python (ds)" && \
    micromamba clean --all --yes

# ---------- Install project-specific dependencies (optional) ----------
COPY requirements.txt /tmp/requirements.txt
RUN if [ -s /tmp/requirements.txt ]; then \
      echo "Installing additional pip packages..." && \
      micromamba run -n ds pip install --no-cache-dir -r /tmp/requirements.txt; \
    else \
      echo "No requirements.txt found or empty, skipping."; \
    fi && \
    micromamba run -n ds pip cache purge || true && \
    micromamba clean --all --yes

# ---------- Permissions for OpenShift ----------

RUN chgrp -R 0 /opt/java /opt/conda && chmod -R g+rwX /opt/java /opt/conda

ENTRYPOINT ["/usr/bin/tini", "--"]
USER 1001
WORKDIR /opt/app-root/src
CMD ["/opt/app-root/bin/run-code-server.sh"]
