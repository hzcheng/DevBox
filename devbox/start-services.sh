#!/bin/bash

# Start SSH service
mkdir -p /var/run/sshd

# Configure SSH if public key is provided
if [ -n "$SSH_PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi

/usr/sbin/sshd -D &

# Configure code-server
mkdir -p /root/.config/code-server
cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: ${CODE_SERVER_AUTH:-password}
password: ${CODE_SERVER_PASSWORD:-devbox}
cert: false
EOF

# Start code-server
# Try multiple possible locations for code-server
/usr/bin/code-server --config /root/.config/code-server/config.yaml /root/Projects &

# Keep container running
wait
