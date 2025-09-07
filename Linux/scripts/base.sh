#!/bin/bash
#
# setup-rocky-tui.sh - Interface TUI para Configuração de Rocky Linux em LXC
#
# Este script fornece uma interface interativa para configuração completa do ambiente:
# 1. Define uma chave SSH específica para o usuário root do contêiner.
# 2. Cria um usuário administrador ('admin') com sudo e a mesma chave SSH.
# 3. Reforça a segurança do SSH (desabilita root, senha e restringe acesso por IP).
# 4. Atualiza o sistema e instala pacotes essenciais (git, docker, htop, etc.).
# 5. Configura o Docker, inicia o serviço e adiciona o 'admin' ao grupo.
# 6. Cria o diretório de deploy em /opt/apps.
# 7. Aplica um .bashrc personalizado e amigável para o usuário 'admin'.
# 8. Auto-desabilita o serviço systemd após execução única.
#
# Executar como root dentro do contêiner ou como serviço systemd.
#

set -e # Encerra o script se qualquer comando falhar

# --- Controle de cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Função para logging ---
log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# --- Função para mostrar progresso ---
show_progress() {
    local current=$1
    local total=$2
    local step_name=$3
    local percentage=$((current * 100 / total))
    
    echo -e "\n${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} Progresso: ${CYAN}[$current/$total]${NC} ${GREEN}($percentage%)${NC}"
    echo -e "${PURPLE}║${NC} Executando: ${YELLOW}$step_name${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}\n"
}

# --- Função para pausar e aguardar input do usuário ---
pause_for_user() {
    echo -e "\n${YELLOW}Pressione ENTER para continuar ou CTRL+C para cancelar...${NC}"
    read -r
}

# --- Função para mostrar menu principal ---
show_main_menu() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                    ${CYAN}SETUP ROCKY LINUX TUI${NC}                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${BLUE}Este script irá configurar seu ambiente Rocky Linux com:${NC}"
    echo -e "  ${GREEN}•${NC} Configuração de chaves SSH"
    echo -e "  ${GREEN}•${NC} Criação de usuário administrador"
    echo -e "  ${GREEN}•${NC} Hardening do SSH"
    echo -e "  ${GREEN}•${NC} Instalação de pacotes essenciais"
    echo -e "  ${GREEN}•${NC} Configuração do Docker"
    echo -e "  ${GREEN}•${NC} Preparação do ambiente de deploy"
    echo -e "  ${GREEN}•${NC} Personalização do shell"
    echo -e "\n${YELLOW}Opções:${NC}"
    echo -e "  ${CYAN}1)${NC} Executar configuração completa (interativa)"
    echo -e "  ${CYAN}2)${NC} Executar configuração automática (sem pausas)"
    echo -e "  ${CYAN}3)${NC} Mostrar status do sistema"
    echo -e "  ${CYAN}4)${NC} Sair"
    echo -e "\n${BLUE}Escolha uma opção [1-4]:${NC} "
}

# --- Função para verificar se já foi executado ---
check_if_already_configured() {
    if [ -f "/opt/.rocky-setup-complete" ]; then
        log_warning "Este sistema já foi configurado anteriormente!"
        log_info "Arquivo de controle encontrado: /opt/.rocky-setup-complete"
        echo -e "\n${YELLOW}Deseja executar novamente? (s/N):${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log_info "Execução cancelada pelo usuário."
            disable_systemd_service
            exit 0
        fi
    fi
}

# --- Função para desabilitar o serviço systemd ---
disable_systemd_service() {
    if systemctl is-enabled rocky-setup.service >/dev/null 2>&1; then
        log_step "Desabilitando serviço systemd rocky-setup.service..."
        systemctl disable rocky-setup.service
        log_success "Serviço systemd desabilitado com sucesso"
    fi
}

# --- Função para mostrar status do sistema ---
show_system_status() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                     ${CYAN}STATUS DO SISTEMA${NC}                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}Sistema:${NC}"
    echo -e "  Distribuição: $(cat /etc/redhat-release 2>/dev/null || echo 'N/A')"
    echo -e "  Uptime: $(uptime -p 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${BLUE}Usuários:${NC}"
    if id "admin" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Usuário 'admin' existe"
    else
        echo -e "  ${RED}✗${NC} Usuário 'admin' não encontrado"
    fi
    
    echo -e "\n${BLUE}Serviços:${NC}"
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Docker está ativo"
    else
        echo -e "  ${RED}✗${NC} Docker não está ativo"
    fi
    
    if systemctl is-active sshd >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} SSH está ativo"
    else
        echo -e "  ${RED}✗${NC} SSH não está ativo"
    fi
    
    echo -e "\n${BLUE}Configuração:${NC}"
    if [ -f "/opt/.rocky-setup-complete" ]; then
        echo -e "  ${GREEN}✓${NC} Setup completo executado em: $(cat /opt/.rocky-setup-complete)"
    else
        echo -e "  ${RED}✗${NC} Setup ainda não foi executado"
    fi
    
    echo -e "\n${YELLOW}Pressione ENTER para voltar ao menu...${NC}"
    read -r
}

# --- Variáveis ---
ADMIN_USER="admin"
# Chave SSH pública a ser configurada
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeZjKJuYySTF41rq2I6Op7a4TkpKuMM0LS4x8Vk/peG efsn88@pm.me"
INTERACTIVE_MODE=true
TOTAL_STEPS=7

# --- Função principal de configuração ---
run_setup() {
    local interactive=$1
    INTERACTIVE_MODE=$interactive
    
    log_step "Iniciando configuração do Rocky Linux..."
    
    # Verificar se já foi configurado
    check_if_already_configured
    
    # Passo 1: Configuração SSH do Root
    show_progress 1 $TOTAL_STEPS "Configuração da chave SSH para root"
    if $INTERACTIVE_MODE; then
        log_info "Será configurada a chave SSH para o usuário root"
        pause_for_user
    fi
    configure_root_ssh
    
    # Passo 2: Atualização do sistema
    show_progress 2 $TOTAL_STEPS "Atualização do sistema e instalação de pacotes"
    if $INTERACTIVE_MODE; then
        log_info "O sistema será atualizado e pacotes essenciais serão instalados"
        pause_for_user
    fi
    update_system_and_install_packages
    
    # Passo 3: Criação do usuário admin
    show_progress 3 $TOTAL_STEPS "Criação e configuração do usuário administrador"
    if $INTERACTIVE_MODE; then
        log_info "Será criado o usuário 'admin' com privilégios sudo"
        pause_for_user
    fi
    create_admin_user
    
    # Passo 4: Hardening SSH
    show_progress 4 $TOTAL_STEPS "Aplicação de configurações de segurança SSH"
    if $INTERACTIVE_MODE; then
        log_info "SSH será configurado com restrições de segurança"
        pause_for_user
    fi
    configure_ssh_hardening
    
    # Passo 5: Configuração Docker
    show_progress 5 $TOTAL_STEPS "Instalação e configuração do Docker"
    if $INTERACTIVE_MODE; then
        log_info "Docker será instalado e configurado"
        pause_for_user
    fi
    configure_docker
    
    # Passo 6: Diretório de deploy
    show_progress 6 $TOTAL_STEPS "Criação do diretório de deploy"
    if $INTERACTIVE_MODE; then
        log_info "Diretório /opt/apps será criado para deploys"
        pause_for_user
    fi
    create_deploy_directory
    
    # Passo 7: Configuração do bashrc
    show_progress 7 $TOTAL_STEPS "Configuração do ambiente shell personalizado"
    if $INTERACTIVE_MODE; then
        log_info "Será aplicado um .bashrc personalizado para o usuário admin"
        pause_for_user
    fi
    configure_bashrc
    
    # Marcar como completo
    mark_setup_complete
    
    # Desabilitar o serviço systemd
    disable_systemd_service
    
    show_completion_message
}

# --- Função para configurar SSH do root ---
configure_root_ssh() {
    log_step "Configurando chave SSH para o usuário 'root'..."
    mkdir -p /root/.ssh
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    log_success "Chave SSH do root configurada"
}

# --- Função para atualizar sistema ---
update_system_and_install_packages() {
    log_step "Atualizando pacotes do sistema..."
    dnf update -y
    
    log_step "Instalando ferramentas essenciais..."
    dnf install -y git vim nano curl wget ncurses htop net-tools bind-utils telnet unzip bzip2 ca-certificates gnupg openssh-server dnf-utils
    log_success "Sistema atualizado e pacotes instalados"
}

# --- Função para criar usuário admin ---
create_admin_user() {
    if id "$ADMIN_USER" &>/dev/null; then
        log_warning "Usuário '$ADMIN_USER' já existe. Pulando criação."
    else
        log_step "Criando usuário '$ADMIN_USER'..."
        useradd -m -s /bin/bash -G wheel "$ADMIN_USER"
        log_success "Usuário '$ADMIN_USER' criado"
    fi
    
    log_step "Configurando permissões de sudo sem senha..."
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-wheel-nopasswd
    
    log_step "Configurando chave SSH para '$ADMIN_USER'..."
    mkdir -p /home/$ADMIN_USER/.ssh
    cp /root/.ssh/authorized_keys /home/$ADMIN_USER/.ssh/authorized_keys
    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    chmod 700 /home/$ADMIN_USER/.ssh
    chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
    log_success "Usuário '$ADMIN_USER' configurado com SSH"
}

# --- Função para configurar SSH hardening ---
configure_ssh_hardening() {
    log_step "Aplicando configurações de segurança ao SSH..."
    
    # Desabilita o login do root
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    log_info "Login do root via SSH desabilitado"
    
    # Desabilita a autenticação por senha
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    log_info "Autenticação por senha desabilitada"
    
    # Restringe o acesso ao usuário admin
    sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
    echo "AllowUsers ${ADMIN_USER}@10.10.100.10" >> /etc/ssh/sshd_config
    log_info "Acesso SSH restrito a: '${ADMIN_USER}@10.10.100.10'"
    
    log_step "Reiniciando serviço SSH..."
    systemctl restart sshd
    log_success "SSH configurado com segurança aprimorada"
}

# --- Função para configurar Docker ---
configure_docker() {
    log_step "Configurando repositório do Docker..."
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    
    log_step "Instalando Docker..."
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_step "Iniciando e habilitando Docker..."
    systemctl start docker
    systemctl enable docker
    
    log_step "Adicionando '$ADMIN_USER' ao grupo docker..."
    usermod -aG docker $ADMIN_USER
    log_success "Docker configurado e '$ADMIN_USER' adicionado ao grupo"
}

# --- Função para criar diretório de deploy ---
create_deploy_directory() {
    log_step "Criando diretório de deploy..."
    mkdir -p /opt/apps
    chown -R $ADMIN_USER:$ADMIN_USER /opt/apps
    log_success "Diretório /opt/apps criado e configurado"
}

# --- Função para configurar bashrc ---
configure_bashrc() {
    log_step "Aplicando .bashrc personalizado..."
    cat << 'EOF' > /home/$ADMIN_USER/.bashrc
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# Meus Aliases Personalizados
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
alias update='sudo dnf update -y'

# Prompt de Comando Colorido
if [ "$EUID" -eq 0 ]; then
  export PS1='\[\e[31m\][\u@\h \W]\$ \[\e[0m\]'
else
  export PS1='\[\e[32m\][\u@\h \W]\$ \[\e[0m\]'
fi

# Ativar Bash Completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
        for rc in ~/.bashrc.d/*; do
                if [ -f "$rc" ]; then
                        . "$rc"
                fi
        done
fi

unset rc
EOF

    chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.bashrc
    log_success ".bashrc personalizado configurado"
}

# --- Função para marcar setup como completo ---
mark_setup_complete() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > /opt/.rocky-setup-complete
    log_success "Setup marcado como completo"
}

# --- Função para mostrar mensagem de conclusão ---
show_completion_message() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                   ${CYAN}CONFIGURAÇÃO CONCLUÍDA!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${GREEN}✅ Configuração completa do Rocky Linux finalizada!${NC}"
    echo -e "\n${BLUE}Resumo das configurações aplicadas:${NC}"
    echo -e "   ${GREEN}•${NC} Usuário '$ADMIN_USER' criado com acesso sudo e Docker"
    echo -e "   ${GREEN}•${NC} Chaves SSH configuradas para 'root' e '$ADMIN_USER'"
    echo -e "   ${GREEN}•${NC} SSH configurado com segurança aprimorada"
    echo -e "   ${GREEN}•${NC} Sistema atualizado com pacotes essenciais"
    echo -e "   ${GREEN}•${NC} Docker instalado e configurado"
    echo -e "   ${GREEN}•${NC} Diretório /opt/apps preparado para deploys"
    echo -e "   ${GREEN}•${NC} Ambiente shell personalizado aplicado"
    echo -e "   ${GREEN}•${NC} Serviço systemd auto-desabilitado"
    echo -e "\n${YELLOW}Próximos passos:${NC}"
    echo -e "   ${BLUE}1.${NC} Faça login como '$ADMIN_USER' usando a chave SSH"
    echo -e "   ${BLUE}2.${NC} Teste os comandos Docker: ${CYAN}docker --version${NC}"
    echo -e "   ${BLUE}3.${NC} Use o diretório /opt/apps para seus deploys"
    echo -e "\n${CYAN}Pressione ENTER para finalizar...${NC}"
    read -r
}

# --- Verificação de Root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Por favor, execute este script como root."
        exit 1
    fi
}

# --- Função principal ---
main() {
    check_root
    
    # Se executado com argumentos, roda em modo não-interativo
    if [ "$1" = "--auto" ] || [ "$1" = "--service" ]; then
        log_step "Modo automático detectado - executando sem interação"
        run_setup false
        exit 0
    fi
    
    # Menu interativo
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                run_setup true
                break
                ;;
            2)
                run_setup false
                break
                ;;
            3)
                show_system_status
                ;;
            4)
                log_info "Saindo..."
                exit 0
                ;;
            *)
                log_error "Opção inválida. Escolha entre 1-4."
                sleep 2
                ;;
        esac
    done
}

# --- Execução do script ---
main "$@"

