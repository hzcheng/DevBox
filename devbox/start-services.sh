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

install_marketplace_vsix() {
    local publisher="$1"
    local extension="$2"
    local version="$3"
    local extension_id="$4"
    local publisher_host
    local vsix_path
    local url

    publisher_host="$(printf '%s' "${publisher}" | tr '[:upper:]' '[:lower:]')"
    vsix_path="/tmp/${publisher_host}.${extension}-${version}.vsix"
    url="https://${publisher_host}.gallery.vsassets.io/_apis/public/gallery/publisher/${publisher}/extension/${extension}/${version}/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage?redirect=true"

    curl -fL --retry 3 --retry-all-errors --connect-timeout 15 --max-time 300 \
        "${url}" \
        -o "${vsix_path}"

    if [ "$(head -c 2 "${vsix_path}")" != "PK" ]; then
        echo "downloaded file is not a valid VSIX archive: ${vsix_path}" >&2
        echo "download url: ${url}" >&2
        exit 1
    fi

    code-server --install-extension "${vsix_path}"
    rm -f "${vsix_path}"
    code-server --list-extensions | grep -Fx "${extension_id}" >/dev/null
}

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
code-server --install-extension openai.chatgpt
code-server --install-extension anthropic.claude-code

# CodeWiz is published on the VS Code Marketplace, so install it from VSIX.
CODEWIZ_VERSION="${CODEWIZ_VERSION:-0.0.2}"
install_marketplace_vsix "felvin" "codewiz" "${CODEWIZ_VERSION}" "felvin.codewiz"

# GitHub Copilot extensions are published on the VS Code Marketplace.
COPILOT_VERSION="${COPILOT_VERSION:-latest}"
COPILOT_CHAT_VERSION="${COPILOT_CHAT_VERSION:-latest}"
install_marketplace_vsix "GitHub" "copilot" "${COPILOT_VERSION}" "GitHub.copilot"
install_marketplace_vsix "GitHub" "copilot-chat" "${COPILOT_CHAT_VERSION}" "GitHub.copilot-chat"

# Keep container running
wait
