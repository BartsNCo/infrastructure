FROM docker.io/unityci/editor:ubuntu-6000.0.50f1-linux-il2cpp-3.1.0

# Install additional dependencies if needed
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /unity-builder

# Copy entrypoint script
COPY entrypoint.sh /unity-builder/entrypoint.sh
RUN chmod +x /unity-builder/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/unity-builder/entrypoint.sh"]