# openwrt-vpngate
 vpngate.net client for OpenWRT

## Description
This script allows to pull server list from vpngate public VPN server registry and filter
it by country, score, maximum ping and uptime.

Once server that matches requested criteria found, script will setup openvpn
instance via UCI and perform connection test.

Extra config for openvpn can be added to `/etc/vpngate.include`

## Examples
* find any working server and setup openvpn instance with default name (vpngate):
```
root@OpenWRT:~# vg
```
* find server in the United States and setup openvpn instance named us01:
```
root@OpenWRT:~# vg -c us us01
```
* find server in the United States and setup openvpn instance named `us01` in disabled state:
```
root@OpenWRT:~# vg -c us -d us01
```
* find server in the United States or Great Britain, if none available, fallback to any location:
```
root@OpenWRT:~# vg -c us,gb,any
```
* find any server with ping that is less than 20 ms:
```
root@OpenWRT:~# vg -p 20
```
* find any server in Japan with ping that is less than 30 ms:
```
root@OpenWRT:~# vg -c jp -p 30
```
* force server list update and find any server with score greater than 10000:
```
root@OpenWRT:~# vg -U -s 10000
```
