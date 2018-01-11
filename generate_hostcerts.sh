#!/bin/bash
#description : This script manages (generate+send+get) certificate requests
#              towards the GridKa CA service.
#author      : Xavier Mol, Pavel Weber
#date        : 11.01.2018
#version     : 1.2
#notes       : The number of hosts is not limited.
#              Host names are read from stdin - one per line.
#              After a successful retrieval of the requested host certificate,
#                the request will be removed from that cache.

usercert="$HOME/.globus/usercert.pem"
userkey="$HOME/.globus/userkey.pem"
kit_ca_chain_url='https://pki.pca.dfn.de/kit-ca/pub/cacert/chain.txt'
domain=
organisation=
ra_name=
ra_id=
salut='Herr'
email=
phone=
declare -a aliases
out=/tmp
comment=
mode=
usercache="$HOME/.hostcert_requests"

usage () {
  cat <<EOF
usage: $(basename $0) -M <run-mode> [options]

== Runmodes ==
The script has different run-modes (-M):
* REQUEST
  Request new host certificates, host names are read from stdin.
* GET
  Retrieve host certificates, again, host names are read from stdin.
* DROP
  Dismiss requests for those hosts read from stdin.
* GETALL
  Attempt to retrieve finalized certificates for all current requests.
* LIST
  List all requests found in the cache directory.
* PURGE
  Completely purge the cache of current requests.
Either of these must be selected!

== Mandatory request operands ==
Even though the following operands look like options, they are actually
mandatory in REQUEST run-mode.

  -E MAIL
    The email address submitted when issuing requests.
  
  -I RA_ID
    The ID number of the Registration Authority (RA) administrator. See
    https://gridka-ca.kit.edu/info/RA.php for the right ID, or
    ask your RA what the appropriate ID in your case is.

  -O ORGANISATION
    The OU-part of the host's DN
    (e.g. "/C=DE/O=GermanGrid/OU=KIT/CN=any-host.kit.edu"). Refer to
    https://gridka-ca.kit.edu/info/RA.php if you are unsure.

  -P NUMBER
    The phone number submitted when issuing requests (ignored otherwise).
  
  -R RA_ADMIN
    The name of the Registration Authority (RA) administrator. See
    https://gridka-ca.kit.edu/info/RA.php for your responsible admin, or
    ask your RA what the appropriate name in your case is.
  
  
== Options ==
All following options are optional or are initialized with default values.

  -a ALIAS[,ALIAS,...]
    A comma-seperated list of alternative host names to be included
    with _all_ requests, ignored otherwise.
    It is also possible to add aliases for a specific hostname, by listing
    them on the same line. I.e. the first word read per line is the primary
    hostname and all others will be included as an alias.
  
  -c FILE
    Set the user certificate to be used for generating requests.
    Default: $usercert
  
  -d DOMAINSUFFIX
    The domain will be appended to all host names.
  
  -f
    You will be addressed as a female, male by default.
   
  -h
    Print this usage information and exit.
  
  -k FILE
    Set the private user key to be used when generating new requests.
    You will be prompted for a password if the key is encrypted.
    Default: $userkey
  
  -m COMMENT
    A comment that will be supplied to all requests (ignored otherwise).
  
  -o DIR
    The output directory, where host keys and certificates will be put after
    successful retrieval (ignored otherwise) - $out by default.
  
  -u DIR
    Use DIR for caching new requests instead of a (hidden) directory
    in HOME ($usercache).
EOF
}

# In case there are alternative names for a host, we can include them
# in the request by writing a short openssl configuration file.
print_config () {
  cat <<EOF
[req]
# This section and attribute must exist, even though potentially nothing is configured.
distinguished_name = required
req_extensions     = v3_req
[required]
[v3_req]
subjectAltName = "$the_sans"
EOF
}

# Check that a file is a valid host certificate.
verify_cert () {
  openssl x509 -in "$1" -noout
}

req_certs () {
  if [ -z "$organisation" -o -z "$phone" -o -z "$email" -o -z "$ra_name" -o -z "$ra_id" ]
  then
    echo "At least one of the mandatory operands for the REQUEST run-mode is missing!" >&2
    usage >&2
    exit 1
  fi
  
  echo "Requesting new host certificates as $email."
  echo "Reading private user key..."
  tmp=mktemp && { exec 3>"$tmp"; unlink "$tmp"; }
  openssl rsa <"$userkey" >&3
  
  while read hn more
  do
    # If $domain is set, append it with an extra '.' separator.
    hn="$hn${domain:+.$domain}"
    the_sans=$(echo -n "DNS:$hn"
      for h in "${aliases[@]}" $more
      do
        echo -n ", DNS:$h${domain:+.$domain}"
      done
    )
    local reqfile="$usercache/$hn.hostreq.pem"
    local keyfile="$usercache/$hn.hostkey.pem"
    
    if [ -e "$reqfile" ]
    then
      echo "Found an open request for $hn. Skipping..."
      continue
    fi
    
    # Generate a new request for this host.
    echo "Generate new request file for $hn..."
    /usr/bin/openssl req \
      -newkey rsa:2048 -nodes \
      -keyout "$keyfile" \
      -out "$reqfile" \
      -subj "/C=DE/O=GermanGrid/OU=$organisation/CN=$hn"\
      -config <( print_config ) || {
        rc=$?
        echo "Failed to generate new request!" >&2
        /bin/rm "$reqfile" "$keyfile" 2>/dev/null
        exit $rc
      }
    
    # Proceed to submit the request to the GridKa CA.
    echo "Submit request for $hn to CA..."
    /usr/bin/curl -sS\
      --cert "$usercert"\
      --key /proc/$$/fd/3\
      --cacert "$kit_ca_chain"\
      --form anrede="$salut"\
      --form email="$email"\
      --form telefon="$phone"\
      --form raname=$ra_name\
      --form ra_ID=$ra_id\
      --form anmerkung="$comment $the_sans"\
      --form pemfile="@$reqfile"\
      --form button=absenden\
      --form requesttyp=2\
      https://gridka-ca.kit.edu/sec/pem_req2.php >/dev/null || {
        rc=$?
        echo "Failed to submit the request to the GridKa CA!" >&2
        /bin/rm "$reqfile" "$keyfile" 2>/dev/null
        exit $rc
      }
  done
}

get_certs () {
  while read hn
  do
    # In GETALL runmode, we get the actual file names from find.
    if [ "$mode" == 'GETALL' ]
    then
      local reqfile="$usercache/$hn"
      local keyfile="$usercache/${hn/hostreq/hostkey}"
      local certfile="$usercache/${hn/hostreq/hostcert}"
      hn="${hn%.hostreq.pem}"
    else
      hn="$hn${domain:+.$domain}"
      local reqfile="$usercache/$hn.hostreq.pem"
      local keyfile="$usercache/$hn.hostkey.pem"
      local certfile="$usercache/$hn.hostcert.pem"
    fi
          
    /usr/bin/curl -s -o "$certfile" \
      "https://gridka-ca.kit.edu/abholen3.php?hostname=$hn"
    
    # Check whether the file produced can be parsed successfully as a
    # host certificate (the exit status for the GridKa CA's php script is
    # always 0, even if no certificate was provided or any error occured).
    if verify_cert "$certfile"
    then
      echo "Fetched the host certificate of $hn."
    else
      echo "Failed to fetch the certificate for $hn!" >&2
      /bin/rm "$certfile" &>/dev/null
    fi
    
    if [ -s "$certfile" -a -s "$keyfile" ]
    then
      echo "Move the new host certificate and key to $out..."
      /bin/mv -v "$certfile" "$keyfile" "$out/" \
        && /bin/rm "$reqfile" 2>/dev/null
    elif [ -s "$certfile" ]
    then
      echo "The host certificate was fetched and will be moved to $out..."
      /bin/mv -v "$certfile" "$out/" \
        && /bin/rm "$reqfile" 2>/dev/null
    fi
  done
}

drop () {
  while read h
  do
    h="$h${domain:+.$domain}"
    echo "Drop the request for $h"
    /bin/rm -v "$usercache/$h.hostreq.pem"
  done
}

purge () {
  echo -n "Clear cache $usercache ... "
  /bin/rm -fr "$usercache" && echo "Done!"
}

while getopts "d:E:I:M:O:P:R:a:c:fhk:m:o:z:u:" opt
do
  case "$opt" in
    d) domain="$OPTARG";;
    E) email="$OPTARG";;
    I) ra_id="$OPTARG";;
    M) mode="$OPTARG";;
    O) organisation="$OPTARG";;
    P) phone="$OPTARG";;
    R) ra_name="$OPTARG";;
    a) IFS=, read -a aliases <<<"$OPTARG";;
    c) usercert="$OPTARG";;
    f) salut='Frau';;
    h) usage && exit;;
    k) userkey="$OPTARG";;
    m) comment="$OPTARG";;
    o) out="$OPTARG";;
    u) usercache="$OPTARG";;
    esac
done

if [ -z "$mode" ]
then
  echo -e "No run-mode was selected!\n" >&2
  usage >&2
  exit 1
fi

# Directory to spool requests 
if [ ! -d "$usercache" ]
then
  mkdir -p "$usercache" || { echo "$usercache is missing!" >&2; exit 2; }
fi

# Fetch the KIT-CA cert chain pem file.
kit_ca_chain="$usercache/kit-ca-chain.pem"
if [ ! -f "$kit_ca_chain" ]
then
  wget -q "$kit_ca_chain_url" -O "$kit_ca_chain"
fi

case "$mode" in
  LIST)
    echo "Current requests found in $usercache..."
    find $usercache -type f -name *.hostreq.pem -printf " * %f\n" |\
      sed 's/.hostreq.pem//';;
  REQUEST)
    req_certs;;
  GET)
    get_certs;;
  GETALL)
    find $usercache -type f -name *.hostreq.pem -printf "%f\n" | get_certs;;
  DROP)
    drop;;
  PURGE)
    purge;;
  *)
  echo "Invalid run-mode '$mode' selected - note that the runmode identifier is case-sensitive!" >&2
    usage >&2
    exit 1;;
esac
