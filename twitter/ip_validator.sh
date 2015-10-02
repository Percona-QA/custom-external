#!/bin/bash
# User Vars
CLI='/ssd2/mysql-5.5.33.t12-linux-x86_64/bin/mysql -A -uroot -S/ssd2/mysql-5.5.33.t12-linux-x86_64/socket.sock test'
#CLI='/ssd2/mysql-5.5.33-linux-x86_64/bin/mysql -A -uroot -S/ssd2/mysql-5.5.33-linux-x86_64/socket.sock test'

# Program Vars
FUNC='DROP FUNCTION IF EXISTS check_ip; CREATE FUNCTION check_ip(ip CHAR(255)) RETURNS CHAR(20) RETURN IF(IS_IPV4(ip)=1,IF(INET_ATON(ip) IS NOT NULL,IF(INET6_ATON(ip) IS NOT NULL,IF(INET_NTOA(INET_ATON(ip))=ip,"OK (IPV4)",">!FAIL!(a)<"),">!FAIL!(b)<"),">!FAIL!(c)<"),IF(IS_IPV6(ip)=1,IF(INET6_ATON(ip) IS NOT NULL,IF(INET6_NTOA(INET6_ATON(ip))=ip,"OK (IPV6)",">!FAIL!(d)<"),">!FAIL!(e)<"),"NOT_AN_IP"));'

# Human readable copy of $FUNC
# ----------------------------
# DROP FUNCTION IF EXISTS check_ip; 
# CREATE FUNCTION check_ip(ip CHAR(255)) RETURNS CHAR(20) RETURN 
#   IF(IS_IPV4(ip)=1,
#     IF(INET_ATON(ip) IS NOT NULL,
#       IF(INET6_ATON(ip) IS NOT NULL,
#         IF(INET_NTOA(INET_ATON(ip))=ip,
#           "OK (IPV4)"
#         ,
#           ">!FAIL!(a)<")
#       ,
#         ">!FAIL!(b)<")
#     ,
#       ">!FAIL!(c)<")
#   ,
#     IF(IS_IPV6(ip)=1,
#       IF(INET6_ATON(ip) IS NOT NULL,
#         IF(INET6_NTOA(INET6_ATON(ip))=ip,
#           "OK (IPV6)"
#         ,
#           ">!FAIL!(d)<")
#       ,
#         ">!FAIL!(e)<")
#     ,
#       "NOT_AN_IP")
#   )
# ;'

# Create function
echo $FUNC | $CLI

# Check & cleanup function
check_ip(){
  echo "SELECT check_ip($1);" | $CLI | tr '\n' ' ' | sed "s/check_ip(['(]*//;s/[')]*)/DUMMY/;s/$/\n/" | sed "s/\(.*\)DUMMY[ ]*\(.*\)/\2\t\1/" 
  # debug echo "SELECT check_ip($1);" | $CLI 
}

# Start checking, based on contents of file ip_input.txt
rm -f /tmp/ip_validator.tmp
touch /tmp/ip_validator.tmp
while read line
do
  if [ ! "$line" == "" ]; then
    check_ip "$line" >> /tmp/ip_validator.tmp
  fi
done < ./ip_input.txt

# Post processing for mysql-specific IPV6 optimizations
# An IPV6 like 2001:0:9d38:6abd:3c3e:1e4:3f57:d4e9 will be optimized to 2001::9d38:6abd:3c3e:1e4:3f57:d4e9 (:0: becomes ::)
# This function accounts for this optimization by re-qualifying these results
rm -f /tmp/ip_validator.tmp2
touch /tmp/ip_validator.tmp2
grep -v ">!FAIL!(d)<" /tmp/ip_validator.tmp >> /tmp/ip_validator.tmp2
grep ">!FAIL!(d)<" /tmp/ip_validator.tmp | grep -v ":0" >> /tmp/ip_validator.tmp2
grep ">!FAIL!(d)<" /tmp/ip_validator.tmp | grep ":0" | sed 's|>!FAIL!(d)<|CHECK_MANUALLY|' >> /tmp/ip_validator.tmp2
rm -f /tmp/ip_validator.tmp

# Finish
cat /tmp/ip_validator.tmp2 | sort -u
rm -f /tmp/ip_validator.tmp2
