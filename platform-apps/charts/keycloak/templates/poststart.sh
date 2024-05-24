#!/bin/bash
#
# Bootstrap Backstage Client 
#

# creates user, set credentials, adds to group
function create_user() {
  username=$1
  group=$2
  email="$3"
  firstName="$4"
  lastName="$5"

  if [[ -n "$firstName" && -n "$lastName" ]]; then
    ./kcadm.sh create users -r sx-cnp-oss -s username=$username -s enabled=true -s emailVerified=true -s email="$email" -s firstName=$firstName -s lastName=$lastName
  else
    ./kcadm.sh create users -r sx-cnp-oss -s username=$username -s enabled=true -s emailVerified=true -s email="$email"
  fi

  ./kcadm.sh set-password -r sx-cnp-oss --username $username --new-password test --temporary=false
  
  # fetch user and group id
  userid=$(./kcadm.sh get users -r sx-cnp-oss -q username=$username --fields id --format csv --noquotes)
  groupid=$(./kcadm.sh get groups -r sx-cnp-oss --noquotes --format csv | grep ",$group" | cut -d, -f1)
  
  # no group membership yet, but add
  ./kcadm.sh update users/$userid/groups/$groupid -r sx-cnp-oss -s realm=sx-cnp-oss -s userId=$userid -s groupId=$groupid -n
  ./kcadm.sh get users/$userid/groups -r sx-cnp-oss
}

###### MAIN ######################
sleepSeconds="${1:-30}"
echo "going to wait for initialization/stabilization of server, sleeping for $sleepSeconds"
#sleep $sleepSeconds
sleep 60

cd /opt/keycloak/bin

# login
./kcadm.sh config credentials --realm master --user admin --password admin --server http://localhost:8080

# create realm
./kcadm.sh create realms -f /tmp/sx-cnp-oss.realm.json
#./kcadm.sh create clients -r sx-cnp-oss -f /tmp/backstage.exported.json
#./kcadm.sh create partialImport -r sx-cnp-oss -s ifResourceExists=FAIL -o -f /tmp/sx-cnp-oss.realm.json

# create realm
#./kcadm.sh create realms -s realm=sx-cnp-oss -s enabled=true -o

# disable 'rsa-enc-generated' key for realm to avoid JWKS 'RSA-OAEP' key types which jwt module cannot parse
component_id=$(./kcadm.sh get components -r sx-cnp-oss -q name=rsa-enc-generated --fields id --format csv --noquotes)
./kcadm.sh update components/$component_id -r sx-cnp-oss -s 'config.active=["false"]'
./kcadm.sh update components/$component_id -r sx-cnp-oss -s 'config.enabled=["false"]'

# creates users in various groups
create_user demouser group1 demouser@platform-engineer.cloud demuser sx-cnp-oss
create_user phac users phac@platform-engineer.cloud Philipp Achmueller
create_user jokl users jokl@platform-engineer.cloud Johannes Kleinlercher
create_user backstageadmin admins backstageadmin@platform-engineer.cloud Backstage Admin

# create client from json placed into container (secret will be generated upon import)
#./kcadm.sh create clients -r sx-cnp-oss -f /tmp/backstage.exported.json

# get secret for 'backstage' that was just generated upon import
clientid=$(./kcadm.sh get clients -r sx-cnp-oss -q clientId=backstage --fields id --format csv --noquotes)
clientsecret=$(./kcadm.sh get clients/$clientid/client-secret -r sx-cnp-oss --fields value --format csv --noquotes)
outfile=/tmp/keycloak.properties
touch $outfile
chmod 666 $outfile
echo "realm=sx-cnp-oss" >> $outfile
echo "clientid=backstage" >> $outfile
echo "clientsecret=$clientsecret" >> $outfile
