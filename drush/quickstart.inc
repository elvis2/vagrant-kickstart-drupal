<?php

/**
 * @file
 * Drush command callback helper functions for the Quickstart module.
 *
 * @see quickstart.drush.inc
 */

/**
 * Executes shell commands.
 *
 * Throws exceptions on errors.
 *
 * @param string $command
 *   The command to run.
 * @param bool $throw_exception
 *   TRUE if an exception should be thrown on error or FALSE if not.
 */
function quickstart_shell_exec($command, $throw_exception = TRUE) {
  // Note: for shell commands: 0=success, non-zero=error code.
  $ret = drush_shell_exec($command);
  if ($throw_exception && !$ret) {
    $msg = "Command returned unexpected result: {$command}";
    $output = drush_shell_exec_output();
    foreach ($output as $line) {
      $msg = "\n  {$line}";
    }
    throw new Exception($msg);
  }
}

/**
 * Runs SQL on a local mysql database.
 *
 * @param string $sql
 *   The SQL code to be run.
 * @param string $dbuser
 *   The database user.
 * @param string $dbpassword
 *   The database password.
 */
function quickstart_mysql_exec($sql, $dbuser, $dbpassword) {
  quickstart_shell_exec("echo \"{$sql}\" | mysql -u{$dbuser} -p{$dbpassword}");
}

/**
 * Dereferences paths.
 *
 * @param string $path
 *   A path to dereference.
 *
 * @return string
 *   The dereferenced path.
 */
function quickstart_fixpath($path) {
  // Fix ~'s.
  $home_dir = getenv('HOME');
  $dereferenced_path = str_replace('~', $home_dir, $path);
  // Realpath fails on non-existant folders. So it's hard to fix .'s and ..'s.
  return $dereferenced_path;
}

/**
 * Configures DNS for a domain.
 *
 * Adds an entry to /etc/hosts on the local machine, identified by
 * "#quickstart".
 *
 * @param string $domain_name
 *   The domain name.
 */
function quickstart_create_dns($domain_name) {
  $hosts_file = file_get_contents('/etc/hosts');

  // Pad the domain name with spaces for searching, to prevent partial matches.
  $padded_domain_name = " {$domain_name} ";

  if (!strpos($hosts_file, $padded_domain_name)) {
    $entry = PHP_EOL . "127.0.0.1 {$domain_name} #quickstart";
    file_put_contents('/etc/hosts', $entry, FILE_APPEND | LOCK_EX);
  }
  else {
    $message = dt('DNS has already been configured for @domain.', array(
      '@domain' => $domain_name,
    ));
    throw new Exception($message);
  }
}

/**
 * Destroys the DNS.
 *
 * Removes the entry from /etc/hosts file on the local machine.
 *
 * @param string $domain
 *   The domain name.
 */
function quickstart_destroy_dns($domain) {
  quickstart_shell_exec("sudo sed -i \"/ {$domain} .*#quickstart/d\" /etc/hosts");
}

/**
 * Creates an Apache virtual host.
 *
 * Enables the virtual host and restarts Apache.
 *
 * @param string $domain_name
 *   The domain name.
 * @param string $document_root
 *   The path to the document root.
 */
function quickstart_create_apache($domain_name, $document_root) {
  // Make sure the document root exists.
  if (!file_exists($document_root)) {
    mkdir($document_root, 0777, TRUE);
  }

  // Create the vhost file.
  $vhost = file_get_contents(__DIR__ . '/templates/vhost.txt');
  $vhost = str_replace('#DOMAIN#', $domain_name, $vhost);
  $vhost = str_replace('#DOCROOT#', $document_root, $vhost);
  file_put_contents("/etc/apache2/sites-available/{$domain_name}", $vhost, LOCK_EX);

  // Enable the vhost and restart Apache.
  quickstart_shell_exec("sudo a2ensite {$domain_name}");
  quickstart_shell_exec('sudo apache2ctl restart');
}

/**
 * Destroys the apache virtual hosts config.
 *
 * @param string $domain
 *   The domain name.
 */
function quickstart_destroy_apache($domain) {
  quickstart_shell_exec("sudo a2dissite {$domain}", FALSE);
  $filename = "/etc/apache2/sites-available/{$domain}";
  if (file_exists($filename)) {
    unlink($filename);
  }
  quickstart_shell_exec('sudo apache2ctl restart');
}

/**
 * SQL for creating a database.
 *
 * CREATE USER causes trouble. Note GRANT ALL ON *.* for site-install.
 */
define('DATABASE_CREATE', "
GRANT USAGE ON *.* TO #DOMAIN#@localhost IDENTIFIED BY '#DOMAIN#' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
CREATE DATABASE IF NOT EXISTS #DOMAIN#;
GRANT ALL PRIVILEGES ON *.* TO #DOMAIN#@localhost;
FLUSH PRIVILEGES;");

/**
 * SQL for destroying a database.
 *
 * We GRANT before DROP USER to make sure there is something to drop. USAGE is
 * synonym for 'no priveledges'.
 */
define('DATABASE_DESTROY', "
GRANT USAGE ON *.* TO #DOMAIN#@localhost;
DROP USER #DOMAIN#@localhost;
DROP DATABASE IF EXISTS #DOMAIN#;
FLUSH PRIVILEGES;");

/**
 * Creates the database.
 *
 * Runs SQL. Replaces .'s with _'s in domain name to get the database name,
 * database username, and password.
 *
 * @param string $dbuser
 *   The database user.
 * @param string $dbpassword
 *   The database password.
 * @param string $domain
 *   The domain name, with dots (.) replaced with underscores (_).
 */
function quickstart_create_database($dbuser, $dbpassword, $domain_) {
  $sql = str_replace('#DOMAIN#', $domain_, DATABASE_CREATE);
  quickstart_mysql_exec($sql, $dbuser, $dbpassword);
}

/**
 * Destroys the database using SQL.
 *
 * @param string $dbuser
 *   The database user.
 * @param string $dbpassword
 *   The database password.
 * @param string $domain
 *   The domain name, with dots (.) replaced with underscores (_).
 */
function quickstart_destroy_database($dbuser, $dbpassword, $domain_) {
  $sql = str_replace('#DOMAIN#', $domain_, DATABASE_DESTROY);
  quickstart_mysql_exec($sql, $dbuser, $dbpassword);
}

/**
 * Downloads the code using drush make.
 *
 * If path already exists, moves it to path.old.
 *
 * @param string $domain
 *   The domain name.
 * @param string $codepath
 *   The code path.
 * @param string $makefile
 *   The make file path.
 */
function quickstart_create_code($domain, $codepath, $makefile) {
  if (file_exists($codepath)) {
    // @todo This will cause collision if run on the same directory more than
    //   once. There needs to be more testing for edge cases.
    drush_move_dir($codepath, "{$codepath}.old");
    drush_log("Moved existing directory {$codepath} to {$codepath}.old", "ok");
  }
  if (!file_exists($makefile)) {
    // Try to find makefile in ~/websites folder.
    $makefile = quickstart_fixpath($makefile);
    if (!file_exists($makefile)) {
      throw new Exception("Make file {$makefile} not found.");
    }
  }
  drush_invoke_process(
    '@self',
    'make',
    array($makefile, $codepath),
    array('--prepare-install'),
    array('#integrate' => TRUE)
  );
  drush_invoke_process(
    '@self',
    'quickstart-fixperms',
    array(),
    array("--domain={$domain}", "--codepath={$codepath}"),
    array('#integrate' => TRUE)
  );
}

/**
 * Deletes the site's code.
 *
 * @param string $codepath
 *   The code path.
 */
function quickstart_destroy_code($codepath) {
  // Only delete a web folder. "drush qsd --codepath=/" would be bad.
  if (!file_exists("{$codepath}/index.php")) {
    drush_log(dt('Invalid code path detected. Files were not deleted.'), 'warning');
    return;
  }
  drush_delete_dir($codepath, TRUE);
}

/**
 * Installs a site.
 *
 * @param string $domain
 *   The domain name.
 * @param array $params
 *   An associative array of parameters.
 */
function quickstart_create_install($domain, $params) {
  // Detect the Drupal version from the CHANGELOG.txt file.
  $dversion = 'unknown';
  $codepath = $params['codepath'];

  // CHANGELOG.txt lives in the core directory in d8. Test for it there first.
  $changelog = "{$codepath}/core/CHANGELOG.txt";
  if (!file_exists($changelog)) {
    $changelog = "{$codepath}/CHANGELOG.txt";
  }
  $str = file_get_contents($changelog);
  if (preg_match('/^Drupal 6./m', $str)) {
    $dversion = 'd6';
  }
  // Regex magic.
  if (preg_match('/^Drupal 7./m', $str)) {
    $dversion = 'd7';
  }
  elseif (preg_match('/^Drupal 8./m', $str)) {
    $dversion = 'd8';
  }

  // D6 specific.
  if ($dversion == 'd6') {
    // D6 and D7 have different names for the default profile.
    if ($params['profile'] == 'standard') {
      $params['profile'] = "default";
    }
    // Copy default.settings.php to settings.php and change URL and prefix.
    $str = file_get_contents("{$codepath}/sites/default/default.settings.php");
    $str = str_replace('mysql://username:password@localhost/databasename', $params['db-url'], $str);
    $str = str_replace("\$db_prefix = ''", $params['db-prefix'], $str);
    file_put_contents("{$codepath}/sites/{$params['sites-subdir']}/settings.php", $str);
  }

  // Nuff foreplay, let's install!
  $opts = array(
    "--root={$params['codepath']}",
    "--db-url={$params['db-url']}",
    "--db-prefix={$params['db-prefix']}",
    "--account-name={$params['account-name']}",
    "--account-pass={$params['account-pass']}",
    "--account-mail={$params['account-mail']}",
    "--locale={$params['locale']}",
    "--clean-url={$params['clean-url']}",
    "--site-name={$params['site-name']}",
    "--site-mail={$params['site-mail']}",
    "--sites-subdir={$params['sites-subdir']}",
  );

  drush_invoke_process(
    '@self',
    'site-install',
    array($params['profile']),
    $opts,
    array('#integrate' => TRUE)
  );

  // D7 specific.
  if ($dversion == 'd7') {
    // Create a private files folder. This is done to make fix-perms not break
    // configuring a private files directory.
    if (!file_exists("{$codepath}/sites/default/files_private")) {
      quickstart_shell_exec("sudo mkdir {$codepath}/sites/default/files_private");
    }
    drush_invoke_process(
      '@self',
      'variable-set',
      array('file_private_path', 'sites/default/files_private'),
      array('--always-set', "--root={$codepath}"),
      array('#integrate' => TRUE)
    );
    drush_invoke_process(
      '@self',
      'quickstart-fixperms',
      array(),
      array("--domain={$domain}", "--codepath={$codepath}"),
      array('#integrate' => TRUE)
    );
  }

  drush_log("\nURL: http://{$params['domain']}\nAdmin user: {$params['account-name']}\nAdmin password: {$params['account-pass']}", 'ok');
}

/**
 * Creates a cron job.
 *
 * All cron jobs are run as the web server user to avoid file permissions
 * conflicts.
 *
 * @param string $domain
 *   The domain name.
 * @param string $codepath
 *   The codepath.
 */
function quickstart_create_cron($domain, $codepath) {
  // Get the current crontab.
  drush_shell_exec('sudo crontab -u www-data -l');
  $crontab = drush_shell_exec_output();

  $new_cron_job = "0 * * * * drush --uri={$domain} --root={$codepath} core-cron";

  // Prevent duplicates.
  if (in_array($new_cron_job, $crontab)) {
    drush_log(dt('A cron job already exists for this site.'), 'warning');
    return;
  }

  // Add the new cron job.
  array_push($crontab, $new_cron_job);
  $crontab = implode($crontab, PHP_EOL);
  drush_shell_exec("echo '{$crontab}' | sudo crontab -u www-data -");
}

/**
 * Destroys a cron job.
 *
 * @param string $domain
 *   The domain name.
 * @param string $codepath
 *   The codepath.
 */
function quickstart_destroy_cron($domain, $codepath) {
  // Get the current crontab.
  drush_shell_exec('sudo crontab -u www-data -l');
  $crontab = drush_shell_exec_output();

  $cron_job = "0 * * * * drush --uri={$domain} --root={$codepath} core-cron";

  // Find the cron job, if it exists.
  $position = array_search($cron_job, $crontab);
  if ($position === FALSE) {
    drush_log(dt('The site had no cron job.'), 'warning');
  }

  // Remove the cron job.
  unset($crontab[$position]);
  $crontab = implode($crontab, PHP_EOL);
  drush_shell_exec("echo '{$crontab}' | sudo crontab -u www-data -");
}
