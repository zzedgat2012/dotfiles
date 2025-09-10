#!/bin/bash
#
# setup-rocky-tui.sh - Interface TUI para Configuração de Rocky Linux em LXC
#
# Este script fornece uma interface interativa (TUI) para configuração completa do ambiente:
# 1. Adiciona os repositórios EPEL e RPM Fusion.
# 2. Define uma chave SSH específica para o usuário root do contêiner.
# 3. Cria um usuário administrador ('admin') com sudo e a mesma chave SSH.
# 4. Reforça a segurança do SSH (desabilita root, senha e restringe acesso por IP).
#    (Etapa pulada automaticamente se um ambiente WSL for detectado).
# 5. Atualiza o sistema e instala pacotes essenciais (git, docker, htop, etc.).
# 6. Configura o Docker, inicia o serviço e adiciona o 'admin' ao grupo.
# 7. Cria o diretório de deploy em /opt/apps.
# 8. Aplica um .bashrc personalizado e amigável para o usuário 'admin'.
# 9. Auto-desabilita o serviço systemd após execução única.
#
# Executar como root dentro do contêiner ou como serviço systemd.
#

set -e # Encerra o script se qualquer comando falhar

# --- Controle de cores para output (usado no log de fundo) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Variáveis ---
ADMIN_USER="admin"
# Chave SSH pública a ser configurada
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeZjKJuYySTF41rq2I6Op7a4TkpKuMM0LS4x8Vk/peG efsn88@pm.me"
IS_WSL=false
TOTAL_STEPS=8

# --- Funções de Logging ---
log_step() { echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# --- Funções TUI (dialog) ---
show_infobox() { dialog --title "Informação" --infobox "$1" 5 50; }
show_msgbox() { dialog --title "Mensagem" --msgbox "$1" 10 60; }
show_yesno() { dialog --title "Confirmação" --yesno "$1" 8 60; }

# --- Função para verificar se estamos em ambiente WSL ---
check_wsl() {
    if grep -q -i "microsoft\|wsl" /proc/version; then
        IS_WSL=true
        log_warning "Ambiente WSL detectado. A configuração de SSH será pulada."
    else
        IS_WSL=false
    fi
}

# --- Função para verificar se já foi executado ---
check_if_already_configured() {
    if [ -f "/opt/.rocky-setup-complete" ]; then
        if ! show_yesno "Este sistema já foi configurado anteriormente. Arquivo de controle encontrado em /opt/.rocky-setup-complete.\n\nDeseja executar novamente?"; then
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
    distro=$(cat /etc/redhat-release 2>/dev/null || echo 'N/A')
    uptime_val=$(uptime -p 2>/dev/null || echo 'N/A')

    admin_status="${RED}✗ Usuário 'admin' não encontrado${NC}"
    if id "admin" &>/dev/null; then
        admin_status="${GREEN}✓ Usuário 'admin' existe${NC}"
    fi

    docker_status="${RED}✗ Docker não está ativo${NC}"
    if systemctl is-active docker >/dev/null 2>&1; then
        docker_status="${GREEN}✓ Docker está ativo${NC}"
    fi

    ssh_status="${RED}✗ SSH não está ativo${NC}"
    if systemctl is-active sshd >/dev/null 2>&1; then
        ssh_status="${GREEN}✓ SSH está ativo${NC}"
    fi

    setup_status="${RED}✗ Setup ainda não foi executado${NC}"
    if [ -f "/opt/.rocky-setup-complete" ]; then
        setup_status="${GREEN}✓ Setup completo executado em: $(cat /opt/.rocky-setup-complete)${NC}"
    fi

    # Usando --programbox para manter cores
    (
        echo -e "${BLUE}Sistema:${NC}"
        echo -e "  Distribuição: $distro"
        echo -e "  Uptime: $uptime_val\n"
        echo -e "${BLUE}Usuários:${NC}"
        echo -e "  $admin_status\n"
        echo -e "${BLUE}Serviços:${NC}"
        echo -e "  $docker_status"
        echo -e "  $ssh_status\n"
        echo -e "${BLUE}Configuração:${NC}"
        echo -e "  $setup_status"
    ) | dialog --title "Status do Sistema" --programbox 20 70
}


# --- Funções de Configuração ---

configure_extra_repos() {
    log_step "Adicionando repositórios EPEL e RPM Fusion..."
    dnf install -y --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm > /dev/null 2>&1
    dnf install -y --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm > /dev/null 2>&1
    log_success "Repositórios EPEL e RPM Fusion adicionados."
}

configure_root_ssh() {
    log_step "Configurando chave SSH para o usuário 'root'..."
    mkdir -p /root/.ssh
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    log_success "Chave SSH do root configurada"
}

update_system_and_install_packages() {
    log_step "Atualizando pacotes do sistema..."
    dnf update -y > /dev/null 2>&1
    
    log_step "Instalando ferramentas essenciais..."
    dnf install -y git vim nano curl wget htop net-tools bind-utils telnet unzip bzip2 ca-certificates gnupg openssh-server dnf-utils > /dev/null 2>&1
    log_success "Sistema atualizado e pacotes instalados"
}

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
    
    if ! $IS_WSL; then
        log_step "Configurando chave SSH para '$ADMIN_USER'..."
        mkdir -p /home/$ADMIN_USER/.ssh
        cp /root/.ssh/authorized_keys /home/$ADMIN_USER/.ssh/authorized_keys
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
        log_success "Usuário '$ADMIN_USER' configurado com SSH"
    fi
}

configure_ssh_hardening() {
    log_step "Aplicando configurações de segurança ao SSH..."
    
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    log_info "Login do root via SSH desabilitado"
    
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    log_info "Autenticação por senha desabilitada"
    
    sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
    echo "AllowUsers ${ADMIN_USER}@10.10.100.10" >> /etc/ssh/sshd_config
    log_info "Acesso SSH restrito a: '${ADMIN_USER}@10.10.100.10'"
    
    log_step "Reiniciando serviço SSH..."
    systemctl restart sshd
    log_success "SSH configurado com segurança aprimorada"
}

configure_docker() {
    log_step "Configurando repositório do Docker..."
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
    
    log_step "Instalando Docker..."
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    
    log_step "Iniciando e habilitando Docker..."
    systemctl start docker
    systemctl enable docker
    
    log_step "Adicionando '$ADMIN_USER' ao grupo docker..."
    usermod -aG docker $ADMIN_USER
    log_success "Docker configurado e '$ADMIN_USER' adicionado ao grupo"
}

create_deploy_directory() {
    log_step "Criando diretório de deploy..."
    mkdir -p /opt/apps
    chown -R $ADMIN_USER:$ADMIN_USER /opt/apps
    log_success "Diretório /opt/apps criado e configurado"
}

configure_bashrc() {
    log_step "Aplicando .bashrc personalizado..."
    # O conteúdo do .bashrc foi omitido para encurtar, mas é o mesmo do script original
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
EOF
    chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.bashrc
    log_success ".bashrc personalizado configurado"
}

mark_setup_complete() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > /opt/.rocky-setup-complete
    log_success "Setup marcado como completo"
}

# --- Função principal de execução com TUI ---
run_setup() {
    check_if_already_configured

    if $IS_WSL; then
        show_infobox "Ambiente WSL detectado!\n\nAs etapas de configuração de SSH (root e hardening) serão puladas."
        sleep 2
        TOTAL_STEPS=6 # Ajusta o total de passos para WSL
    fi

    local current_step=0
    (
        # Passo 1: Adicionar repositórios extras
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Adicionando repositórios EPEL e RPM Fusion..."
        echo "XXX"
        configure_extra_repos

        # Passo 2: Configuração SSH do Root (se não for WSL)
        if ! $IS_WSL; then
            let current_step++
            echo $((current_step * 100 / TOTAL_STEPS))
            echo "XXX"
            echo "Passo [$current_step/$TOTAL_STEPS]: Configurando chave SSH para root..."
            echo "XXX"
            configure_root_ssh
        fi

        # Passo 3: Atualização do sistema
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Atualizando sistema e instalando pacotes..."
        echo "XXX"
        update_system_and_install_packages
        
        # Passo 4: Criação do usuário admin
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Criando usuário administrador..."
        echo "XXX"
        create_admin_user

        # Passo 5: Hardening SSH (se não for WSL)
        if ! $IS_WSL; then
            let current_step++
            echo $((current_step * 100 / TOTAL_STEPS))
            echo "XXX"
            echo "Passo [$current_step/$TOTAL_STEPS]: Aplicando configurações de segurança SSH..."
            echo "XXX"
            configure_ssh_hardening
        fi

        # Passo 6: Configuração Docker
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Instalando e configurando o Docker..."
        echo "XXX"
        configure_docker

        # Passo 7: Diretório de deploy
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Criando diretório de deploy..."
        echo "XXX"
        create_deploy_directory

        # Passo 8: Configuração do bashrc
        let current_step++
        echo $((current_step * 100 / TOTAL_STEPS))
        echo "XXX"
        echo "Passo [$current_step/$TOTAL_STEPS]: Configurando ambiente shell personalizado..."
        echo "XXX"
        configure_bashrc

    ) | dialog --title "Progresso da Configuração" --gauge "Iniciando..." 10 75 0

    mark_setup_complete
    disable_systemd_service
    
    local summary="Configuração completa do Rocky Linux finalizada!\n\nResumo:\n"
    summary+="  • Usuário '$ADMIN_USER' criado com acesso sudo e Docker.\n"
    if ! $IS_WSL; then
    summary+="  • Chaves SSH configuradas e hardening aplicado.\n"
    fi
    summary+="  • Repositórios EPEL e RPM Fusion adicionados.\n"
    summary+="  • Sistema atualizado com pacotes essenciais.\n"
    summary+="  • Docker instalado e configurado.\n"
    summary+="  • Diretório /opt/apps preparado para deploys.\n"
    summary+="  • Serviço systemd auto-desabilitado."
    
    show_msgbox "$summary"
}

# --- Verificação de Root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Por favor, execute este script como root."
        # Tenta mostrar o erro no dialog se possível, senão só no console
        command -v dialog >/dev/null && show_msgbox "ERRO: Este script precisa ser executado como root."
        exit 1
    fi
}

# --- Função de setup inicial para TUI ---
prepare_tui() {
    log_step "Verificando dependências para a interface TUI..."
    if ! command -v dialog >/dev/null; then
        log_info "Instalando 'ncurses' e 'dialog' para a interface gráfica..."
        dnf install -y ncurses dialog > /dev/null 2>&1
        log_success "'dialog' instalado."
    fi
}

# --- Função principal ---
main() {
    check_root
    
    # Se executado com argumentos, roda em modo não-interativo (sem TUI)
    if [ "$1" = "--auto" ] || [ "$1" = "--service" ]; then
        log_step "Modo automático detectado - executando sem interação"
        check_wsl
        # Aqui você poderia chamar uma função `run_setup_non_interactive` se quisesse
        # Por simplicidade, vamos assumir que o modo automático não precisa de TUI
        # e as funções de log são suficientes.
        echo "Modo automático ainda não implementado com as novas funções."
        exit 1
    fi
    
    prepare_tui
    check_wsl

    while true; do
        exec 3>&1
        selection=$(dialog --backtitle "Setup Rocky Linux" \
            --title "MENU PRINCIPAL" \
            --clear \
            --cancel-label "Sair" \
            --menu "Escolha uma opção:" 15 60 4 \
            "1" "Executar configuração completa" \
            "2" "Mostrar status do sistema" \
            "3" "Sair" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            0) # Opção OK
                case $selection in
                    1)
                        if show_yesno "Você está prestes a iniciar a configuração completa do sistema. Deseja continuar?"; then
                            run_setup
                        fi
                        ;;
                    2) show_system_status ;;
                    3) break ;;
                esac
                ;;
            1) # Botão Cancel (Sair)
                break
                ;;
            255) # Tecla ESC
                break
                ;;
        esac
    done
    
    clear
    log_info "Script finalizado."
}

# --- Execução do script ---
main "$@"
