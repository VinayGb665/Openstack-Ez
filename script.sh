#Compulsory Readme
#To be always run as secret
#Replace C_SERVER ->Controller IP address (everywhere)
#Replace secret with your password(everywhere) do a find and replace
#you need to edit your hosts(/etc/network/hosts) and name your static ip as controller

echo Y | apt install chrony
echo server C_SERVER iburst >> /etc/chrony/chrony.conf
echo allow 10.0.0.0/24 >> /etc/chrony/chrony.conf
service chrony restart
echo Y | apt install software-properties-common
echo Y |add-apt-repository cloud-archive:ocata
apt update && apt dist-upgrade
echo Y | apt install python-openstackclient
echo Y | apt install mariadb-server python-pymysql

echo -e \[mysqld\] \\n bind-address = C_SERVER \\n default-storage-engine = innodb \\n innodb_file_per_table = on \\n max_connections = 4096 \\n collation-server = utf8_general_ci \\n character-set-server = utf8 > /etc/mysql/mariadb.conf.d/99-openstack.cnf
service mysql restart
mysql_secure_installation <<EOF

y
secret
secret
y
y
y
y
EOF
apt install rabbitmq-server
rabbitmqctl add_user openstack secret
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
apt install memcached python-memcache
sed -i '35 s/.*/-l C_SERVER/' /etc/memcached.conf
service memcached restart

mysql <<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY 'secret';
EOF
apt install keystone-manage
sed -i 's/#connection = <None>/connection = mysql+pymysql:\/\/keystone:secret@controller\/keystone/' /etc/keystone/keystone.conf 
sed -i '2842 s/.*/provider = fernet/' /etc/keystone/keystone.conf 
su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password secret --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne
echo ServerName controller >> /etc/apache2/apache2.conf
service apache2 restart
rm -f /var/lib/keystone/keystone.db
export OS_USERNAME=admin
export OS_PASSWORD=secret
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password secret demo
openstack role create user
openstack role add --project demo --user demo user

#----------------------------------------Creating admin-openrc file (Please change the secret if u want different passwords for admin and demo projects)-------

cat <<EOT > admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=secret
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOT

#-----------------------------------------Creating demo-openrc file--------------------------------------------------------------------------------------------
cat <<EOT > demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=secret
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOT
. admin-openrc
openstack token issue

mysql <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'secret';
exit
EOF

openstack user create --domain default --password secret glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292
echo Y | apt install glance 

sed -i 's/#connection = <None>/connection = mysql+pymysql:\/\/glance:secret@controller\/glance/'  /etc/glance/glance-api.conf
sed -i '3283 s/.*/auth_uri \= http\:\/\/controller\:5000\nauth_url \= http\:\/\/controller\:35357\nmemcached_servers \= controller\:11211\nauth_type \= password\nproject_domain_name \= default\nuser_domain_name \= default\nproject_name \= service\nusername \= glance\npassword \= secret\n/' /etc/glance/glance-api.conf
sed -i '4244 s/.*/flavor = keystone/' /etc/glance/glance-api.conf
sed -i '1916 s/.*/stores = file\,http\ndefault_store = file\nfilesystem_store_datadir \= \/var\/lib\/glance\/images\/\n/' /etc/glance/glance-api.conf
sed -i 's/#connection = <None>/connection = mysql+pymysql:\/\/glance:secret@controller\/glance/'  /etc/glance/glance-registry.conf
sed -i '1206 s/.*/auth_uri \= http\:\/\/controller\:5000\nauth_url \= http\:\/\/controller\:35357\nmemcached_servers \= controller\:11211\nauth_type \= password\nproject_domain_name \= default\nuser_domain_name \= default\nproject_name \= service\nusername \= glance\npassword \= secret\n/' /etc/glance/glance-registry.conf
sed -i '2129 s/.*/flavor = keystone/' /etc/glance/glance-registry.conf
su -s /bin/sh -c "glance-manage db_sync" glance

service glance-registry restart

service glance-api restart
#-------------------------------------------------Optional Since its a verification step for glance-api----------------
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

mysql <<EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'secret';

GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'secret';

EOF
. admin-openrc
openstack user create --domain default --password secret nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
openstack user create --domain default --password secret placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin http://controller:8778
echo Y|apt install nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api

sed -i '3379 s/.*/connection \= mysql+pymysql:\/\/nova\:secret\@controller\/nova\_api/' /etc/nova/nova.conf
sed -i '4396 s/.*/connection \= mysql+pymysql:\/\/nova\:secret\@controller\/nova/' /etc/nova/nova.conf
sed -i '3021 s/.*/transport\_url \= rabbit\:\/\/openstack\:secret\@controller/' /etc/nova/nova.conf
sed -i '3085 s/.*/auth_strategy \= keystone/' /etc/nova/nova.conf
sed -i '5597 s/.*/auth_uri \= http\:\/\/controller\:5000\nauth_url \= http\:\/\/controller\:35357\nmemcached_servers \= controller\:11211\nauth_type \= password\nproject_domain_name \= default\nuser_domain_name \= default\nproject_name \= service\nusername \= nova\npassword \= secret/' /etc/nova/nova.conf
sed -i '1481 s/.*/my_ip \= C_SERVER/' /etc/nova/nova.conf
sed -i '2 s/.*/use_neutron \= True\nfirewall_driver \= nova\.virt\.firewall\.NoopFirewallDriver/' /etc/nova/nova.conf
sed -i '2 s/.*/enabled \= true\nvncserver\_listen \= $my\_ip\nvncserver\_proxyclient\_address \= $my\_ip/' /etc/nova/nova.conf

sed -i '4939 s/.*/api\_servers \= http\:\/\/controller\:9292/' /etc/nova/nova.conf
sed -i '7262 s/.*/lock\_path \= \/var\/lib\/nova\/tmp/' /etc/nova/nova.conf
sed -i '8109 s/.*/os\_region\_name \= RegionOne\nproject\_domain\_name \= Default\nproject\_name \= service\nauth\_type \= password\nuser\_domain\_name \= Default\nauth\_url \= http\\:\/\/controller\:35357\/v3\nusername \= placement\npassword \= secret/' /etc/nova/nova.conf
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
openstack catalog list
openstack image list
nova-status upgrade check

mysql <<EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'secret';
EOF
. admin-openrc
openstack user create --domain default --password secret neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696

#----Networking /Neutron part is under construction hang in there--
#apt install neutron-server neutron-plugin-ml2 \
#  neutron-linuxbridge-agent neutron-dhcp-agent \
 # neutron-metadata-agent
#sed -i '860 s/.*/password\=secret/' /etc/neutron/neutron.conf
#sed -i '1111 s/.*/password\=secret/' /etc/neutron/neutron.conf
 #--------------------------------------------------------------------
 

apt install openstack-dashboard
sed -i '161 s/.*/OPENSTACK_HOST \= \"controller\"/' /etc/openstack-dashboard/local_settings.py
sed -i '29 s/.*/ALLOWED\_HOSTS \= \[\"\*\"\]/' /etc/openstack-dashboard/local_settings.py
sed -i '130 s/.*/SESSION\_ENGINE \= \"django\.contrib\.sessions\.backends\.cache\"/' /etc/openstack-dashboard/local_settings.py
sed -i '134 s/.*/\t\"LOCATION\"\: "controller\:11211\"\,/' /etc/openstack-dashboard/local_settings.py
sed -i '66 s/.*/OPENSTACK\_KEYSTONE\_MULTIDOMAIN_SUPPORT \= True/' /etc/openstack-dashboard/local_settings.py
sed -i '62 s/.*/OPENSTACK\_API\_VERSIONS \= \{\n\t\"identity\"\: 3\,\n\t\"image\"\: 2\,\n\t\"volume\"\: 2\,\n\}/' /etc/openstack-dashboard/local_settings.py
sed -i '78 s/.*/OPENSTACK\_KEYSTONE\_DEFAULT\_DOMAIN \= \"Default\"/' /etc/openstack-dashboard/local_settings.py
sed -i '167 s/.*/OPENSTACK\_KEYSTONE\_DEFAULT\_ROLE \= \"user\"/' /etc/openstack-dashboard/local_settings.py
service apache2 reload
sudo chown www-data /var/lib/openstack-dashboard/secret_key
sudo service apache2 reload
openstack user create --domain default --password secret swift
openstack role add --project service --user swift admin
openstack service create --name swift \
  --description "OpenStack Object Storage" object-store
openstack endpoint create --region RegionOne \
  object-store public http://controller:8080/v1/AUTH_%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  object-store internal http://controller:8080/v1/AUTH_%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  object-store admin http://controller:8080/v1
echo -e Y\nY\nY |apt-get install swift swift-proxy python-swiftclient \
  python-keystoneclient python-keystonemiddleware \
  memcached
mkdir  /etc/swift
touch /etc/swift/proxy-server.conf
curl -o /etc/swift/proxy-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/proxy-server.conf-sample?h=stable/newton
cp ./proxy-server.conf /etc/swift/proxy-server.conf
sed -i "337 s/.*/password \= secret/" /etc/swift/proxy-server.conf
sed -i "2 s/.*/bind_ip \= C\_SERVER/" /etc/swift/proxy-server.conf
