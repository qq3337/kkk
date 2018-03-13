#!/bin/bash
# Install Shadowsocks on CentOS 7

echo "Installing Shadowsocks..."

work_path=$(dirname $(readlink -f $0))

random-string()
{
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

KCP_FILE=s
CONFIG_FILE=/etc/shadowsocks.json
SERVICE_FILE=/etc/systemd/system/shadowsocks.service
SERVICE_KCP_FILE=/etc/systemd/system/kcp.service
SS_PASSWORD=$(random-string 32)
SS_PORT=1299
KCP_PORT=4000
SS_METHOD=aes-256-cfb
SS_IP=`ip route get 1 | awk '{print $NF;exit}'`
GET_PIP_FILE=/tmp/get-pip.py

# install pip
curl "https://bootstrap.pypa.io/get-pip.py" -o "${GET_PIP_FILE}"
python ${GET_PIP_FILE}

# install shadowsocks
pip install --upgrade pip
pip install shadowsocks

# create shadowsocls config
cat <<EOF | sudo tee ${CONFIG_FILE}
{
  "server": "0.0.0.0",
  "server_port": ${SS_PORT},
  "password": "${SS_PASSWORD}",
  "method": "${SS_METHOD}"
}
EOF

#kcptun
wget https://github.com/xtaci/kcptun/releases/download/v20180305/kcptun-linux-amd64-20180305.tar.gz
tar -zxvf kcptun-linux-amd64-20180305.tar.gz

#kcptun run file
cat <<EOF | tee ${KCP_FILE}
#!/bin/bash
pids=\`ps auaux | grep '[s]erver_linux_amd64' | awk '{print \$2}'\`
kill -s 9 \${pids}
${work_path}/server_linux_amd64 -t "127.0.0.1:${SS_PORT}" -l ":${KCP_PORT}" -mode fast3 --log /var/log/kcp.log
EOF

chmod a+x ${KCP_FILE}


# create ss service
cat <<EOF | sudo tee ${SERVICE_FILE}
[Unit]
Description=Shadowsocks

[Service]
TimeoutStartSec=0
ExecStart=/usr/bin/ssserver -c ${CONFIG_FILE}

[Install]
WantedBy=multi-user.target
EOF

# create kcp service
cat <<EOF | sudo tee ${SERVICE_KCP_FILE}
[Unit]
Description=kcp

[Service]
TimeoutStartSec=0
ExecStart=${work_path}/s

[Install]
WantedBy=multi-user.target
EOF

# start service
systemctl enable shadowsocks
systemctl start shadowsocks

systemctl enable kcp
systemctl start kcp

#firewall
sudo firewall-cmd --permanent --add-port=${SS_PORT}/tcp
sudo firewall-cmd --permanent --add-port=${KCP_PORT}/udp
sudo firewall-cmd --reload

# view service status
sleep 5
systemctl status shadowsocks -l

echo "================================"
echo ""
echo "Congratulations! Shadowsocks has been installed on your system."
echo "You shadowsocks connection info:"
echo "--------------------------------"
echo "server:      ${SS_IP}"
echo "server_port: ${SS_PORT}"
echo "password:    ${SS_PASSWORD}"
echo "method:      ${SS_METHOD}"
echo "--------------------------------"