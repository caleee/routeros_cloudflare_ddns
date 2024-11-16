:local DEBUG "off";
:local CLOUD "no";
:local INTERFACE "pppoe-out1";
:local ZONEID "****************************";
:local RECORDID "****************************";
:local URL ("https://api.cloudflare.com/client/v4/zones/" . "$ZONEID/dns_records/$RECORDID");
:local TOKEN "****************************";
:local TYPE "A";
:local DOMAIN "ddns.example.com";
:local TTL "1";

:global currentIPv4;
:global previousIPv4;

:log info "DDNS-CF-v4 \"Start executing the Cloudflare DDNS update script.\"";

:if ($CLOUD = "yes") do={
    :set currentIPv4 [/ip cloud get public-address];
} else={
    :local CIDR [/ip address get [find interface="$INTERFACE"] address];
    :set currentIPv4 [:pick "$CIDR" 0 [:find "$CIDR" "/"]];
}

:if ("$currentIPv4" = "$previousIPv4") do={
    :log info "DDNS-CF-v4 \"The public IP address has not changed, no update is needed.\"";
} else={
    :log info "DDNS-CF-v4 \"Start updating domain name resolution records.\"";
    /tool fetch http-method=put mode=https output=none url="$URL" check-certificate=no \
        http-header-field="Authorization:Bearer $TOKEN,content-type:application/json" \
        http-data="{\"type\":\"$TYPE\",\"name\":\"$DOMAIN\",\"content\":\"$currentIPv4\",\"ttl\":$TTL}";
    :set previousIPv4 "$currentIPv4";
    :log info "DDNS-CF-v4 \"Update domain name resolution record successfully.\"";
}

:if ($DEBUG = "on") do={
    :log info "DDNS-CF-DEBUG-v4 \"Current IP address: $currentIPv4\"";
    :log info "DDNS-CF-DEBUG-v4 \"Previous IP address: $previousIPv4\"";
}
