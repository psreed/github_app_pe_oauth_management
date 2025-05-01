# @summary GitHub App Token management for Puppet Enterprise Code Manager
#
# This module installs and configures a set of scripts designed to manage 
# the workflow associated with the GitHub App Token process and connect with
# the Puppet Enterprise Code Manager service.
#
# This module is meant to be applied to a Puppet Enterprise Primary Server only.
#
# @example
#   include github_app_pe_oauth_management
#
# @param location
#   The location on disk where the scripts are installed
# @param config
#   The file containing the configuration for the scripts. 
#   Note: The directory for this configuration file must previously exist, or be managed in a seperate Puppet resource.
# @param github_client_id
#   The GitHub App Client ID associated with the source repository
# @param github_client_secret
#   The GitHub App Client Secret associated with the GitHub App Client ID
# @param github_oauth_login_url
#   The GitHub Oauth Login URL.
# @param github_token_url
#   The GitHub Oauth Token Endpoint URL
# @param token_file
#   File location in which to store the GitHub Access Token. By default, this token will expire every 8 hours.
# @param token_expiry_file
#   File location in which to store the expiry time for the GitHub Access Token
# @param refresh_token_file
#   File location in which to store the GitHub Refresh Token. By default, this token will expire every 6 months.
# @param refresh_threshold
#   Time (in seconds) in which to flag the GitHub Access Token as stale and to be refreshed.
# @param callback_uri
#   Callback URL which the user will be forwarded to once they authorize access to GitHub in the early phase of the workflow.
#   NOTE: This must be explicitly set to be the same as the configured Callback URL in the GitHub App itself.
# @param callback_html
#   The location to place the local callback html file. 
# @param get_code_uri
#   URL which the user will use to start the GitHub App authentication process.
# @param get_code_html
#   The location to place the local getcode html file. 
# @param web_root
#   Location to use for web form files. Must be accessible by pe-nginx service.
# @param scope
#   This is the scope used for the GitHub App Token request.
# @param python_bin
#   The location of the python3 binary to use for the scripts
#
class github_app_pe_oauth_management (
  Stdlib::Absolutepath $location             = '/opt/puppetlabs/github_app_pe_oauth_management',
  Stdlib::Absolutepath $config               = '/etc/puppetlabs/github_app_pe_oauth_management_config.json',
  Sensitive[String[1]] $github_client_id     = Sensitive('<GITHUB_CLIENT_ID>'),
  Sensitive[String[1]] $github_client_secret = Sensitive('<GITHUB_CLIENT_SECRET>'),
  Stdlib::HTTPSUrl $github_oauth_login_url   = 'https://github.com/login/oauth/authorize',
  Stdlib::HTTPSUrl $github_token_url         = 'https://github.com/login/oauth/token',
  Stdlib::Absolutepath $token_file           = '/etc/puppetlabs/github_oauth_token',
  Stdlib::Absolutepath $token_expiry_file    = '/etc/puppetlabs/github_oauth_token_expiry',
  Stdlib::Absolutepath $refresh_token_file   = '/etc/puppetlabs/github_oauth_refresh_token',
  Integer $refresh_threshold                 = 14400,
  Stdlib::Absolutepath $web_root             = '/opt/puppetlabs/puppetserver/data/public/packages/',
  Stdlib::Absolutepath $callback_html        = 'github_app_getcode.html',
  Stdlib::Absolutepath $get_code_html         = 'github_app_callback.html', # lint:ignore:140chars
  Stdlib::HTTPSUrl $get_code_uri              = "https://${facts['clientcert']}:8140/packages/github_app_get_code.html",
  Stdlib::HTTPSUrl $callback_uri             = "https://${facts['clientcert']}:8140/packages/github_app_callback.html",
  String[1] $scope                           = 'repo',
  Stdlib::Absolutepath $python_bin           = '/usr/bin/python3',
) {
  #
  # Module defaults
  #
  $managed_scripts = [
    '1_get_github_app_code.py',
    '2_exchange_code_for_token.py',
    '3_check_current_token.py',
    '4_check_refresh_needed.py',
    '5_refresh_token.py',
    'ghpe_functions.py',
  ]
  File {
    ensure => file,
    owner => 'root',
    group => 'pe-puppet',
  }
  $directory_permissions = { mode  => '0750', }
  $config_permissions    = { mode  => '0640', }
  $script_permissions    = { mode  => '0750', }
  #
  # Check pe_status_check and trusted fact to ensure we only apply onto a puppet/server
  #
  if $trusted['extensions']['1.3.6.1.4.1.34380.1.1.9812']=='puppet/server' and $facts['pe_status_check_role']=='primary' {
    #
    # Manage python package requirements
    #
    ensure_resource('package','python3-lxml', { 'ensure' => present, })

    #
    # Manage config.json file
    #
    file { $config:
      content => epp("${module_name}/config.json.epp", {
          github_client_id       => $github_client_id,
          github_client_secret   => $github_client_secret,
          github_oauth_login_url => $github_oauth_login_url,
          github_token_url       => $github_token_url,
          token_file             => $token_file,
          token_expiry_file      => $token_expiry_file,
          refresh_token_file     => $refresh_token_file,
          refresh_threshold      => $refresh_threshold,
          callback_uri           => $callback_uri,
          scope                  => $scope,
      }),
      *       => $config_permissions,
    }

    #
    # Manage scripts
    #
    file { $location:
      ensure => directory,
      *      => $directory_permissions,
    }
    $managed_scripts.each | $script | {
      file { "${location}/${script}":
        content => epp("${module_name}/${script}.epp", {
            python_bin => $python_bin,
            config     => $config,
            location   => $location,
        }),
        *       => $script_permissions,
      }
    }

    #
    # Get Code and Callback HTML forms to show code
    #
    notice("GitHub App Homepage URL: ${get_code_uri}")
    $query_string="client_id=${uriescape($github_client_id)}&redirect_uri=${uriescape($callback_uri)}&scope=${uriescape($scope)}&state=${seeded_rand_string(20, '', '0123456789abcdef')}" #lint:ignore:140chars
    file { "${web_root}/${get_code_html}":
      content => epp("${module_name}/github_app_get_code.html.epp", {
          url => "${github_oauth_login_url}?${query_string}",
      }),
      mode    => '0644',
    }
    notice("GitHub App Callback URL: ${callback_uri}")
    file { "${web_root}/${callback_html}":
      content => epp("${module_name}/github_app_callback.html.epp", {}),
      mode    => '0644',
    }
  }
}
