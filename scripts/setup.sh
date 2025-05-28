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
     ( o.o )  Hello! I'm CodeCat 🐱💻
      > ^ <  Setting up your GitOps environment...
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

check_tools() {
  local tools=(docker kubectl helm kind)
  log_info "Checking required tools..."
  for tool in "${tools[@]}"; do
    if ! command -v $tool &>/dev/null; then
      log_error "$tool not found. Please install it before proceeding."
      exit 1
    fi
  done
  log_success "All required tools found."
}

create_kind_cluster() {
  local cluster_name="gitops-cluster"
  local cluster_config="cluster/config.yaml"

  log_info "Checking if kind cluster '$cluster_name' exists..."
  if kind get clusters | grep -q "$cluster_name"; then
    log_success "Cluster '$cluster_name' already exists."
  else
    log_info "Creating kind cluster from config..."
    kind create cluster --name $cluster_name --config $cluster_config > /dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    if [ $? -eq 0 ]; then
      log_success "Kind cluster created."
    else
      log_error "Failed to create kind cluster."
      exit 1
    fi
  fi
}

install_argocd() {
  log_info "Installing ArgoCD on cluster..."
  kubectl get namespace argocd > /dev/null 2>&1 || kubectl create namespace argocd > /dev/null
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml > /tmp/argocd-install.log 2>&1 &

  pid=$!
  spinner $pid
  wait $pid

  if [ $? -ne 0 ]; then
    log_error "Failed to install ArgoCD. Check /tmp/argocd-install.log for details."
    exit 1
  fi

  log_info "Waiting for ArgoCD Server to be ready..."
  kubectl wait --namespace argocd --for=condition=Ready pods -l app.kubernetes.io/name=argocd-server --timeout=120s > /dev/null
  if [ $? -eq 0 ]; then
    log_success "ArgoCD is ready!"
  else
    log_error "ArgoCD server did not become ready in time."
    exit 1
  fi
}

deploy_apps() {
  local apps_dir="kubernetes/argocd"

  if [ -z "$(ls -A $apps_dir/*.yaml 2>/dev/null)" ]; then
    log_info "No ArgoCD application manifests found in $apps_dir."
    return
  fi

  log_info "Applying ArgoCD applications..."
  for app_file in "$apps_dir"/*.yaml; do
    kubectl apply -f "$app_file" > /dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid

    if [ $? -ne 0 ]; then
      log_error "Failed to apply $app_file."
      exit 1
    fi
  done
  log_success "All ArgoCD applications applied."
}

main() {
  ascii_art
  check_tools
  create_kind_cluster
  install_argocd
  deploy_apps

  echo -e "\n🎉 ${GREEN}Setup complete! To access the ArgoCD Server via port-forward, run:${NC}"
  echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

main
