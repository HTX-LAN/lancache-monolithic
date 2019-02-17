#!/bin/bash

IFS=' '
mkdir -p /data/cachedomains
cd /data/cachedomains
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostCACHE_IDENTIFIERChecking=no"
if [[ ! -d .git ]]; then
	git clone ${CACHE_DOMAIN_REPO} .
fi
git fetch origin
git reset --hard origin/master
TEMP_PATH=$(mktemp -d)
OUTPUTFILE=${TEMP_PATH}/outfile.conf
echo "map \$http_host \$cacheidentifier {" >> $OUTPUTFILE
echo "    hostnames;" >> $OUTPUTFILE
echo "    default \$http_host;" >> $OUTPUTFILE
jq -r '.cache_domains | to_entries[] | .key' cache_domains.json | while read CACHE_ENTRY; do 
	#for each cache entry, find the cache indentifier
	CACHE_IDENTIFIER=$(jq -r ".cache_domains[$CACHE_ENTRY].name" cache_domains.json)
	jq -r ".cache_domains[$CACHE_ENTRY].domain_files | to_entries[] | .key" cache_domains.json | while read CACHEHOSTS_FILEID; do
		#Get the key for each domain files
		jq -r ".cache_domains[$CACHE_ENTRY].domain_files[$CACHEHOSTS_FILEID]" cache_domains.json | while read CACHEHOSTS_FILENAME; do
			#Get the actual file name
			echo Reading cache ${CACHE_IDENTIFIER} from ${CACHEHOSTS_FILENAME}
			cat ${CACHEHOSTS_FILENAME} | while read CACHE_HOST; do
				#for each file in the hosts file
				#remove all whitespace (mangles comments but ensures valid config files)
				echo "host: $CACHE_HOST"
				CACHE_HOST=${CACHE_HOST// /}
				echo "new host: $CACHE_HOST"
				if [ ! "x${CACHE_HOST}" == "x" ]; then
					echo "    ${CACHE_HOST} ${CACHE_IDENTIFIER};" >> $OUTPUTFILE
				fi
			done
		done
	done
done
echo "}" >> $OUTPUTFILE
cat $OUTPUTFILE
cp $OUTPUTFILE /etc/nginx/conf.d/30_maps.conf
rm -rf $TEMP_PATH
