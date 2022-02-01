# Kickstart file for alma-8.5
# Generated by libguestfs.git/builder/templates/make-template.ml

install
text
reboot
lang en_US.UTF-8
keyboard us
network --bootproto dhcp
rootpw builder
firewall --enabled --ssh
timezone --utc America/New_York
selinux --enforcing

bootloader --location=mbr --append="console=tty0 console=ttyS0,115200 rd_NO_PLYMOUTH"


zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --type=plain

# Halt the system once configuration has finished.
poweroff

%packages
@core
%end

# EOF
