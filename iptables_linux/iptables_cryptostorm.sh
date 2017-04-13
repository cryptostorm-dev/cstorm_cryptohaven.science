#!/bin/bash
if [ `id -u` != "0" ]; then
        echo "Error: you must be root to run this script!"
        exit 1
fi
if [ $OSTYPE != "linux-gnu" ]; then
        echo "Error: this script is only for Linux!"
        exit 1
fi
IPT=`command -v iptables`
IPT6=`command -v ip6tables`
if [ $? -ne 0 ]; then
        echo "Error: cannot find iptables on this system."
        exit 1
fi
echo -e "\033[31mWARNING:\033[00m";
echo -e "This script will disconnect you if you are remotely connected to this system\n"
read -rp "Clear current iptables rules? [Y/n]" idunno
idunno=${idunno,,}
if [[ $idunno =~ ^(yes|y|^$) ]]; then
        echo "Flushing existing rules..."
        $IPT -F
	$IPT6 -F
else
        read -rp "Continue with script [Y/n]" whatever
        whatever=${whatever,,}
        if ! [[ $whatever =~ ^(y|yes|^$) ]]; then
                echo "Ok, exiting..."
                exit 1
        fi
fi
read -rp "Apply rules now [Y/n]" surewhynot
surewhynot=${surewhynot,,}
if ! [[ $surewhynot =~ ^(y|yes|^$) ]]; then
        echo "Ok, exiting..."
        exit 1
fi
echo "Applying rules..."
# lines above this one: intro and are you really, really sure you want to do this stuff, courtesy df

$IPT -A INPUT -i lo -j ACCEPT -m comment --comment "Allow loopback device"
$IPT -A OUTPUT -o lo -j ACCEPT -m comment --comment "Allow loopback device"

$IPT -A INPUT -s 127.0.1.1 -j ACCEPT -m comment --comment "resolv"
$IPT -A OUTPUT -d 127.0.1.1 -j ACCEPT -m comment --comment "resolv"

$IPT -A OUTPUT -d 192.168.1.0/24 -p udp --dport 53 -j REJECT -m comment --comment "prevent usage of local DNS server"

$IPT -A OUTPUT  -p udp -m udp -m string --hex-string "|0001|" --algo bm --from 27 --to 28 -m string --hex-string "|2112a442|" --algo bm --from 30 --to 34 -j LOG --log-prefix "STUN binding request : " --log-level 4
$IPT -A OUTPUT  -p udp -m udp -m string --hex-string "|0001|" --algo bm --from 27 --to 28 -m string --hex-string "|2112a442|" --algo bm --from 30 --to 34 -j DROP

$IPT -A INPUT -s 192.168.1.0/24 -j ACCEPT -m comment --comment "allow all local traffic"
$IPT -A OUTPUT -d 192.168.1.0/24 -j ACCEPT -m comment --comment "allow all local traffic"

$IPT -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# alternative 1: starting with all internet traffic blocked, allows okturtles DNS in order to resolve CS addresses against dnscrypt-cert.okturtles.com and create rules, rule allowing okturtles DNS is removed after rules are created. 
$IPT -A OUTPUT -d 192.184.93.146 -p udp --dport 53 -j ACCEPT -m comment --comment "dnscrypt-cert.okturtles.com"
$IPT -A OUTPUT -d 192.184.93.146 -p tcp --dport 53 -j ACCEPT -m comment --comment "dnscrypt-cert.okturtles.com"
nslookup public.deepdns.net 192.184.93.146 |awk  '/Address: /{system ( "iptables -A OUTPUT -d " $2 " -p udp --dport 53 -j ACCEPT -m comment --comment \"cryptostorm-shared.deepdns.net public.deepdns.net public.deepdns.dk\"") }'
nslookup linux-balancer.cstorm.pw 192.184.93.146 |awk  '/Address: /{system ( "iptables -A OUTPUT -d " $2 " -p udp --dport 443 -j ACCEPT -m comment --comment \"linux-balancer.cryptostorm.net\"") }'
nslookup linux.voodoo.network 192.184.93.146 |awk  '/Address: /{system ( "iptables -A OUTPUT -d " $2 " -p udp --dport 443 -j ACCEPT -m comment --comment \"linux.voodoo.network\"") }'
nslookup linux-cryptofree.cryptostorm.net 192.184.93.146 |awk  '/Address: /{system ( "iptables -A OUTPUT -d " $2 " -p udp --dport 443 -j ACCEPT -m comment --comment \"linux-cryptofree.cryptostorm.net\"") }'
$IPT -D OUTPUT -d 192.184.93.146 -p udp --dport 53 -j ACCEPT -m comment --comment "dnscrypt-cert.okturtles.com"
$IPT -D OUTPUT -d 192.184.93.146 -p tcp --dport 53 -j ACCEPT -m comment --comment "dnscrypt-cert.okturtles.com"

# alternative 2: DNS traffic is possible - CS addresses are resolved and rules are created
# host cryptostorm-shared.deepdns.net | awk '{ system ( "iptables -A OUTPUT -d " $4 " -p udp --dport 53 -j ACCEPT -m comment --comment \"cryptostorm-shared.deepdns.net\"")  }'
# host linux-balancer.cryptostorm.net | awk '{ system ( "iptables -A OUTPUT -d " $4 " -p udp --dport 443 -j ACCEPT -m comment --comment \"linux-balancer.cryptostorm.net\"")  }'

$IPT -A OUTPUT -o tun+ -j ACCEPT -m comment --comment "accept all TUN connections"

$IPT -P INPUT DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"
$IPT -P OUTPUT DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"
$IPT -P FORWARD DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"

$IPT -N LOGGING
$IPT -A INPUT -j LOGGING
$IPT -A OUTPUT -j LOGGING
$IPT -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "iptables-dropped: " --log-level 4
$IPT -A LOGGING -j DROP

$IPT6 -P INPUT DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"
$IPT6 -P OUTPUT DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"
$IPT6 -P FORWARD DROP -m comment --comment "set default policies to drop all communication unless specifically allowed"

$IPT6 -N LOGGING
$IPT6 -A INPUT -j LOGGING
$IPT6 -A OUTPUT -j LOGGING
$IPT6 -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "ip6tables-dropped: " --log-level 4
$IPT6 -A LOGGING -j DROP

echo "Done!"
