#!/bin/bash

set -eo pipefail

# Dev user configuration (passed via environment from docker-compose)
DEV_USER="${DEV_USER:-root}"
DEV_HOME="${DEV_HOME:-/root}"
DEV_GRANT_SUDO="${DEV_GRANT_SUDO:-false}"

# Global code-server command: wrap with gosu when running as non-root so that
# all callers (start, restart, install_extensions) use the same identity.
if [ "${DEV_USER}" != "root" ]; then
    CODE_SERVER_CMD="gosu ${DEV_USER} code-server"
else
    CODE_SERVER_CMD="code-server"
fi

CODE_SERVER_PID=""
CODE_SERVER_PIDFILE="/var/run/code-server.pid"

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

# ============================================
# 开发用户初始化
# ============================================
setup_dev_user() {
    [ "${DEV_USER}" = "root" ] && return 0

    log_info "Setting up dev user: ${DEV_USER} (home: ${DEV_HOME})"

    # Ensure home directory exists (volume may be empty on first run)
    mkdir -p "${DEV_HOME}"

    # First-boot only: recursively fix ownership of pre-existing root-owned files.
    # The sentinel lives outside the volume so it survives image rebuilds but not
    # volume resets, which is exactly when a full chown-R is needed again.
    local sentinel="/var/lib/devbox-initialized-${DEV_USER}"
    if [ ! -f "${sentinel}" ]; then
        log_info "First boot: fixing ownership of ${DEV_HOME} recursively (this may take a moment)..."
        # Use find to skip read-only bind mounts (e.g. ~/.ssh mounted with :ro).
        find "${DEV_HOME}" -mount -exec chown "${DEV_USER}:${DEV_USER}" {} + 2>/dev/null || true
        touch "${sentinel}"
        log_info "Ownership fixed. Subsequent boots will skip this step."
    else
        # Subsequent boots: ensure just the top-level home dir has correct ownership.
        chown "${DEV_USER}:${DEV_USER}" "${DEV_HOME}"
    fi

    # Ensure projects directory exists and is owned by the dev user
    mkdir -p "${DEV_HOME}/projects"
    chown "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/projects"

    # Populate shell dotfiles from /etc/skel if missing (volume mount wipes them).
    for skel_file in /etc/skel/.*; do
        [ -f "${skel_file}" ] || continue
        dest="${DEV_HOME}/${skel_file##/etc/skel/}"
        if [ ! -e "${dest}" ]; then
            cp "${skel_file}" "${dest}"
            chown "${DEV_USER}:${DEV_USER}" "${dest}"
        fi
    done

    # Inject devbox prompt into ~/.bashrc if not already present.
    # /etc/profile.d/ only runs for login shells; VS Code terminals are non-login interactive,
    # so we source the prompt script from ~/.bashrc instead.
    local bashrc="${DEV_HOME}/.bashrc"
    if [ -f "${bashrc}" ] && ! grep -q 'devbox-prompt' "${bashrc}"; then
        printf '\n# devbox prompt (git branch + newline)\n[ -f /etc/profile.d/devbox-prompt.sh ] && . /etc/profile.d/devbox-prompt.sh\n' >> "${bashrc}"
        chown "${DEV_USER}:${DEV_USER}" "${bashrc}"
    fi

    # Symlink global tmux.conf into user home (Dockerfile copies it to /etc/tmux.conf)
    if [ -f /etc/tmux.conf ] && [ ! -e "${DEV_HOME}/.tmux.conf" ]; then
        ln -sf /etc/tmux.conf "${DEV_HOME}/.tmux.conf"
        chown -h "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.tmux.conf"
    fi

    # Add dev user to the docker group using the host socket's actual GID.
    # The GID is host-specific and unknown at image build time, so we handle it here.
    # We add docker as a supplementary group AND inject a newgrp call into ~/.bashrc so
    # that every new terminal (including VS Code integrated terminals, which are forked
    # from a process that predates this setup) automatically re-enters the docker group.
    local docker_gid
    docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)
    if [ -n "${docker_gid}" ] && [ "${docker_gid}" != "0" ]; then
        groupadd --gid "${docker_gid}" docker 2>/dev/null || true
        usermod -aG docker "${DEV_USER}" 2>/dev/null || true
        log_info "Added ${DEV_USER} to docker group (gid=${docker_gid})"

        # Inject newgrp into ~/.bashrc so every new terminal picks up the docker group.
        # Without this, VS Code terminals inherit the process groups from vscode-server,
        # which was started before setup_dev_user ran and does not have docker in its groups.
        local bashrc="${DEV_HOME}/.bashrc"
        if [ -f "${bashrc}" ] && ! grep -q 'newgrp docker' "${bashrc}"; then
            printf '\n# Re-enter docker group so VS Code terminals can access /var/run/docker.sock\nif ! id -nG 2>/dev/null | grep -qw docker; then exec newgrp docker; fi\n' >> "${bashrc}"
            chown "${DEV_USER}:${DEV_USER}" "${bashrc}"
            log_info "Injected newgrp docker into ${bashrc}"
        fi
    fi

}

# ============================================
# 旧环境变量兼容性警告
# ============================================
_warn_deprecated_env_vars() {
    local deprecated_vars=""
    for var in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL OPENAI_API_KEY OPENAI_BASE_URL; do
        if [ -n "${!var:-}" ]; then
            deprecated_vars="${deprecated_vars}${deprecated_vars:+, }${var}"
        fi
    done
    if [ -n "$deprecated_vars" ]; then
        log_warn "检测到已弃用的环境变量: ${deprecated_vars}"
        log_warn "Claude Code / Codex 的 endpoint 配置已迁移到 cc-switch，请通过以下命令管理："
        log_warn "  cc-switch provider list          # 查看可用 provider"
        log_warn "  cc-switch provider switch <id>   # 切换 provider"
        log_warn "  cc-switch provider add           # 添加自定义 provider"
        log_warn "如需持久化自定义 provider，请修改 devbox/config/cc-switch/providers-patch.sql"
    fi
}

# ============================================
# cc-switch provider 配置（codewiz-proxy 模型切换）
# ============================================
setup_cc_switch_providers() {
    local db="${DEV_HOME}/.cc-switch/cc-switch.db"
    local patch="/usr/local/share/cc-switch-providers.sql"

    if [ ! -f "$patch" ]; then
        log_warn "cc-switch provider patch not found at ${patch}, skipping"
        return 0
    fi

    # Initialize cc-switch DB if missing (run as dev user to avoid root-owned files)
    if [ ! -f "$db" ]; then
        mkdir -p "$(dirname "$db")"
        if [ "${DEV_USER}" != "root" ] && command -v gosu >/dev/null 2>&1; then
            gosu "${DEV_USER}" cc-switch provider list > /dev/null 2>&1 || true
            chown -R "${DEV_USER}:${DEV_USER}" "$(dirname "$db")"
        else
            cc-switch provider list > /dev/null 2>&1 || true
            chown -R "${DEV_USER}:${DEV_USER}" "$(dirname "$db")"
        fi
    fi

    # Apply provider patch (INSERT OR IGNORE, preserves existing records including is_current)
    if [ -f "$db" ]; then
        if _CC_SWITCH_DB="$db" _CC_SWITCH_PATCH="$patch" python3 -c "
import sqlite3, sys, os
try:
    db = os.environ['_CC_SWITCH_DB']
    patch = os.environ['_CC_SWITCH_PATCH']
    conn = sqlite3.connect(db)
    with open(patch, encoding='utf-8') as f:
        conn.executescript(f.read())
    conn.commit()
    conn.close()
except Exception as e:
    print(f'[cc-switch] ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"; then
            log_info "cc-switch providers configured"
        else
            log_warn "Failed to apply cc-switch provider patch"
        fi
    fi
}

# ============================================
# Tmux 插件安装（session 持久化，运行时下载无需重建镜像）
# ============================================
setup_tmux_plugins() {
    local tmux_dir="${DEV_HOME}/.tmux"
    local tmux_plugins_dir="${tmux_dir}/plugins"
    mkdir -p "${tmux_plugins_dir}"

    # Sync tmux.conf from the bind-mounted repo so changes don't require image rebuild.
    # The repo is mounted at ${DEV_HOME}/projects/DevBox via docker-compose.
    local repo_tmux_conf="${DEV_HOME}/projects/DevBox/devbox/tmux.conf"
    if [ -f "${repo_tmux_conf}" ]; then
        cp -f "${repo_tmux_conf}" /etc/tmux.conf
        log_info "Synced tmux.conf from repo"
    fi

    install_tmux_plugin() {
        local repo_name="$1"
        local plugin_dir="${tmux_plugins_dir}/${repo_name}"
        if [ -d "${plugin_dir}/.git" ]; then
            return 0
        fi

        log_info "Installing tmux plugin: ${repo_name}"
        local base_url="https://github.com/tmux-plugins"
        if git clone --depth=1 "${base_url}/${repo_name}.git" "${plugin_dir}" 2>/dev/null; then
            return 0
        elif git clone --depth=1 "https://ghp.ci/${base_url}/${repo_name}.git" "${plugin_dir}" 2>/dev/null; then
            return 0
        else
            log_warn "Failed to install tmux plugin: ${repo_name}. Session persistence will not be available."
            rm -rf "${plugin_dir}"
            return 0
        fi
    }

    install_tmux_plugin "tpm" || true
    install_tmux_plugin "tmux-resurrect" || true
    install_tmux_plugin "tmux-continuum" || true

    # Ensure the entire ~/.tmux tree is owned by dev user so resurrect/continuum
    # can create ~/.tmux/resurrect/ and write save files.
    if [ "${DEV_USER}" != "root" ] && [ -d "${tmux_dir}" ]; then
        chown -R "${DEV_USER}:${DEV_USER}" "${tmux_dir}"
    fi
}

# ============================================
# SSH 服务管理
# ============================================
setup_ssh() {
    log_info "Setting up SSH service..."

    mkdir -p /var/run/sshd

    # Configure SSH public key for the dev user (root or non-root)
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        log_info "Configuring SSH public key authentication for ${DEV_USER}..."
        mkdir -p "${DEV_HOME}/.ssh"
        echo "$SSH_PUBLIC_KEY" > "${DEV_HOME}/.ssh/authorized_keys"
        chmod 700 "${DEV_HOME}/.ssh"
        chmod 600 "${DEV_HOME}/.ssh/authorized_keys"
        if [ "${DEV_USER}" != "root" ]; then
            chown -R "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.ssh"
        fi
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

    # Run as dev user so ~/.gitconfig lands in DEV_HOME. Use a single subshell to
    # avoid forking gosu once per config key.
    local as_dev_user=""
    [ "${DEV_USER}" != "root" ] && as_dev_user="gosu ${DEV_USER}"

    ${as_dev_user} bash -c "
        [ -n '${GIT_USER_NAME}' ]  && git config --global user.name  '${GIT_USER_NAME}'
        [ -n '${GIT_USER_EMAIL}' ] && git config --global user.email '${GIT_USER_EMAIL}'
        git config --global init.defaultBranch main
        git config --global credential.helper store
    "
    [ -n "${GIT_USER_NAME}" ]  && log_info "Git user.name set to: ${GIT_USER_NAME}"
    [ -n "${GIT_USER_EMAIL}" ] && log_info "Git user.email set to: ${GIT_USER_EMAIL}"
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
    curl -fL --connect-timeout 20 --max-time 3600 --retry 10 --retry-delay 5 --retry-all-errors -C - \
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

    local config_dir="${DEV_HOME}/.config/code-server"
    mkdir -p "${config_dir}"
    cat > "${config_dir}/config.yaml" <<EOF
bind-addr: 0.0.0.0:${CODE_SERVER_PORT:-8080}
auth: ${CODE_SERVER_AUTH:-password}
password: ${CODE_SERVER_PASSWORD:-devbox}
cert: false
EOF
    if [ "${DEV_USER}" != "root" ]; then
        chown -R "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.config"
    fi
}

start_code_server() {
    log_info "Starting code-server on port ${CODE_SERVER_PORT:-8080}..."

    local config="${DEV_HOME}/.config/code-server/config.yaml"
    local workdir="${DEV_HOME}/projects"

    if [ "${DEV_USER}" != "root" ]; then
        # Use login shell (su -) so code-server and its spawned terminals run under
        # a complete session (correct USER, HOME, groups, PATH).
        # Prepend .local/bin via env so pip-installed CLIs are available.
        su - "${DEV_USER}" -c "PATH='${DEV_HOME}/.local/bin:\$PATH' /usr/bin/code-server --config '${config}' '${workdir}'" &
    else
        /usr/bin/code-server --config "${config}" "${workdir}" &
    fi
    CODE_SERVER_PID=$!
    echo "${CODE_SERVER_PID}" > "${CODE_SERVER_PIDFILE}"
    log_info "code-server started (PID: ${CODE_SERVER_PID})"
}

stop_code_server() {
    # Read PID from file if the in-memory variable is stale (e.g. called from a subshell)
    if [ -z "${CODE_SERVER_PID}" ] && [ -f "${CODE_SERVER_PIDFILE}" ]; then
        CODE_SERVER_PID="$(cat "${CODE_SERVER_PIDFILE}")"
    fi
    if [ -z "${CODE_SERVER_PID}" ] || ! kill -0 "${CODE_SERVER_PID}" 2>/dev/null; then
        return 0
    fi

    log_info "Stopping code-server (PID: ${CODE_SERVER_PID})..."
    kill "${CODE_SERVER_PID}" 2>/dev/null || true
    wait "${CODE_SERVER_PID}" 2>/dev/null || true
    CODE_SERVER_PID=""
    rm -f "${CODE_SERVER_PIDFILE}"
}

restart_code_server() {
    stop_code_server
    start_code_server
}

is_code_server_auto_update_enabled() {
    local enabled="${CODE_SERVER_AUTO_UPDATE:-true}"

    case "${enabled}" in
        1|true|TRUE|yes|YES|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_and_update_code_server() {
    local requested_version="${CODE_SERVER_VERSION:-latest}"
    local installed_version=""
    local resolved_version="${requested_version}"

    if command -v code-server >/dev/null 2>&1; then
        installed_version="$(get_code_server_version || true)"
    fi

    if [ -z "${resolved_version}" ] || [ "${resolved_version}" = "latest" ]; then
        resolved_version="$(resolve_latest_code_server_version)" || {
            log_warn "Skipping code-server update check because the latest version could not be resolved."
            return 0
        }
    fi

    if [ "${installed_version}" = "${resolved_version}" ]; then
        log_info "code-server ${installed_version} is already up to date"
        return 0
    fi

    log_info "Updating code-server from ${installed_version:-not installed} to ${resolved_version}"
    ensure_code_server_installed || return 1
    restart_code_server
}

code_server_update_loop() {
    local initial_delay="${CODE_SERVER_UPDATE_INITIAL_DELAY_SECONDS:-300}"
    local interval="${CODE_SERVER_UPDATE_INTERVAL_SECONDS:-86400}"

    if ! [[ "${initial_delay}" =~ ^[0-9]+$ ]]; then
        log_warn "Invalid CODE_SERVER_UPDATE_INITIAL_DELAY_SECONDS=${initial_delay}; defaulting to 300"
        initial_delay=300
    fi

    if ! [[ "${interval}" =~ ^[0-9]+$ ]] || [ "${interval}" -le 0 ]; then
        log_warn "Invalid CODE_SERVER_UPDATE_INTERVAL_SECONDS=${interval}; defaulting to 86400"
        interval=86400
    fi

    if [ "${CODE_SERVER_VERSION:-latest}" != "latest" ]; then
        log_info "Skipping auto-update loop because CODE_SERVER_VERSION is pinned to ${CODE_SERVER_VERSION}"
        return 0
    fi

    log_info "Starting code-server auto-update loop (initial delay: ${initial_delay}s, interval: ${interval}s)"
    sleep "${initial_delay}"

    while true; do
        if check_and_update_code_server; then
            log_info "code-server auto-update check completed"
        else
            log_warn "code-server auto-update check failed; retrying on next interval"
        fi

        sleep "${interval}"
    done
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
    
    ${CODE_SERVER_CMD} --install-extension "${vsix_path}" --force
    rm -f "${vsix_path}"
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
    ${CODE_SERVER_CMD} --install-extension "${extension_id}" --force
}

# 插件安装任务（在后台执行）
install_extensions_async() {
    log_info "Starting extension installation in background..."

    # Poll until code-server is ready to accept extension commands
    local attempts=0
    until ${CODE_SERVER_CMD} --list-extensions >/dev/null 2>&1; do
        sleep 2
        attempts=$((attempts + 1))
        if [ "${attempts}" -ge 60 ]; then
            log_warn "code-server did not become ready after 120s; skipping extension install"
            return 1
        fi
    done

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

    for extension_id in "${openvsx_extensions[@]}"; do
        log_info "Installing extension: ${extension_id}..."
        if install_openvsx_extension "${extension_id}"; then
            log_info "Successfully installed: ${extension_id}"
        else
            log_warn "Failed to install: ${extension_id}"
        fi
    done

    log_info "Extension installation completed!"
}

# ============================================
# Claude + Codex Proxy 启动（共用同一个 proxy，端口 8089）
# ============================================
setup_claude_proxy() {
    if [ "${DEV_USER}" != "root" ]; then
        # Run as dev user so HOME resolves to DEV_HOME (where codewiz auth.json lives)
        HOME="${DEV_HOME}" gosu "${DEV_USER}" /usr/local/bin/start-claude-proxy.sh \
            2>&1 | while IFS= read -r line; do log_info "${line}"; done || true
    else
        /usr/local/bin/start-claude-proxy.sh \
            2>&1 | while IFS= read -r line; do log_info "${line}"; done || true
    fi
    # Proxy health check only; endpoint config is managed by cc-switch provider settings
    if ! curl -sf --max-time 2 "http://127.0.0.1:8089" >/dev/null 2>&1; then
        log_warn "codewiz-proxy not responding on port 8089"
    fi
}

# ============================================
# 主函数
# ============================================
main() {
    log_info "=========================================="
    log_info "Starting DevBox services..."
    log_info "=========================================="

    # 0. 初始化开发用户（必须最先，其他函数依赖 DEV_HOME 目录已就绪）
    setup_dev_user

    # 0.4 旧环境变量兼容性警告
    _warn_deprecated_env_vars

    # 0.5 配置 cc-switch providers（codewiz-proxy 模型切换）
    setup_cc_switch_providers

    # 0.6 安装 tmux 插件（运行时下载，无需重建镜像）
    setup_tmux_plugins

    # 1. 启动 SSH 服务
    setup_ssh

    # 2. 配置 Git
    setup_git

    # 3. 配置 code-server（不依赖已安装）
    setup_code_server_config

    # 4. 启动 claude proxy（在 code-server 之前，使 code-server 继承环境变量）
    setup_claude_proxy

    # 5. 在后台安装/更新 code-server，装好后立即启动，装完再开自动更新和插件安装
    # 注意：start_code_server 设置的 CODE_SERVER_PID 在子 shell 中无法传回主进程，
    # stop/restart_code_server 仅在子 shell 内（如 check_and_update_code_server）有效。
    {
        if ensure_code_server_installed; then
            start_code_server
            if is_code_server_auto_update_enabled; then
                code_server_update_loop &
            fi
            install_extensions_async
        else
            log_error "code-server installation failed; skipping start"
        fi
    } &
    log_info "code-server install/start running in background"

    log_info "=========================================="
    log_info "All services started successfully!"
    log_info "SSH: port 22"
    log_info "Code Server: port ${CODE_SERVER_PORT:-8080}"
    log_info "=========================================="

    # 9. 保持容器运行，等待所有后台进程
    wait
}

# 执行主函数
main "$@"
