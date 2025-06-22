mkdir -p $HOME/.uvc
wget -O $HOME/.uvc/uvc.sh 'https://github.com/LiangYang666/uvc/releases/download/latest/uvc.sh'

enable_uvc='source "$HOME/.uvc/uvc.sh"'

if [ -n "$ZSH_VERSION" ]; then
    config_file="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    config_file="$HOME/.bashrc"
else
    config_file="$HOME/.bashrc"
fi

# 检查并添加配置
if ! grep -qxF "$enable_uvc" "$config_file"; then
    echo "$enable_uvc" >> "$config_file"
fi

# 重新加载配置
source "$config_file"