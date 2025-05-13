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
###########################################################################
## Common Parameters
########################################################################### 
#
# @param location
#   The location on disk where the scripts are installed
# @param config
#   The file containing the configuration for the scripts. 
#   Note: The directory for this configuration file must previously exist, or be managed in a seperate Puppet resource.
# @param authentication_method
#   Method to use for token retrieval. Valid values are 'private_key' to use a Client ID and Private Key or 'oauth' to use
#   a web client based authentication workflow.
# @param github_client_id
#   The GitHub App Client ID associated with the source repository.
#   Required for both authentication methods.
# @param token_file
#   File location in which to store the GitHub Access Token. In OAuth mode, this token will expire every 8 hours.
# @param python_bin
#   The location of the python3 binary to use for the scripts.
#
###########################################################################
## Private Key Authentication Method Parameters
########################################################################### 
#
# @param github_app_private_key
#   Github App private key. Must be associated with the Github App 'client_id'
#   Required for 'private_key' authentication only. 
# @param github_app_private_key_file
#   File location in which to store the GitHub Private Key.
#   Required for 'private_key' authentication only. 
#
###########################################################################
## OAuth Authentication Method Parameters
########################################################################### 
#
# @param github_client_secret
#   The GitHub App Client Secret associated with the GitHub App Client ID
#   Required for 'OAuth' authentication only. 
# @param github_oauth_login_url
#   The GitHub Oauth Login URL.
#   Required for 'OAuth' authentication only. 
# @param github_token_url
#   The GitHub Oauth Token Endpoint URL
#   Required for 'OAuth' authentication only. 
# @param token_expiry_file
#   File location in which to store the expiry time for the GitHub Access Token
#   Required for 'OAuth' authentication only. 
# @param refresh_token_file
#   File location in which to store the GitHub Refresh Token. By default, this token will expire every 6 months.
#   Required for 'OAuth' authentication only. 
# @param refresh_threshold
#   Time (in seconds) in which to flag the GitHub Access Token as stale and to be refreshed.
#   Required for 'OAuth' authentication only. 
# @param callback_uri
#   Callback URL which the user will be forwarded to once they authorize access to GitHub in the early phase of the workflow.
#   NOTE: This must be explicitly set to be the same as the configured Callback URL in the GitHub App itself.
#   Required for 'OAuth' authentication only. 
# @param callback_html
#   The location to place the local callback html file. 
#   Required for 'OAuth' authentication only. 
# @param get_code_uri
#   URL which the user will use to start the GitHub App authentication process.
#   Required for 'OAuth' authentication only. 
# @param get_code_html
#   The location to place the local getcode html file. 
#   Required for 'OAuth' authentication only. 
# @param web_root
#   Location to use for web form files. Must be accessible by pe-nginx service.
#   Required for 'OAuth' authentication only. 
# @param notify_urls
#   If set to true, this will create a notify resource on every puppet run. Useful for initial configuration if you need to see the URLs,
#   but should be turned off for regular operations.
# @param scope
#   This is the scope used for the GitHub App Token request.
#   Required for 'OAuth' authentication only. 
#
class github_app_pe_oauth_management (
  Stdlib::Absolutepath $location                     = '/opt/puppetlabs/github_app_pe_oauth_management',
  Stdlib::Absolutepath $config                       = '/etc/puppetlabs/github_app_pe_oauth_management_config.json',
  Enum['private_key','oauth'] $authentication_method = 'private_key',
  Sensitive[String[1]] $github_client_id             = Sensitive('<GITHUB_CLIENT_ID>'),
  Sensitive[String[1]] $github_client_secret         = Sensitive('<GITHUB_CLIENT_SECRET>'),
  Stdlib::HTTPSUrl $github_oauth_login_url           = 'https://github.com/login/oauth/authorize',
  Stdlib::HTTPSUrl $github_token_url                 = 'https://github.com/login/oauth/access_token',
  Sensitive[String[1]] $github_app_private_key       = Sensitive('<GITHUB_APP_PRIVATE_KEY>'),
  Stdlib::Absolutepath $github_app_private_key_file  = '/etc/puppetlabs/github_app_private_key.pem',
  Stdlib::Absolutepath $token_file                   = '/etc/puppetlabs/github_oauth_token',
  Stdlib::Absolutepath $token_expiry_file            = '/etc/puppetlabs/github_oauth_token_expiry',
  Stdlib::Absolutepath $refresh_token_file           = '/etc/puppetlabs/github_oauth_refresh_token',
  Integer $refresh_threshold                         = 14400,
  Stdlib::Absolutepath $web_root                     = '/opt/puppetlabs/server/data/packages/public',
  String[1] $callback_html                           = 'github_app_callback.html',
  String[1] $get_code_html                           = 'github_app_get_code.html',
  Stdlib::HTTPSUrl $get_code_uri                     = "https://${facts['clientcert']}:8140/packages/github_app_get_code.html",
  Stdlib::HTTPSUrl $callback_uri                     = "https://${facts['clientcert']}:8140/packages/github_app_callback.html",
  Boolean $notify_urls                               = false,
  String[1] $scope                                   = 'repo',
  Stdlib::Absolutepath $python_bin                   = '/usr/bin/python3',
) {
  #
  # Module defaults
  #
  $common_scripts = [
    'check_current_token.py',
    'ghpe_functions.py',
  ]
  $private_key_scripts = [
    'retrieve_github_app_token.py',
  ]
  $oauth_scripts = [
    '1_get_github_app_code.py',
    '2_exchange_code_for_token.py',
    '3_check_refresh_needed.py',
    '4_refresh_token.py',
  ]

  File {
    ensure => file,
    owner => 'root',
    group => 'pe-puppet',
  }
  $directory_permissions = { mode  => '0750', }
  $config_permissions    = { mode  => '0640', }
  $script_permissions    = { mode  => '0750', }
  $web_permissions       = { mode  => '0644', }
  #
  # Check pe_status_check and trusted fact to ensure we only apply onto a puppet/server
  #
  if $facts['pe_status_check_role']=='primary' {
    #
    # Manage python package requirements
    #
    ensure_resource('package','python3-lxml', { 'ensure' => present, })

    #
    # Manage config.json file
    #
    file { $config:
      content => epp("${module_name}/config.json.epp", {
          github_client_id            => $github_client_id,
          github_client_secret        => $github_client_secret,
          github_app_private_key_file => $github_app_private_key_file,
          github_oauth_login_url      => $github_oauth_login_url,
          github_token_url            => $github_token_url,
          token_file                  => $token_file,
          token_expiry_file           => $token_expiry_file,
          refresh_token_file          => $refresh_token_file,
          refresh_threshold           => $refresh_threshold,
          callback_uri                => $callback_uri,
          scope                       => $scope,
      }),
      *       => $config_permissions,
    }

    if $authentication_method == 'private_key' {
      #
      # Manage Github App Private Key
      #
      file { $github_app_private_key_file:
        content => $github_app_private_key,
        *       => $config_permissions,
      }
    }

    #
    # Manage scripts depending on selected authentication method
    #
    $managed_scripts = $authentication_method ? {
      'private_key' => $common_scripts + $private_key_scripts,
      default => $common_scripts + $oauth_scripts,
    }
    $absent_scripts =  $authentication_method ? {
      'private_key' => $oauth_scripts,
      default => $private_key_scripts,
    }
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
    $absent_scripts.each | $script | {
      file { "${location}/${script}": ensure => absent, }
    }

    #
    # Get Code and Callback HTML forms to show code
    #
    $query_string="client_id=${github_app_pe_oauth_management::urlencode($github_client_id.unwrap)}&redirect_uri=${github_app_pe_oauth_management::urlencode($callback_uri)}&scope=${github_app_pe_oauth_management::urlencode($scope)}&state=${seeded_rand_string(20, '', '0123456789abcdef')}" #lint:ignore:140chars
    file { "${web_root}/${get_code_html}":
      content => epp("${module_name}/github_app_get_code.html.epp", {
          url => "${github_oauth_login_url}?${query_string}",
      }),
      *       => $web_permissions,
    }
    file { "${web_root}/${callback_html}":
      content => epp("${module_name}/github_app_callback.html.epp", {}),
      *       => $web_permissions,
    }

    #
    # Show URLs if notify_urls is enabled
    #
    if $notify_urls {
      notify { 'github_app_hompage_url':
        message => "GitHub App Homepage URL: ${get_code_uri}",
      }
      notify { 'github_app_callback_url':
        message => "GitHub App Callback URL: ${callback_uri}",
      }
    }
  }
}
