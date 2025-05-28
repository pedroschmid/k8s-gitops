#!/bin/bash

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

INFO="ℹ️ "
CHECK_MARK="✅"
CROSS_MARK="❌"

ascii_art() {
  echo -e "${CYAN}
      /\\_/\\  
     ( o.o )  Hello! I'm CodeCat 🐱🧹
      > ^ <  Cleaning up your GitOps environment...
${NC}"
}

log_info()    { echo ""; echo -e "${YELLOW}[${INFO}] $1${NC}"; }
log_success() { echo -e "${GREEN}[${CHECK_MARK}] $1${NC}"; }
log_error()   { echo -e "${RED}[${CROSS_MARK}] $1${NC}"; }

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
}

delete_argocd() {
  log_info "Deleting ArgoCD namespace (argocd)..."
  kubectl delete namespace argocd --ignore-not-found > /dev/null 2>&1 &
  pid=$!
  spinner $pid
  wait $pid
  if [ $? -eq 0 ]; then
    log_success "ArgoCD namespace deleted."
  else
    log_error "Failed to delete ArgoCD namespace."
  fi
}

delete_kind_cluster() {
  local cluster_name="gitops-cluster"
  log_info "Deleting kind cluster '$cluster_name'..."
  kind delete cluster --name "$cluster_name" > /dev/null 2>&1 &
  pid=$!
  spinner $pid
  wait $pid
  if [ $? -eq 0 ]; then
    log_success "Kind cluster deleted."
  else
    log_error "Failed to delete kind cluster."
  fi
}

main() {
  ascii_art
  delete_argocd
  delete_kind_cluster

  echo -e "\n🎉 ${GREEN}Cleanup complete! Your environment is clean and ready for another run.${NC}"
}

main
