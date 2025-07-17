# ultra-dev Dockerfile
FROM ubuntu:24.04

ARG USERNAME=jam
ARG UID=1000
ARG GID=1000
ARG PASSWORD=jam
ARG DEBIAN_FRONTEND=noninteractive

# Base OS + dev tooling
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        sudo locales \
        git curl wget ca-certificates gnupg2 \
        build-essential pkg-config \
        python3 python3-pip python3-venv python-is-python3 python3-dev \
        nodejs npm \
        openssh-server \
        bash-completion vim nano less \
        jq rsync iproute2 iputils-ping net-tools unzip zip \
        libssl-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# Locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Create admin user
RUN groupadd --gid ${GID} ${USERNAME} && \
    useradd --uid ${UID} --gid ${GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:${PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# SSH setup
RUN mkdir -p /var/run/sshd && \
    mkdir -p /home/${USERNAME}/.ssh && \
    chmod 700 /home/${USERNAME}/.ssh && \
    ssh-keygen -A && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# Optional: drop in your pubkey at build time
# COPY authorized_keys /home/${USERNAME}/.ssh/authorized_keys
# RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh/authorized_keys && chmod 600 /home/${USERNAME}/.ssh/authorized_keys

# Hostname env (actual hostname set at docker run)
ENV HOSTNAME=ultra

EXPOSE 22

# Dev-friendly defaults for jam
USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:${PATH} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
RUN python -m venv ~/.venv && echo 'source ~/.venv/bin/activate' >> ~/.bashrc
RUN npm config set prefix ~/.npm-global && echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> ~/.bashrc

# Back to root to launch sshd
USER root
CMD ["/usr/sbin/sshd","-D","-e"]
