#!/bin/bash

#!/bin/bash -e
############ install cloudflared
# install basic packages
apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install sudo bash nano

# install stubby
apt-get -y update \
    && apt-get -y install stubby

# clean stubby config
mkdir -p /etc/stubby \
    && rm -f /etc/stubby/stubby.yml

# install cloudflared
if [[ ${TARGETPLATFORM} =~ "arm" ]]
then
    cd /tmp \
    && curl -O https://bin.equinox.io/c/VdrWdbjqyF/cloudflared-stable-linux-arm.tgz \
    && tar -xvzf ./cloudflared-stable-linux-arm.tgz \
    && cp ./cloudflared /usr/local/bin \
    && rm -f ./cloudflared-stable-linux-arm.tgz \
    && echo "Cloudflared installed for arm due to tag ${TAG}"
else
    cd /tmp \
    && curl -O https://bin.equinox.io/c/VdrWdbjqyF/cloudflared-stable-linux-amd64.deb \
    && dpkg -i ./cloudflared-stable-linux-amd64.deb \
    && rm -f ./cloudflared-stable-linux-amd64.deb \
    && echo "Cloudflared installed for amd64 due to tag ${TAG}"
fi
useradd -s /usr/sbin/nologin -r -M cloudflared \
    && chown cloudflared:cloudflared /usr/local/bin/cloudflared

# clean cloudflared config
mkdir -p /etc/cloudflared \
    && rm -f /etc/cloudflared/config.yml

# clean up
apt-get -y autoremove \
    && apt-get -y autoclean \
    && apt-get -y clean \
    && rm -fr /tmp/* /var/tmp/* /var/lib/apt/lists/*

# installed version
cloudflared --version
#############

# Creating pihole-dot-doh service
mkdir -p /etc/services.d/pihole-dot-doh

# run file
echo '#!/usr/bin/with-contenv bash' > /etc/services.d/pihole-dot-doh/run
# Copy config file if not exists
echo 'cp -n /temp/stubby.yml /config/' >> /etc/services.d/pihole-dot-doh/run
echo 'cp -n /temp/cloudflared.yml /config/' >> /etc/services.d/pihole-dot-doh/run
# run stubby in background
echo 's6-echo "Starting stubby"' >> /etc/services.d/pihole-dot-doh/run
echo 'stubby -g -C /config/stubby.yml' >> /etc/services.d/pihole-dot-doh/run
# run cloudflared in foreground
echo 's6-echo "Starting cloudflared"' >> /etc/services.d/pihole-dot-doh/run
echo '/usr/local/bin/cloudflared --config /config/cloudflared.yml' >> /etc/services.d/pihole-dot-doh/run

# finish file
echo '#!/usr/bin/with-contenv bash' > /etc/services.d/pihole-dot-doh/finish
echo 's6-echo "Stopping stubby"' >> /etc/services.d/pihole-dot-doh/finish
echo 'killall -9 stubby' >> /etc/services.d/pihole-dot-doh/finish
echo 's6-echo "Stopping cloudflared"' >> /etc/services.d/pihole-dot-doh/finish
echo 'killall -9 cloudflared' >> /etc/services.d/pihole-dot-doh/finish
