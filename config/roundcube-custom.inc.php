<?php
// Custom Roundcube settings (loaded by the image on top of the generated config).

// ManageSieve: lets users create server-side filters and forwarding/vacation rules.
$config['managesieve_host'] = 'mailserver';
$config['managesieve_port'] = 4190;
$config['managesieve_conn_options'] = [
    'ssl' => ['verify_peer' => false, 'verify_peer_name' => false],
];
$config['managesieve_usetls'] = true;
$config['managesieve_default'] = '/etc/dovecot/sieve/global.sieve';
$config['managesieve_vacation'] = 1;      // vacation/auto-reply UI
$config['managesieve_forward'] = 1;       // "Forwarding" tab in Settings
$config['managesieve_kolab_master'] = false;

// Do not verify the self-signed cert of the internal mailserver connection.
$config['imap_conn_options'] = [
    'ssl' => ['verify_peer' => false, 'verify_peer_name' => false],
];
$config['smtp_conn_options'] = [
    'ssl' => ['verify_peer' => false, 'verify_peer_name' => false],
];

// Usability
$config['product_name'] = 'Webmail';
$config['support_url'] = '';
$config['message_show_email'] = true;
$config['prefer_html'] = true;
$config['htmleditor'] = 1;
$config['draft_autosave'] = 60;
$config['check_all_folders'] = true;
$config['session_lifetime'] = 60;
$config['login_lc'] = 2;
$config['mail_pagesize'] = 50;
$config['skin'] = 'elastic';
