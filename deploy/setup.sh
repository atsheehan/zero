#!/bin/bash

# Exit early if any of the commands fails
set -e

# Fetch the latest package lists and upgrade any previously installed
# packages.
sudo apt-get update
sudo apt-get -y upgrade

# Enable unattended-upgrades to install essential security updates
# nightly.
sudo tee /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Libraries required to build Ruby
sudo apt-get -y install autoconf bison build-essential libssl-dev \
     libreadline-dev zlib1g-dev libgdbm-dev

# Download Ruby source code
cd $HOME
wget https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.2.tar.gz
echo "8d7f6ca0f16d77e3d242b24da38985b7539f58dc0da177ec633a83d0c8f5b197 ruby-2.3.2.tar.gz" | sha256sum -c -

tar zxf ruby-2.3.2.tar.gz
cd ruby-2.3.2/

# Compile and install Ruby system-wide
./configure --disable-install-doc
make
sudo make install

# Clean up build artifacts after installed
cd $HOME
rm -rf ruby-2.3.2 ruby-2.3.2.tar.gz

# Use bundler to bootstrap gem installs
sudo gem install --no-document bundler

# Download the latest version of the web application
cd $HOME
wget https://github.com/atsheehan/zero/archive/master.tar.gz
tar zxf master.tar.gz
rm master.tar.gz

# This is the directory where the application source will live.
sudo mkdir -p /srv
sudo mv zero-master /srv/zero
sudo chown -R root:root /srv/zero

# These libraries are necessary for building native gem extensions
sudo apt-get install -y libpq-dev nodejs

# Install and build gems
cd /srv/zero
sudo bundle install --deployment --without development test

# Precompile assets
sudo RAILS_ENV=production bundle exec rake assets:precompile

# Create application user
sudo adduser --system --no-create-home --gecos '' zero

# Create our new temp directory
sudo mkdir -p /var/tmp/zero
sudo chown zero /var/tmp/zero

# Remove the existing temp directory, then replace it with a symlink
sudo rm -rf /srv/zero/tmp
sudo ln -s /var/tmp/zero/ /srv/zero/tmp

# Provide a dummy log file. The actual logs will be capture from
# STDOUT and written to /var/log/upstart/zero.log
sudo rm /srv/zero/log/production.log
sudo ln -s /dev/null /srv/zero/log/production.log

# Use a local PostgreSQL server for demonstration purposes and create
# the "zero" database user.
sudo apt-get install -y postgresql
sudo su postgres -c "createuser -s zero"

# Normally we'd fetch database credentials and other secrets from a
# secure, external source. For this demonstration, we're using a local
# database server so we can connect without a password, and we can
# generate a random secret key base using `rake secret`.
sudo tee /srv/zero/.env <<EOF
DATABASE_NAME=zero_production
DATABASE_HOST=
DATABASE_USER=zero
DATABASE_PASSWORD=
EOF

echo "SECRET_KEY_BASE=$(bundle exec rake secret)" | sudo tee -a /srv/zero/.env

# Configure the database
cd /srv/zero
bundle exec rake db:setup

# Start application service
sudo cp /srv/zero/deploy/upstart.conf /etc/init/zero.conf
sudo start zero

# Add the nginx package repository
sudo tee /etc/apt/sources.list.d/nginx.list <<EOF
deb http://nginx.org/packages/ubuntu/ trusty nginx
deb-src http://nginx.org/packages/ubuntu/ trusty nginx
EOF

# Add the signing key for the nginx repo
cat <<EOF > /tmp/nginx_repo.key
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2.0.22 (GNU/Linux)

mQENBE5OMmIBCAD+FPYKGriGGf7NqwKfWC83cBV01gabgVWQmZbMcFzeW+hMsgxH
W6iimD0RsfZ9oEbfJCPG0CRSZ7ppq5pKamYs2+EJ8Q2ysOFHHwpGrA2C8zyNAs4I
QxnZZIbETgcSwFtDun0XiqPwPZgyuXVm9PAbLZRbfBzm8wR/3SWygqZBBLdQk5TE
fDR+Eny/M1RVR4xClECONF9UBB2ejFdI1LD45APbP2hsN/piFByU1t7yK2gpFyRt
97WzGHn9MV5/TL7AmRPM4pcr3JacmtCnxXeCZ8nLqedoSuHFuhwyDnlAbu8I16O5
XRrfzhrHRJFM1JnIiGmzZi6zBvH0ItfyX6ttABEBAAG0KW5naW54IHNpZ25pbmcg
a2V5IDxzaWduaW5nLWtleUBuZ2lueC5jb20+iQE+BBMBAgAoAhsDBgsJCAcDAgYV
CAIJCgsEFgIDAQIeAQIXgAUCV2K1+AUJGB4fQQAKCRCr9b2Ce9m/YloaB/9XGrol
kocm7l/tsVjaBQCteXKuwsm4XhCuAQ6YAwA1L1UheGOG/aa2xJvrXE8X32tgcTjr
KoYoXWcdxaFjlXGTt6jV85qRguUzvMOxxSEM2Dn115etN9piPl0Zz+4rkx8+2vJG
F+eMlruPXg/zd88NvyLq5gGHEsFRBMVufYmHtNfcp4okC1klWiRIRSdp4QY1wdrN
1O+/oCTl8Bzy6hcHjLIq3aoumcLxMjtBoclc/5OTioLDwSDfVx7rWyfRhcBzVbwD
oe/PD08AoAA6fxXvWjSxy+dGhEaXoTHjkCbz/l6NxrK3JFyauDgU4K4MytsZ1HDi
MgMW8hZXxszoICTTiQEcBBABAgAGBQJOTkelAAoJEKZP1bF62zmo79oH/1XDb29S
YtWp+MTJTPFEwlWRiyRuDXy3wBd/BpwBRIWfWzMs1gnCjNjk0EVBVGa2grvy9Jtx
JKMd6l/PWXVucSt+U/+GO8rBkw14SdhqxaS2l14v6gyMeUrSbY3XfToGfwHC4sa/
Thn8X4jFaQ2XN5dAIzJGU1s5JA0tjEzUwCnmrKmyMlXZaoQVrmORGjCuH0I0aAFk
RS0UtnB9HPpxhGVbs24xXZQnZDNbUQeulFxS4uP3OLDBAeCHl+v4t/uotIad8v6J
SO93vc1evIje6lguE81HHmJn9noxPItvOvSMb2yPsE8mH4cJHRTFNSEhPW6ghmlf
Wa9ZwiVX5igxcvaIRgQQEQIABgUCTk5b0gAKCRDs8OkLLBcgg1G+AKCnacLb/+W6
cflirUIExgZdUJqoogCeNPVwXiHEIVqithAM1pdY/gcaQZmIRgQQEQIABgUCTk5f
YQAKCRCpN2E5pSTFPnNWAJ9gUozyiS+9jf2rJvqmJSeWuCgVRwCcCUFhXRCpQO2Y
Va3l3WuB+rgKjsQ=
=EWWI
-----END PGP PUBLIC KEY BLOCK-----
EOF

sudo apt-key add /tmp/nginx_repo.key
sudo apt-get update

# Configure nginx web server as reverse proxy
sudo apt-get -y install nginx

sudo rm /etc/nginx/conf.d/default.conf
sudo cp /srv/zero/deploy/nginx.conf /etc/nginx/conf.d/zero.conf

# Restart to pick up new configuration
sudo service nginx restart
