FROM zabbix/zabbix-proxy-sqlite3:6.0-ubuntu-latest

USER root

ENV TERM=xterm ZBX_VERSION=6.0.21 ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git MIBDIRS=/var/lib/mibs/ietf:/var/lib/mibs/iana:/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL ZBX_TLSPSKFILE=/etc/zabbix/zabbix_proxy.psk ZBX_TLSPSKIDENTITY=proxy1 ZBX_TLSCONNECT=psk ZBX_ENABLEREMOTECOMMANDS=1 ZBX_SERVER_HOST=90.85.33.105 ZBX_HOSTNAME=PSO-VEN-ZPROXY ZBX_PROXYOFFLINEBUFFER=96 ZBX_PROXYHEARTBEATFREQUENCY=900 ZBX_CONFIGFREQUENCY=7200 ZBX_DATASENDERFREQUENCY=900 ZBX_IPMIPOLLERS=3 ZBX_STARTVMWARECOLLECTORS=3 ZBX_VMWAREFREQUENCY=3600 ZBX_VMWAREPERFFREQUENCY=3600 ZBX_VMWARECACHESIZE=16M ZBX_CACHESIZE=16M

RUN apt-get -y update && apt-get install -y zabbix-agent

RUN service zabbix-agent start

RUN update-rc.d zabbix-agent enable

COPY SNMPv2-PDU /var/lib/mibs/ietf/SNMPv2-PDU

ENTRYPOINT ["/usr/bin/tini" "--" "/usr/bin/docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_proxy" "--foreground" "-c" "/etc/zabbix/zabbix_proxy.conf"]