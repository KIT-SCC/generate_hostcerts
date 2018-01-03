# Bulk request host certificates from the GridKa CA
This repository publishes tools that enable bulk requests of new host
certificates issued by the GridKa CA.

## Bash
The bash script `generate_hostcerts.sh` relies on `openssl` and `curl`
to generate new x509 host keys and requests for host certificates, which
then are submitted to the GridKa CA using `curl`. Requests that have been
processed and granted by the CA will be fetched with `curl`, too.

### Usage
#### Run-mode
The script requires the run-mode (`-M`, capitalization matters!) specified
on invocation. The following modes are currently implemented:
<dl>
  <dt>REQUEST</dd>
  <dd>Request new host certificates, host names are read from stdin.</dd>
  
  <dt>GET</dt>
  <dd>Retrieve host certificates, again, host names are read from stdin.</dd>
  
  <dt>DROP</dt>
  <dd>Dismiss requests for those hosts read from stdin.</dd>
  
  <dt>GETALL</dt>
  <dd>Attempt to retrieve finalized certificates for all cached requests.</dd>
  
  <dt>LIST</dt>
  <dd>List all requests found in the cache directory.</dd>
  
  <dt>PURGE</dt>
  <dd>Completely purge the cache.</dd>
</dl>

Either of these *must* be selected!

#### Mandatory request operands
Even though the following operands look like options, they are actually
mandatory in _request_ run-mode.
<dl>
  <dt>-E MAIL</dt>
  <dd>The email address submitted when issuing requests.</dd>
  
  <dt>-I RA_ID</dt>
  <dd>
    The ID number of the Registration Authority (RA) administrator. See
    https://gridka-ca.kit.edu/info/RA.php for the right ID, or
    ask your RA what the appropriate ID in your case is.
  </dd>

  <dt>-O ORGANISATION</dt>
  <dd>
    The OU-part of the host's DN
    (e.g. "/C=DE/O=GermanGrid/OU=KIT/CN=any-host.kit.edu"). Refer to
    https://gridka-ca.kit.edu/info/RA.php if you are unsure.
  </dd>

  <dt>-P NUMBER</dt>
  <dd>The phone number submitted when issuing requests (ignored otherwise).</dd>
  
  <dt>-R RA_ADMIN</dt>
  <dd>
    The name of the Registration Authority (RA) administrator. See
    https://gridka-ca.kit.edu/info/RA.php for your responsible admin, or
    ask your RA what the appropriate name in your case is.
  </dd>
</dl>
  
#### Options
All following options are optional or are initialized with default values.

<dl>
  <dt>-a ALIAS[,ALIAS,...]</dt>
  <dd>
    A comma-seperated list of alternative host names to be included
    with <i>all</i> requests, ignored otherwise.
    It is also possible to add aliases for a specific hostname, by listing
    them on the same line. Ie. the first word read per line is the primary
    hostname and all others will be included as an alias.
  </dd>
  
  <dt>-c FILE</dt>
  <dd>
    Set the user certificate to be used for generating requests.<br />
    <i>Default</i>: <code>$HOME/.globus/usercert.pem</code>
  </dd>
  
  <dt>-d DOMAINSUFFIX</dt>
  <dd>The domain will be appended to all host names.</dd>

  <dt>-f</dt>
  <dd>You will be addressed as a female, male by default.</dd>
   
  <dt>-h</dt>
  <dd>Print the usage information and exit.</dd>
  
  <dt>-k FILE</dt>
  <dd>
    Set the private user key to be used when generating new requests.
    You will be prompted for a password if the key is encrypted.<br />
    <i>Default</i>: <code>$HOME/.globus/userkey.pem</code>
  </dd>
  
  <dt>-m COMMENT</dt>
  <dd>A comment that will be supplied to all requests (ignored otherwise).</dd>
  
  <dt>-o DIR</dt>
  <dd>
    The output directory, where host keys and certificates will be put after
    successful retrieval (ignored otherwise) - <code>/tmp</code> by default.
  </dd>

  <dt>-u DIR</dt>
  <dd>
    Use DIR for caching new requests instead of a (hidden) directory
    in HOME (<code>$HOME/.hostcert_requests</code>).
  </dd>
</dl>