#!/bin/bash

set -e

# ============================================
# 日志工具函数
# ============================================
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# ============================================
# CodeWiz Proxy 常量与路径
# ============================================
CODEWIZ_PROXY_SCRIPT="${CODEWIZ_PROXY_SCRIPT:-/Projects/DevBox/devbox/codewiz-proxy/proxy.py}"
CODEWIZ_PROXY_PID_FILE="/var/run/codewiz-proxy.pid"
CODEWIZ_PROXY_LOG_FILE="/var/log/codewiz-proxy.log"
CODEWIZ_PROFILE_SNIPPET="/etc/profile.d/devbox-codewiz.sh"
CODEWIZ_DEFAULT_API_KEY="QST2332f67caa6bdce8ae9fbd3524bdf2fa"

# ============================================
# CodeWiz Proxy 环境片段管理
# ============================================
write_codewiz_profile_snippet() {
    local resolved_port="$1"
    local resolved_key="$2"
    local escaped_key
    
    escaped_key="${resolved_key//\'/\'\"\'\"\'}"
    
    log_info "Writing CodeWiz Claude environment snippet to ${CODEWIZ_PROFILE_SNIPPET}..."
    mkdir -p "$(dirname "${CODEWIZ_PROFILE_SNIPPET}")"
    cat > "${CODEWIZ_PROFILE_SNIPPET}" <<EOF
export ANTHROPIC_BASE_URL="http://127.0.0.1:${resolved_port}"
export ANTHROPIC_API_KEY='${escaped_key}'
EOF
}

resolve_codewiz_api_key() {
    printf '%s\n' "${CODEWIZ_API_KEY:-${CODEWIZ_DEFAULT_API_KEY}}"
}

normalize_codewiz_proxy_env() {
    if [ -z "${CODEWIZ_TARGET_URL:-}" ]; then
        unset CODEWIZ_TARGET_URL
    fi
}

resolve_codewiz_proxy_port() {
    local candidate="${CODEWIZ_PROXY_PORT:-8088}"
    
    if [[ "${candidate}" =~ ^[0-9]+$ ]] && [ "${candidate}" -ge 1 ] && [ "${candidate}" -le 65535 ]; then
        printf '%s\n' "${candidate}"
        return 0
    fi
    
    return 1
}

export_codewiz_api_key() {
    local resolved_key
    resolved_key="$(resolve_codewiz_api_key)"
    export CODEWIZ_API_KEY="${resolved_key}"
    export ANTHROPIC_API_KEY="${resolved_key}"
}

clear_codewiz_profile_snippet() {
    if [ -f "${CODEWIZ_PROFILE_SNIPPET}" ]; then
        log_info "Removing CodeWiz Claude environment snippet from ${CODEWIZ_PROFILE_SNIPPET}..."
        rm -f "${CODEWIZ_PROFILE_SNIPPET}"
    fi
}

is_port_in_use() {
    local port="$1"
    
    if command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | awk 'NR>1 {print $4}' | grep -qE "[:.]${port}$"
        return $?
    fi
    
    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"${port}" -sTCP:LISTEN -P -n >/dev/null 2>&1
        return $?
    fi
    
    if command -v nc >/dev/null 2>&1; then
        nc -z 127.0.0.1 "${port}" >/dev/null 2>&1
        return $?
    fi
    
    return 1
}

start_codewiz_proxy() {
    local port
    
    if [ -z "${CODEWIZ_SESSION_TOKEN}" ]; then
        log_warn "CODEWIZ_SESSION_TOKEN is not set; skipping CodeWiz proxy startup."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    if [ -z "${CODEWIZ_USER_EMAIL}" ]; then
        log_warn "CODEWIZ_USER_EMAIL is not set; skipping CodeWiz proxy startup."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    if ! port="$(resolve_codewiz_proxy_port)"; then
        log_warn "CODEWIZ_PROXY_PORT must be a numeric TCP port; skipping CodeWiz proxy startup."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    if [ ! -f "${CODEWIZ_PROXY_SCRIPT}" ]; then
        log_warn "CodeWiz proxy script not found at ${CODEWIZ_PROXY_SCRIPT}; skipping startup."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    if is_port_in_use "${port}"; then
        log_warn "Port ${port} is already in use; skipping CodeWiz proxy startup."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    local resolved_key
    resolved_key="$(resolve_codewiz_api_key)"
    normalize_codewiz_proxy_env
    export_codewiz_api_key
    mkdir -p "$(dirname "${CODEWIZ_PROXY_PID_FILE}")"
    mkdir -p "$(dirname "${CODEWIZ_PROXY_LOG_FILE}")"
    
    log_info "Starting CodeWiz proxy on port ${port}..."
    python3 "${CODEWIZ_PROXY_SCRIPT}" --log-file "${CODEWIZ_PROXY_LOG_FILE}" &
    local proxy_pid=$!
    
    sleep 1
    if ! kill -0 "${proxy_pid}" >/dev/null 2>&1; then
        log_warn "CodeWiz proxy failed to start; skipping."
        clear_codewiz_profile_snippet
        return 0
    fi
    
    printf '%s\n' "${proxy_pid}" > "${CODEWIZ_PROXY_PID_FILE}"
    write_codewiz_profile_snippet "${port}" "${resolved_key}"
    log_info "CodeWiz proxy started (PID: ${proxy_pid})."
}

# ============================================
# SSH 服务管理
# ============================================
setup_ssh() {
    log_info "Setting up SSH service..."
    
    mkdir -p /var/run/sshd
    
    # Configure SSH if public key is provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        log_info "Configuring SSH public key authentication..."
        mkdir -p /root/.ssh
        echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
    fi
    
    # Start SSH daemon in background
    /usr/sbin/sshd -D &
    log_info "SSH service started on port 22"
}

# ============================================
# Git 配置
# ============================================
setup_git() {
    log_info "Configuring Git..."
    
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
        log_info "Git user.name set to: $GIT_USER_NAME"
    fi
    
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
        log_info "Git user.email set to: $GIT_USER_EMAIL"
    fi
    
    git config --global credential.helper store
}

# ============================================
# Code Server 版本管理
# ============================================
get_code_server_version() {
    local version_output
    local first_line
    
    version_output="$(code-server --version 2>/dev/null || true)"
    first_line="$(printf '%s\n' "${version_output}" | sed -n '1p')"
    
    if [[ "${first_line}" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    
    log_error "Unable to determine installed code-server version."
    printf '%s\n' "${version_output}" >&2
    return 1
}

resolve_latest_code_server_version() {
    local latest_release_url
    local resolved_version
    
    latest_release_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/coder/code-server/releases/latest)" || return 1
    resolved_version="${latest_release_url##*/}"
    resolved_version="${resolved_version#v}"
    
    if [ -z "${resolved_version}" ]; then
        log_error "Unable to resolve latest code-server version from ${latest_release_url}"
        return 1
    fi
    
    printf '%s\n' "${resolved_version}"
}

ensure_code_server_installed() {
    local requested_version="${CODE_SERVER_VERSION:-latest}"
    local resolved_version="${requested_version}"
    local installed_version=""
    local package_arch
    local deb_path
    local download_url
    
    if command -v code-server >/dev/null 2>&1; then
        installed_version="$(get_code_server_version || true)"
    fi
    
    if [ -z "${resolved_version}" ] || [ "${resolved_version}" = "latest" ]; then
        resolved_version="$(resolve_latest_code_server_version)" || {
            if [ -n "${installed_version}" ]; then
                log_warn "Falling back to installed code-server ${installed_version} because the latest version could not be resolved."
                return 0
            fi
            
            log_error "Unable to resolve the latest code-server version and no installed version is available."
            return 1
        }
    fi
    
    if [ "${installed_version}" = "${resolved_version}" ]; then
        log_info "code-server ${installed_version} is already installed"
        return 0
    fi
    
    package_arch="$(dpkg --print-architecture)"
    deb_path="/tmp/code-server_${resolved_version}_${package_arch}.deb"
    download_url="${CODE_SERVER_RELEASE_BASE_URL:-https://github.com/coder/code-server/releases/download}/v${resolved_version}/code-server_${resolved_version}_${package_arch}.deb"
    
    log_info "Installing code-server ${resolved_version}..."
    curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
        "${download_url}" \
        -o "${deb_path}"
    dpkg -i "${deb_path}"
    rm -f "${deb_path}"
    
    code-server --version >/dev/null
    log_info "code-server ${resolved_version} installed successfully"
}

# ============================================
# Code Server 配置与启动
# ============================================
setup_code_server_config() {
    log_info "Setting up code-server configuration..."
    
    mkdir -p /root/.config/code-server
    cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:${CODE_SERVER_PORT:-8080}
auth: ${CODE_SERVER_AUTH:-password}
password: ${CODE_SERVER_PASSWORD:-devbox}
cert: false
EOF
}

start_code_server() {
    log_info "Starting code-server on port ${CODE_SERVER_PORT:-8080}..."
    
    # Start code-server in background
    /usr/bin/code-server --config /root/.config/code-server/config.yaml /root/Projects &
    
    log_info "code-server started"
}

# ============================================
# 插件安装（后台异步执行）
# ============================================
get_code_version() {
    local version_output
    local version_lines
    local candidate
    
    version_output="$(code-server --version 2>/dev/null || true)"
    if [[ "${version_output}" =~ with[[:space:]]+Code[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    
    mapfile -t version_lines < <(printf '%s\n' "${version_output}")
    for ((candidate=${#version_lines[@]} - 1; candidate >= 0; candidate--)); do
        if [[ "${version_lines[${candidate}]}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done
    
    log_error "Unable to determine VS Code compatibility version from code-server --version output."
    printf '%s\n' "${version_output}" >&2
    return 1
}

resolve_compatible_marketplace_version() {
    local publisher="$1"
    local extension="$2"
    local code_version="$3"
    
    MARKETPLACE_PUBLISHER="${publisher}" \
    MARKETPLACE_EXTENSION="${extension}" \
    CODE_VERSION="${code_version}" \
    node <<'NODE'
const https = require('https');

const publisher = process.env.MARKETPLACE_PUBLISHER;
const extension = process.env.MARKETPLACE_EXTENSION;
const codeVersion = process.env.CODE_VERSION;

function requestJson(url, method = 'GET', body) {
    return new Promise((resolve, reject) => {
        const headers = {
            Accept: 'application/json;api-version=7.2-preview.1;excludeUrls=true',
        };

        if (body) {
            headers['Content-Type'] = 'application/json';
            headers['Content-Length'] = Buffer.byteLength(body);
        }

        const req = https.request(url, { method, headers }, (res) => {
            let data = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                data += chunk;
            });
            res.on('end', () => {
                if (res.statusCode < 200 || res.statusCode >= 300) {
                    reject(new Error(`request failed (${res.statusCode}) for ${url}`));
                    return;
                }

                try {
                    resolve(JSON.parse(data));
                } catch (error) {
                    reject(error);
                }
            });
        });

        req.on('error', reject);

        if (body) {
            req.write(body);
        }

        req.end();
    });
}

function parseVersion(version) {
    return version
        .replace(/-.*/, '')
        .split('.')
        .map((part) => Number.parseInt(part, 10) || 0);
}

function compareVersions(left, right) {
    const a = parseVersion(left);
    const b = parseVersion(right);
    const length = Math.max(a.length, b.length);

    for (let index = 0; index < length; index += 1) {
        const lhs = a[index] || 0;
        const rhs = b[index] || 0;

        if (lhs > rhs) {
            return 1;
        }

        if (lhs < rhs) {
            return -1;
        }
    }

    return 0;
}

function compareConstraint(version, constraint) {
    const match = constraint.match(/^(>=|<=|>|<|=)?\s*(\d+(?:\.\d+){0,2})$/);

    if (!match) {
        return false;
    }

    const operator = match[1] || '=';
    const target = match[2];
    const comparison = compareVersions(version, target);

    switch (operator) {
        case '>':
            return comparison > 0;
        case '>=':
            return comparison >= 0;
        case '<':
            return comparison < 0;
        case '<=':
            return comparison <= 0;
        case '=':
            return comparison === 0;
        default:
            return false;
    }
}

function satisfies(version, rangeExpression) {
    return rangeExpression
        .split('||')
        .map((part) => part.trim())
        .filter(Boolean)
        .some((range) => satisfiesSingle(version, range));
}

function satisfiesSingle(version, range) {
    if (range.startsWith('^')) {
        const base = range.slice(1).trim();
        const [major] = parseVersion(base);
        return compareVersions(version, base) >= 0 && compareVersions(version, `${major + 1}.0.0`) < 0;
    }

    if (range.startsWith('~')) {
        const base = range.slice(1).trim();
        const [major, minor] = parseVersion(base);
        return compareVersions(version, base) >= 0 && compareVersions(version, `${major}.${minor + 1}.0`) < 0;
    }

    const constraints = range.split(/\s+/).filter(Boolean);
    if (constraints.length > 1) {
        return constraints.every((constraint) => compareConstraint(version, constraint));
    }

    return compareConstraint(version, range);
}

async function main() {
    const body = JSON.stringify({
        filters: [
            {
                criteria: [
                    {
                        filterType: 7,
                        value: `${publisher}.${extension}`,
                    },
                ],
            },
        ],
        flags: 103,
    });

    const response = await requestJson('https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery', 'POST', body);
    const versions = response.results?.[0]?.extensions?.[0]?.versions || [];

    for (let index = 0; index < versions.length; index += 10) {
        const batch = versions.slice(index, index + 10);
        const manifests = await Promise.all(batch.map(async (version) => {
            const manifestFile = version.files?.find((file) => file.assetType === 'Microsoft.VisualStudio.Code.Manifest');
            if (!manifestFile) {
                return null;
            }

            const manifest = await requestJson(manifestFile.source);
            return {
                version: version.version,
                engineRange: manifest.engines?.vscode,
            };
        }));

        for (const manifest of manifests) {
            if (manifest?.engineRange && satisfies(codeVersion, manifest.engineRange)) {
                process.stdout.write(manifest.version);
                return;
            }
        }
    }

    console.error(`no compatible version found for ${publisher}.${extension} with Code ${codeVersion}`);
    process.exit(1);
}

main().catch((error) => {
    console.error(error.message);
    process.exit(1);
});
NODE
}

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
        log_error "Downloaded file is not a valid VSIX archive: ${vsix_path}"
        log_error "Download URL: ${url}"
        return 1
    fi
    
    code-server --install-extension "${vsix_path}" --force
    rm -f "${vsix_path}"
    code-server --list-extensions | grep -Fx "${extension_id}" >/dev/null
}

install_marketplace_vsix_for_code_version() {
    local publisher="$1"
    local extension="$2"
    local requested_version="$3"
    local extension_id="$4"
    local version="${requested_version}"
    
    if [ "${requested_version}" = "latest" ]; then
        local code_version
        
        code_version="$(get_code_version)" || return 1
        version="$(resolve_compatible_marketplace_version "${publisher}" "${extension}" "${code_version}")" || return 1
        log_info "Resolved ${extension_id} ${version} for Code ${code_version}"
    fi
    
    install_marketplace_vsix "${publisher}" "${extension}" "${version}" "${extension_id}"
}

install_openvsx_extension() {
    local extension_id="$1"
    
    code-server --install-extension "${extension_id}" --force
    code-server --list-extensions | grep -Fx "${extension_id}" >/dev/null
}

# 插件安装任务（在后台执行）
install_extensions_async() {
    log_info "Starting extension installation in background..."
    
    # Wait a bit for code-server to fully start
    sleep 5
    
    # OpenVSX 插件列表
    local openvsx_extensions=(
        "llvm-vs-code-extensions.vscode-clangd"
        "ms-vscode.cmake-tools"
        "eamodio.gitlens"
        "matepek.vscode-catch2-test-adapter"
        "mhutchie.git-graph"
        "ms-python.python"
        "github.vscode-pull-request-github"
        "yzhang.markdown-all-in-one"
        "ms-toolsai.jupyter"
        "streetsidesoftware.code-spell-checker"
        "ms-python.autopep8"
        "ms-azuretools.vscode-docker"
        "formulahendry.code-runner"
        "bierner.markdown-preview-github-styles"
        "bierner.markdown-mermaid"
        "ms-azuretools.vscode-containers"
        "ryuta46.multi-command"
        "vscode-icons-team.vscode-icons"
        "alefragnani.project-manager"
        "saoudrizwan.claude-dev"
        "wenfangdu.jump"
        "kylinideteam.cppdebug"
        "cweijan.vscode-ssh"
        "openai.chatgpt"
        "anthropic.claude-code"
        "moonshot-ai.kimi-code"
    )
    
    # 安装 OpenVSX 插件
    for extension_id in "${openvsx_extensions[@]}"; do
        log_info "Installing extension: ${extension_id}..."
        if install_openvsx_extension "${extension_id}"; then
            log_info "Successfully installed: ${extension_id}"
        else
            log_warn "Failed to install: ${extension_id}"
        fi
    done
    
    # 安装 Marketplace 插件（CodeWiz）
    local codewiz_version="${CODEWIZ_VERSION:-latest}"
    log_info "Installing CodeWiz extension..."
    if install_marketplace_vsix_for_code_version "felvin" "codewiz" "${codewiz_version}" "felvin.codewiz"; then
        log_info "Successfully installed: felvin.codewiz"
    else
        log_warn "Failed to install: felvin.codewiz"
    fi
    
    log_info "Extension installation completed!"
}

# ============================================
# 主函数
# ============================================
main() {
    log_info "=========================================="
    log_info "Starting DevBox services..."
    log_info "=========================================="
    
    # 1. 启动 SSH 服务
    setup_ssh
    
    # 2. 配置 Git
    setup_git
    
    # 3. 确保 code-server 已安装
    ensure_code_server_installed
    
    # 4. 配置 code-server
    setup_code_server_config
    
    # 5. 启动 code-server（后台）
    start_code_server
    
    # 6. 启动 CodeWiz proxy（如配置）
    start_codewiz_proxy
    local codewiz_status="skipped"
    local codewiz_port=""
    if [ -f "${CODEWIZ_PROFILE_SNIPPET}" ]; then
        codewiz_status="enabled"
        if codewiz_port="$(resolve_codewiz_proxy_port)"; then
            codewiz_status="enabled (port ${codewiz_port})"
        fi
    fi
    
    # 7. 在后台异步安装插件（避免阻碍服务访问）
    install_extensions_async &
    local install_pid=$!
    log_info "Extension installation running in background (PID: ${install_pid})"
    
    log_info "=========================================="
    log_info "All services started successfully!"
    log_info "SSH: port 22"
    log_info "Code Server: port ${CODE_SERVER_PORT:-8080}"
    log_info "CodeWiz proxy: ${codewiz_status}"
    log_info "=========================================="
    
    # 8. 保持容器运行，等待所有后台进程
    wait
}

# 执行主函数
main "$@"
