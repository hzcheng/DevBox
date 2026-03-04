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

# Configure Git identity from environment variables
if [ -n "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi
git config --global credential.helper store

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

# Install code server extensions
code-server --install-extension llvm-vs-code-extensions.vscode-clangd
code-server --install-extension ms-vscode.cmake-tools
code-server --install-extension eamodio.gitlens
code-server --install-extension matepek.vscode-catch2-test-adapter
code-server --install-extension mhutchie.git-graph
code-server --install-extension ms-python.python
code-server --install-extension github.vscode-pull-request-github
code-server --install-extension llvm-vs-code-extensions.vscode-clangd
code-server --install-extension yzhang.markdown-all-in-one
code-server --install-extension ms-toolsai.jupyter
code-server --install-extension streetsidesoftware.code-spell-checker
code-server --install-extension ms-python.autopep8
code-server --install-extension ms-azuretools.vscode-docker
code-server --install-extension formulahendry.code-runner
code-server --install-extension bierner.markdown-preview-github-styles
code-server --install-extension bierner.markdown-mermaid
code-server --install-extension ms-azuretools.vscode-containers
code-server --install-extension ryuta46.multi-command
code-server --install-extension vscode-icons-team.vscode-icons
code-server --install-extension alefragnani.project-manager
code-server --install-extension saoudrizwan.claude-dev
code-server --install-extension wenfangdu.jump   
code-server --install-extension kylinideteam.cppdebug
code-server --install-extension cweijan.vscode-ssh

# Keep container running
wait
