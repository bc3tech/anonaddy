#!/usr/bin/env sh
set -eu

domain="${ANONADDY_DOMAIN:-example.com}"
hostname="${ANONADDY_HOSTNAME:-mail.${domain}}"
all_domains="${ANONADDY_ALL_DOMAINS:-${domain}}"
mynetworks="${POSTFIX_MYNETWORKS:-172.28.0.0/16}"
tls_cert_file="${POSTFIX_TLS_CERT_FILE:-/etc/postfix/certs/tls.crt}"
tls_key_file="${POSTFIX_TLS_KEY_FILE:-/etc/postfix/certs/tls.key}"

mkdir -p /etc/postfix/certs /var/log/mail /var/spool/postfix
touch /var/log/mail/mail.log
chown root:root /var/log/mail/mail.log
chmod 0644 /var/log/mail/mail.log

if [ ! -s "${tls_cert_file}" ] || [ ! -s "${tls_key_file}" ]; then
    openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
        -subj "/CN=${hostname}" \
        -keyout "${tls_key_file}" \
        -out "${tls_cert_file}"
fi

printf '%s\n' "${domain}" > /etc/mailname

username_domain_clauses=''
for mail_domain in $(printf '%s' "${all_domains}" | tr ',' ' '); do
    case "${mail_domain}" in
        *[!A-Za-z0-9.-]*|'')
            echo "Invalid domain in ANONADDY_ALL_DOMAINS: ${mail_domain}" >&2
            exit 1
            ;;
    esac

    if [ -z "${username_domain_clauses}" ]; then
        username_domain_clauses="CONCAT(username, '.${mail_domain}')"
    else
        username_domain_clauses="${username_domain_clauses}, CONCAT(username, '.${mail_domain}')"
    fi
done

cat > /etc/postfix/mysql-virtual-alias-domains-and-subdomains.cf <<EOF
user = ${DB_USERNAME:-anonaddy}
password = ${DB_PASSWORD:-secret}
hosts = ${DB_HOST:-mysql}
dbname = ${DB_DATABASE:-anonaddy}
query = SELECT (SELECT 1 FROM usernames WHERE '%s' IN (${username_domain_clauses})) AS usernames, (SELECT 1 FROM domains WHERE domain = '%s' AND domain_verified_at IS NOT NULL) AS domains LIMIT 1;
EOF

chmod 0640 /etc/postfix/mysql-virtual-alias-domains-and-subdomains.cf
chgrp postfix /etc/postfix/mysql-virtual-alias-domains-and-subdomains.cf

postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "biff = no"
postconf -e "append_dot_mydomain = no"
postconf -e "readme_directory = no"
postconf -e "compatibility_level = 3.6"
postconf -e "myhostname = ${hostname}"
postconf -e "mydomain = ${domain}"
postconf -e "myorigin = /etc/mailname"
postconf -e "mydestination = localhost.\$mydomain, localhost"
postconf -e "virtual_transport = anonaddy:"
postconf -e "virtual_mailbox_domains = \$mydomain, unsubscribe.\$mydomain, mysql:/etc/postfix/mysql-virtual-alias-domains-and-subdomains.cf"
postconf -e "relayhost ="
postconf -e "mynetworks = 127.0.0.0/8 [::1]/128 ${mynetworks}"
postconf -e "mailbox_size_limit = 0"
postconf -e "recipient_delimiter = +"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "local_recipient_maps ="
postconf -e "smtpd_tls_cert_file = ${tls_cert_file}"
postconf -e "smtpd_tls_key_file = ${tls_key_file}"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtpd_tls_CApath = /etc/ssl/certs"
postconf -e "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1"
postconf -e "smtpd_tls_loglevel = 1"
postconf -e "smtp_tls_CApath = /etc/ssl/certs"
postconf -e "smtp_tls_security_level = may"
postconf -e "smtp_tls_loglevel = 1"
postconf -e "smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1"
postconf -e "smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination"
postconf -e "smtpd_helo_required = yes"
postconf -e "smtpd_helo_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname, reject_unknown_helo_hostname"
postconf -e "smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain, reject_unknown_reverse_client_hostname"
postconf -e "smtpd_recipient_restrictions = permit_mynetworks, reject_unauth_destination, check_policy_service unix:private/policy, reject_rhsbl_helo dbl.spamhaus.org, reject_rhsbl_reverse_client dbl.spamhaus.org, reject_rhsbl_sender dbl.spamhaus.org, reject_rbl_client zen.spamhaus.org"
postconf -e "smtpd_data_restrictions = reject_unauth_pipelining"
postconf -e "disable_vrfy_command = yes"
postconf -e "strict_rfc821_envelopes = yes"
postconf -e "maillog_file = /var/log/mail/mail.log"

cp /etc/postfix/master.cf.dist /etc/postfix/master.cf
cat >> /etc/postfix/master.cf <<'EOF'

# Pipe to addy.io application
anonaddy unix - n n - - pipe
  flags=F user=www-data argv=php /var/www/html/artisan anonaddy:receive-email --sender=${sender} --recipient=${recipient} --local_part=${user} --extension=${extension} --domain=${domain} --size=${size}

# addy.io access policy
policy  unix  -       n       n       -       0       spawn
  user=www-data argv=php /var/www/html/postfix/AccessPolicy.php
EOF

postfix check
exec postfix start-fg
