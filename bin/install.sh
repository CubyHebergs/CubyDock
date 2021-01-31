#!/bin/bash

# check version Python
Python=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
sudo sed -i "15s/.venv\/bin\/{python}/.venv\/bin\/python${Python}/g" ../src/systemd/cubydock.service

# check if directory exist
if [ -d "/var/www/html/cubydock" ]; then
  read -e -p "cubydock is already install you are realy sur to reinstall ? : (Y/n) " input_reinstall
  input_reinstall="${input_reinstall:-y}"
fi

if [ "$input_reinstall" != "${input_reinstall#[Yy]}" ]; then
    echo "Reinstall again..."
    echo "Stop service..."
    sudo systemctl stop cubydock
    sudo systemctl stop celery
    echo "Erase all file & database"
    sudo rm -rf /var/www/html/cubydock
    echo "Delete Service"
    # delete sudoers cuby
    #sudo head -n -1 /etc/sudoers > /etc/sudoers
    sudo sed '$d' < /etc/sudoers > /etc/sudoers.temp
    sudo cp /etc/sudoers /etc/sudoers.old
    sudo cp /etc/sudoers.temp /etc/sudoers
    sudo rm -rf /etc/sudoers.temp
    sudo rm -rf /var/log/celery
    sudo rm -rf /var/run/celery
    sudo rm -rf /etc/systemd/system/cubydock.service
    sudo rm -rf /etc/conf.d/celery
    sudo rm -rf /etc/systemd/system/celery.service
    sudo rm -rf /usr/lib/systemd/system/cubydock.service
    sudo rm -rf /etc/systemd/system/multi-user.target.wants/cubydock.service
    sudo rm -rf /run/CubyDock
    echo "Delete all dependancy Python"
    sudo python3 -m pip uninstall -r ../requirements.txt -y
    echo "Delete User/Group cuby"
    sudo userdel -r cuby
    sudo groupdel cuby
    sudo groupdel shadow

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
  PACKAGE="docker pam redis"

elif [[ "$DISTRO"  =~ "Fedora" ]] || [[  "$DISTRO"  =~ "CentOS" ]] && [[  "$VERSION"  =~ "8." ]]; then
  DEPO="sudo dnf"
  DEPO_INSTALL="install -y"
  PACKAGE="docker pam pam-devel redis"

elif [[  "$DISTRO"  =~ "CentOS" ]] && [[  "$VERSION"  =~ "7." ]]; then
  DEPO="sudo yum"
  DEPO_INSTALL="install -y"
  PACKAGE="docker pam pam-devel redis"

elif [[ "$DISTRO"  =~ "Debian"  ]] || [[ "$DISTRO"  =~ "Ubuntu"  ]]; then
  DEPO="sudo apt-get update && sudo apt-get"
  DEPO_INSTALL="-y install"
  PACKAGE="docker pam redis"
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
     sudo groupadd shadow
     sudo usermod -a -G cuby cuby
     sudo usermod -a -G shadow cuby
     sudo usermod -aG docker cuby
     sudo setfacl -m u:cuby:rwx /var/run
     password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9@./_#²' | fold -w 11 | head -n 1)
     echo "cuby:${password}" | sudo chpasswd
 fi

# install dependancy system
$DEPO $DEPO_INSTALL $PACKAGE
sudo python3 -m pip install -r ../requirements.txt

# copy systemd Service
sudo cp ../src/systemd/cubydock.service /etc/systemd/system/cubydock.service
sudo cp ../src/systemd/celery/celery /etc/conf.d/celery
sudo cp ../src/systemd/celery/celery.service /etc/systemd/system/celery.service
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
#sudo chmod 775 -R /var/www/html/cubydock
sudo setfacl -R -d -m u:cuby:rwx /var/www/html/cubydock
sudo setfacl -R -d -m o:cuby:rwx /var/www/html/cubydock

# select language install
echo "Please select language for cubydock"
echo "1. French"
echo "2. English"

# travisci autoselect language
if [ -z "$1" ]; then
  read -e -p "select your language number ? :" input_language
else
  input_language=${1}
  if [[ "$input_language"  =~ "fr" ]]; then
    input_language="1"
  elif [[ "$input_language"  =~ "en" ]]; then
    input_language="2"
  fi
fi

if [ "$input_language" != "${input_language#[1]}" ]; then
  echo "French language select"
  sudo sed -i "155s/en/fr/g" /var/www/html/cubydock/cuby/settings.py
elif [ "$input_language" != "${input_language#[2]}" ]; then
  echo "English language select"
  sudo sed -i "155s/en/en/g" /var/www/html/cubydock/cuby/settings.py
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

# start service docker and cubydock
echo "Prepare service..."
sudo systemctl enable cubydock
sudo systemctl start cubydock
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable redis
sudo sysctl vm.overcommit_memory=1
sudo sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
sudo systemctl start redis


# prepare celery and run
sudo mkdir /var/log/celery
sudo chown -R cuby:cuby /var/log/celery
sudo chmod -R 755 /var/log/celery

sudo mkdir /var/run/celery
sudo chown -R cuby:cuby /var/run/celery
sudo chmod -R 755 /var/run/celery
sudo setfacl -R -d -m u:cuby:rwx /var/run/celery
sudo setfacl -R -d -m o:cuby:rwx /var/run/celery

# add sudoers cuby
sudo sh -c "echo \"cuby ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers"

sudo systemctl enable celery
sudo systemctl start celery

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
  echo "|    Username is: cuby Your Password: ${password}        |"
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

sudo chown cuby:cuby -R /var/www/html/cubydock
