# headless_vero
Here is the the contens of a headlees-docker.deb, that i'm toying with for Vero4 users looking to user their aging Vero4's as a small homeserver.

The package will install fzf, bat, tldr, ripgrep, zoxide, mc, screen, aml-vnc. All this a re debian or osmc packages.

It will also install two external binarys, tested with Vero4, lazydocker_0.24.1_Linux_arm64.tar and eza_aarch64-unknown-linux-gnu.

Lastly it will put two modiefied install scripts, one for docker (that is modyfied to see Vero4s as arm64) docker_install.sh and one for samba
samba_install.sh, which installs osmc smb pckage ith auto sharing of auto mounts and added to that a python based service from bookworm called
wsdd for publishing and remembering windows shares in your network.

