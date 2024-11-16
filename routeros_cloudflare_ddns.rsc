:local DEBUG "off";
:local CLOUD "no";
:local INTERFACE "pppoe-out1";
:local ZONEID "****************************";
:local RECORDID "****************************";
:local RECORDID6 "****************************";
:local URLPRE "https://api.cloudflare.com/client/v4/zones/"
:local URL ("$URLPRE""$ZONEID/dns_records/$RECORDID");
:local URL6 ("https://api.cloudflare.com/client/v4/zones/" . "$ZONEID/dns_records/$RECORDID6");
:local TOKEN "****************************";
:local TYPE "A";
:local TYPE6 "AAAA";
:local DOMAIN "ddns.example.com";
:local TTL "1";

:global currentIPv4;
:global currentIPv6;
:global previousIPv4;
:global previousIPv6;

:log info "DDNS-CF \"Start executing the Cloudflare DDNS update script.\"";

:if ($CLOUD = "yes") do={
    :set currentIPv4 [/ip cloud get public-address];
    :set currentIPv6 [/ip cloud get public-address-ipv6];
} else={
    :local CIDR [/ip address get [find interface="$INTERFACE"] address];
    :local CIDR6 [/ipv6 address get [find interface="$INTERFACE"] address];
    :set currentIPv4 [:pick "$CIDR" 0 [:find "$CIDR" "/"]];
    :set currentIPv6 [:pick "$CIDR6" 0 [:find "$CIDR6" "/"]];
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
    :log info "DDNS-CF-DEBUG \"Current IPv4 address: $currentIPv4\"";
    :log info "DDNS-CF-DEBUG \"Current IPv6 address: $currentIPv6\"";
    :log info "DDNS-CF-DEBUG \"Previous IPv4 address: $previousIPv4\"";
    :log info "DDNS-CF-DEBUG \"Previous IPv6 address: $previousIPv6\"";
}
