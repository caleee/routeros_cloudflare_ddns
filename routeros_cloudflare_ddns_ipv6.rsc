:local DEBUG "off";
:local CLOUD "no";
:local INTERFACE "pppoe-out1";
:local ZONEID "****************************";
:local RECORDID6 "****************************";
:local URLPRE "https://api.cloudflare.com/client/v4/zones/"
:local URL6 ("$URLPRE"."$ZONEID/dns_records/$RECORDID6");
:local TOKEN "****************************";
:local TYPE6 "AAAA";
:local DOMAIN "ddns.example.com";
:local TTL "1";

:global currentIPv6;
:global previousIPv6;

:log info "DDNS-CF-v6 \"Start executing the Cloudflare DDNS update script.\"";

:if ($CLOUD = "yes") do={
    :set currentIPv6 [/ip cloud get public-address-ipv6];
} else={
    :local CIDR6 [/ipv6 address get [find interface=pppoe-out1 and address~"2"] address];
    :set currentIPv6 [:pick "$CIDR6" 0 [:find "$CIDR6" "/"]];
}

:if ("$currentIPv6" = "$previousIPv6") do={
    :log info "DDNS-CF-v6 \"The public IP address has not changed, no update is needed.\"";
} else={
    :log info "DDNS-CF-v6 \"Start updating domain name resolution records.\"";
    /tool fetch http-method=put mode=https output=none url="$URL6" check-certificate=no \
        http-header-field="Authorization:Bearer $TOKEN,content-type:application/json" \
        http-data="{\"type\":\"$TYPE6\",\"name\":\"$DOMAIN\",\"content\":\"$currentIPv6\",\"ttl\":$TTL}";
    :set previousIPv6 "$currentIPv6";
    :log info "DDNS-CF-v6 \"Update domain name resolution record successfully.\"";
}

:if ($DEBUG = "on") do={
    :log info "DDNS-CF-DEBUG-v6 \"Current IP address: $currentIPv6\"";
    :log info "DDNS-CF-DEBUG-v6 \"Previous IP address: $previousIPv6\"";
}
