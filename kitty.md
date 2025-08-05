# Configurações de entrada
input {
    kb_layout = br
    follow_mouse = 1
    sensitivity = 0
}
input:touchpad {
    natural_scroll = yes
    tap-to-click = yes
}

# Configurações gerais
monitor=,preferred,auto,1
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Iniciar o kitty automaticamente
exec-once = kitty

# Atalhos
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, F, fullscreen