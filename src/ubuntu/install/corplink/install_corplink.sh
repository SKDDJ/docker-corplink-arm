#!/usr/bin/env bash
set -ex

apt update
apt install supervisor privoxy jq -y
sed -i '/^listen-address/d' /etc/privoxy/config
echo 'listen-address 0.0.0.0:8118' >>/etc/privoxy/config

# Corplink service
mkdir -p /var/log/corplink/
cat <<EOF >/etc/supervisor/conf.d/corplink.conf
[program:corplink]
command=/opt/Corplink/corplink-service
autostart=true
autorestart=true
stderr_logfile=/var/log/corplink/stderr.log
stdout_logfile=/var/log/corplink/stdout.log
EOF

# Privoxy
mkdir -p /var/log/privoxy
cat <<EOF >/etc/supervisor/conf.d/privoxy.conf
[program:privoxy]
command=/usr/sbin/privoxy --no-daemon /etc/privoxy/config
autostart=true
autorestart=true
stderr_logfile=/var/log/privoxy/stderr.log
stdout_logfile=/var/log/privoxy/stdout.log
EOF

# Socks5 server
mkdir -p /var/log/socks5/
cat <<EOF >/etc/supervisor/conf.d/socks5.conf
[program:socks5]
command=/usr/local/bin/socks5
autostart=true
autorestart=true
stderr_logfile=/var/log/socks5/stderr.log
stdout_logfile=/var/log/socks5/stdout.log
EOF

# Automatic fix dns
cat <<EOF >/usr/local/bin/fixdns.sh
#!/bin/bash
set -x
while true; do
  sleep 5
  dns=\$(jq -r '.DNS[0]' /opt/Corplink/vpn.conf  2>/dev/null)
  [ -z "\$dns" ] && continue
  grep -q "\$dns" /etc/resolv.conf && continue
  echo "nameserver \${dns}" >/etc/resolv.conf
done
EOF
chmod +x /usr/local/bin/fixdns.sh
mkdir -p /var/log/fixdns/
cat <<EOF >/etc/supervisor/conf.d/fixdns.conf
[program:fixdns]
command=/usr/local/bin/fixdns.sh
autostart=true
autorestart=true
stderr_logfile=/var/log/fixdns/stderr.log
stdout_logfile=/var/log/fixdns/stdout.log
EOF

# Download corplink and extract files manually instead of using package manager
wget -q -O corplink.deb https://oss-s3.ifeilian.com/linux/FeiLian_Linux_arm64_v2.2.25_r4432_0e49cd.deb

# Extract deb package manually to avoid systemd service activation during installation
mkdir -p /tmp/corplink_extract
dpkg-deb -x corplink.deb /tmp/corplink_extract
# Install only the application files, not the service
mkdir -p /opt/Corplink
cp -r /tmp/corplink_extract/opt/Corplink/* /opt/Corplink/
# Copy desktop file
mkdir -p /usr/share/applications
cp -f /tmp/corplink_extract/usr/share/applications/corplink.desktop /usr/share/applications/ || true
# Cleanup
rm -rf /tmp/corplink_extract
rm corplink.deb

# Create desktop shortcut
mkdir -p $HOME/Desktop/
cp /usr/share/applications/corplink.desktop $HOME/Desktop/ || true
chmod +x $HOME/Desktop/corplink.desktop || true
