#! /bin/bash

SPLUNK_FILE="splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz"
SPLUNK_VERSION=`echo ${SPLUNK_FILE} | sed 's/-/ /g' | awk '{print $2}'`

SPLUNK_URL="https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=${SPLUNK_VERSION}&product=splunk&filename=${SPLUNK_FILE}&wget=true"

groupadd -g 501 splunk
useradd -u 501 -g 501 splunk --shell /bin/bash

echo "Download Splunk from ${SPLUNK_URL}"
wget -nv -O /opt/${SPLUNK_FILE} ${SPLUNK_URL}

tar zxf /opt/${SPLUNK_FILE} -C /opt/

chown -R splunk:splunk /opt/splunk

sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme

/opt/splunk/bin/splunk enable boot-start -user splunk
