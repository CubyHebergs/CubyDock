#!/bin/bash

# check if directory exist
if [ -d "/var/www/html/cubydock" ]; then
  read -e -p "cubydock is already install you are realy sur to reinstall ? : (Y/n) " input_reinstall
  input_reinstall="${input_reinstall:-y}"
fi

if [ "$input_reinstall" != "${input_reinstall#[Yy]}" ]; then
    echo "Reinstall again..."
    echo "Stop service..."
    sudo systemctl stop cubydock
    echo "Erase all file & database"
    sudo rm -rf /var/www/html/cubydock
    echo "Delete Service"
    sudo rm -rf /etc/systemd/system/cubydock.service
    sudo rm -rf /usr/lib/systemd/system/cubydock.service
    sudo rm -rf /etc/systemd/system/multi-user.target.wants/cubydock.service
    sudo rm -rf /run/CubyDock
    echo "Delete all dependancy Python"
    sudo python3 -m pip uninstall -r ../requirements.txt -y
    echo "Delete User/Group cuby"
    sudo userdel -r cuby
    sudo groupdel cuby

elif [ "$input_reinstall" != "${input_reinstall#[Nn]}" ]; then
    echo "Ok, good bye"
    exit
fi

{
  DISTRO=$(( lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1)
  VERSION=$(lsb_release -sr)
} || {
  # install for centos lsb_release
  yum install -y redhat-lsb
  DISTRO=$(( lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1)
  VERSION=$(lsb_release -sr)
}

if [[ "$DISTRO"  =~ "Manjaro" ]]; then
  DEPO="sudo pacman"
  DEPO_INSTALL="-S --noconfirm"
  PACKAGE="docker"

elif [[ "$DISTRO"  =~ "Fedora" ]] || [[  "$DISTRO"  =~ "CentOS" ]] && [[  "$VERSION"  =~ "8." ]]; then
  DEPO="sudo dnf"
  DEPO_INSTALL="install -y"
  PACKAGE="docker"

elif [[  "$DISTRO"  =~ "CentOS" ]] && [[  "$VERSION"  =~ "7." ]]; then
  DEPO="sudo yum"
  DEPO_INSTALL="install -y"
  PACKAGE="docker"

elif [[ "$DISTRO"  =~ "Debian"  ]] || [[ "$DISTRO"  =~ "Ubuntu"  ]]; then
  DEPO="sudo apt-get"
  DEPO_INSTALL="-y install"
  PACKAGE="docker"
fi

# check group cuby if already exist
group=cuby

if grep -q $group /etc/group
 then
      echo "Error group cuby already exist in your system abord install"
      exit
 else
     sudo useradd cuby
     sudo groupadd cuby
     sudo usermod -a -G cuby cuby
 fi

# install dependancy system
$DEPO $DEPO_INSTALL $PACKAGE
sudo python3 -m pip install -r ../requirements.txt

# copy systemd Service
sudo cp ../src/systemd/cubydock.service /etc/systemd/system/cubydock.service
sudo systemctl daemon-reload

# check web directory exist
if [ ! -d "/var/www/html/cubydock" ]; then
 sudo mkdir -p /var/www/html/cubydock
fi

sudo virtualenv /var/www/html/cubydock/.venv
source /var/www/html/cubydock/.venv/bin/activate
sudo python3 -m pip install -r ../requirements-env.txt

# copy web directory and fix permission group and user
sudo cp -R ../src/web-app/. /var/www/html/cubydock
sudo chown cuby:cuby -R /var/www/html/cubydock
sudo chmod 775 -R /var/www/html/cubydock

# select language install
echo "Please select language for cubydock"
echo "1. French"
echo "2. English"
read -e -p "select your language number ? :" input_language

if [ "$input_language" != "${input_language#[1]}" ]; then
  echo "French language select"
  sudo sed -i "132s/en/fr/g" /var/www/html/cubydock/cuby/settings.py
elif [ "$input_language" != "${input_language#[2]}" ]; then
  echo "English language select"
  sudo sed -i "132s/en/en/g" /var/www/html/cubydock/cuby/settings.py
fi

# renewgenerate SECRET_KEY
NEW_SECRET_KEY=$(sudo python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
sudo sed -i "28s/SECRET_KEY_RANDOM/$NEW_SECRET_KEY/g" /var/www/html/cubydock/cuby/settings.py

# collectstatic django
sudo python3 /var/www/html/cubydock/manage.py collectstatic <<< "yes"

# collect LANGUAGE
sudo python3 /var/www/html/cubydock/manage.py compilemessages

# prepare database
sudo python3 /var/www/html/cubydock/manage.py makemigrations
sudo python3 /var/www/html/cubydock/manage.py migrate

# start service
echo "Prepare service..."
sudo systemctl enable cubydock
sudo systemctl start cubydock
sudo systemctl enable docker
sudo systemctl start docker

service_stats=$(systemctl show -p SubState cubydock | sed 's/SubState=//g')

if [[ "$service_stats"  != "running" ]]; then
  echo ""
  echo " -------------------------------------------------------- "
  echo "| /!\      Error service doesn't work correctly      /!\ |"
  echo "|     show command : sudo systemctl status cubydock      |"
  echo " -------------------------------------------------------- "
else
  echo ""
  echo " -------------------------------------------------------- "
  echo "| Install finish web panel access on http://0.0.0.0:8000 |"
  echo " -------------------------------------------------------- "
fi

# fix permission run docker
docker_testrunning=$(docker ps)

if [[ "$docker_testrunning"  =~ "connect: permission denied" ]]; then
  sudo usermod -aG docker $USER

  echo ""
  echo " -------------------------------------------------------- "
  echo "|      FINISH INSTALL BUT PLEASE REBOOT YOUR SYSTEM      |"
  echo "|     FOR FIX SYSTEM PERMISSION DOCKER WORK CORRECTLY    |"
  echo " -------------------------------------------------------- "

  read -e -p "Reboot Now : (Y/n) " input_reboot
  input_reboot="${input_reboot:-y}"
fi

if [ "$input_reboot" != "${input_reboot#[Yy]}" ]; then
  sudo reboot
elif [ "$input_reboot" != "${input_reboot#[Nn]}" ]; then
    echo "Ok, good bye"
    exit
fi
