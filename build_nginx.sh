#!/bin/sh

NGINX_VERSION=1.26.2
DEBIAN_VERSION=bookworm

apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev
apt install -y krb5-multidev libkrb5-dev # krb5

# check https://nginx.org/packages/debian/pool/nginx/n/nginx/
wget -N https://nginx.org/packages/debian/pool/nginx/n/nginx/nginx_${NGINX_VERSION}-1~${DEBIAN_VERSION}_amd64.deb
dpkg-deb -R nginx_${NGINX_VERSION}-1~${DEBIAN_VERSION}_amd64.deb deb_package
# adjust version
sed -i "s/Version: ${NGINX_VERSION}-1~${DEBIAN_VERSION}/Version: ${NGINX_VERSION}-1+live~${DEBIAN_VERSION}/" ./deb_package/DEBIAN/control

# rehash
cd deb_package/
$ find . -type f -not -path "./DEBIAN/*" -exec md5sum {} + | sort -k 2 | sed 's/\.\/\(.*\)/\1/' > DEBIAN/md5sums

# remove unneded files
sed -i '/CHANGES.ru.gz/d' ./deb_package/DEBIAN/md5sums
sed -i '/index.html/d' ./deb_package/DEBIAN/md5sums
sed -i '/50x.html/d' ./deb_package/DEBIAN/md5sums

# grab nginx source
cd ..
wget -N https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xzvf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}

# grab modules
git clone https://github.com/stnoonan/spnego-http-auth-nginx-module.git
git clone https://github.com/openresty/headers-more-nginx-module

# build
./configure --add-module=spnego-http-auth-nginx-module --add-module=headers-more-nginx-module --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-http_v3_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-1.27.3/debian/debuild-base/nginx-1.27.3=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'
make CFLAGS="-I/usr/include/mit-krb5"

#remove debug info
strip ./objs/nginx

# copy new build
cp ./objs/nginx ../deb_package/usr/sbin/nginx

#repack
cd ..
dpkg-deb -b deb_package nginx_${NGINX_VERSION}-1+live~${DEBIAN_VERSION}_amd64.deb
