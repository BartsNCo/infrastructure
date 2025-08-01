FROM unityci/hub:ubuntu-3.1.0

# Install Unity Editor 6000.0.54f1
RUN unity-hub install --version 6000.0.54f1

# Install WebGL and Android modules
RUN unity-hub install-modules --version 6000.0.54f1 --cm -m webgl android

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    openssh-client \
    unzip \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

# Set working directory
WORKDIR /unity-builder

# Setup SSH and clone Unity project
RUN mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

# Copy SSH private key and clone repository
COPY unity-builder-key /tmp/unity-builder-key
RUN chmod 600 /tmp/unity-builder-key && \
    eval "$(ssh-agent -s)" && \
    ssh-add /tmp/unity-builder-key && \
    git clone -b dev git@github.com:BartsNCo/Unity.git /unity-project && \
    rm -rf /unity-project/.git && \
    rm -f /tmp/unity-builder-key && \
    chown -R root:root /unity-project && \
    chmod -R 755 /unity-project

# Copy Unity license file
COPY Unity_lic.ulf /root/.local/share/unity3d/Unity/Unity_lic.ulf

# Copy entrypoint script
COPY entrypoint.sh /unity-builder/entrypoint.sh
RUN chmod +x /unity-builder/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/unity-builder/entrypoint.sh"]
