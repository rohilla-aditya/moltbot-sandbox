FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 to /opt/node22 instead of overwriting /usr/local
ENV NODE_VERSION=22.13.1
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils ca-certificates rsync \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && mkdir -p /opt/node22 \
    && tar -xJf /tmp/node.tar.xz -C /opt/node22 --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && rm -rf /var/lib/apt/lists/*

# Put Node 22 first in PATH so clawdbot uses it, but don't remove base image's node
ENV PATH="/opt/node22/bin:$PATH"
RUN node --version && npm --version

# Install pnpm and clawdbot using Node 22
RUN npm install -g pnpm \
    && npm install -g clawdbot@2026.1.24-3 \
    && clawdbot --version

# Create directories
RUN mkdir -p /root/.clawdbot /root/.clawdbot-templates /root/clawd/skills

# Copy files
COPY start-moltbot.sh /usr/local/bin/start-moltbot.sh
RUN chmod +x /usr/local/bin/start-moltbot.sh
COPY moltbot.json.template /root/.clawdbot-templates/moltbot.json.template
COPY skills/ /root/clawd/skills/

WORKDIR /root/clawd
EXPOSE 18789

ENTRYPOINT ["/sandbox"]
CMD ["/usr/local/bin/start-moltbot.sh"]