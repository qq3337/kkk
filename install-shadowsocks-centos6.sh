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
SERVICE_FILE=/etc/init.d/shadowsocksd
SERVICE_KCP_FILE=/etc/init.d/kcpd
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
#!/bin/sh
#
# shadowsocks start/restart/stop shadowsocks
#
# chkconfig: 2345 85 15
# description: start shadowsocks/ssserver at boot time

start(){
        ssserver -c ${CONFIG_FILE} -d start
}
stop(){
        ssserver -c ${CONFIG_FILE} -d stop
}
restart(){
        ssserver -c ${CONFIG_FILE} -d restart
}

case "\$1" in
start)
        start
        ;;
stop)
        stop
        ;;
restart)
        restart
        ;;
*)
        echo "Usage: service {start|restart|stop} shadowscksd"
        exit 1
        ;;
esac

EOF

# create kcp service
cat <<EOF | sudo tee ${SERVICE_KCP_FILE}
#!/bin/sh
#
# shadowsocks start/restart/stop kcp
#
# chkconfig: 2345 85 15
# description: start kcp at boot time

start(){
        ${work_path}/s
}
stop(){
        ${work_path}/s
}
restart(){
        ${work_path}/s
}

case "\$1" in
start)
        start
        ;;
stop)
        stop
        ;;
restart)
        restart
        ;;
*)
        echo "Usage: service {start|restart|stop} kcpd"
        exit 1
        ;;
esac

EOF

chmod a+x ${SERVICE_FILE}
chmod a+x ${SERVICE_KCP_FILE}

# start service
chkconfig --add shadowsocksd
service  shadowsocksd start

chkconfig --add kcpd
service  kcpd start

#firewall
#sudo firewall-cmd --permanent --add-port=${SS_PORT}/tcp
#sudo firewall-cmd --permanent --add-port=${KCP_PORT}/udp
#sudo firewall-cmd --reload
iptables -A INPUT -p tcp --dport ${SS_PORT} -j ACCEPT
iptables -A INPUT -p udp --dport ${KCP_PORT} -j ACCEPT
	
# view service status
sleep 5
service  shadowsocksd status -l

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