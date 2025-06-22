mkdir -p $HOME/.uvc
wget -O $HOME/.uvc/uvc.sh 'uvc.sh'

enable_uvc='source "$HOME/.uvc/uvc.sh"'

if ! grep -qxF "$enable_uvc" ~/.bashrc; then
    echo "$enable_uvc" >> ~/.bashrc
fi
source ~/.bashrc