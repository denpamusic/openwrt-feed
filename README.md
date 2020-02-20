# openwrt-feed ![OpenWRT feed](https://github.com/denpamusic/openwrt-feed/workflows/OpenWRT%20feed/badge.svg?branch=master)  
OpenWRT feed by denpamusic

## Buildroot
```bash
[ ! -f "feeds.conf" ] && cp feeds.conf.default feeds.conf
echo src-git denpamusic https://github.com/denpamusic/openwrt-feed.git >> feeds.conf
```

## Device
```sh
wget -P /etc/opkg/keys/ http://openwrt.denpa.pro/keys/4b148d164b058d87
echo src/gz denpamusic http://openwrt.denpa.pro/packages >> /etc/opkg/customfeeds.conf
```
