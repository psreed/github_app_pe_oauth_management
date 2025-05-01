# github_app_pe_oauth_management

This module installs and configures a set of scripts designed to manage the workflow associated with the GitHub App Token process and connect with the Puppet Enterprise Code Manager service.
This includes a set of Tasks and Python scripts to aid in the management of GitHub App authentication workflow.
Create a GitHub App for your organization, then use this to manage the authentication and refresh workflow for OAuth tokens used for Puppet Enterprise Code Manager.

## Requirements & Setup

***Note: This process works for Puppet Enterprise version 2023 (and later) only. Previous versions os PE require additional custom configuration for Code Manager to properly handle HTTPS/OAuth workflow based code deployment.***

1\. Have your control repository (and other private Puppet module repositories) available on GitHub and ensure they are part of the GitHub organization you would like to use.

2\. Create a "GitHub App" (not an "OAuth App") within GitHub. Ensure the App has permissions to the specific (or all organization) repos. 
`Contents: Read` permissions will be required for Puppet Code Manager to read content. You will need `Read and Write` permissions if using CD4PE based pipelines (CD4PE creates branches for managing code deployment workflow).

**GitHub App Setting should be as follows:**

NOTE: The Homepage and Callback URLs below should NOT be accessible from GitHub. They only need to be accessible from your browser within your own internal network for the workflow.

*Basic Information*
```
GitHub App Name: Puppet Enterprise - OAuth Token Integration
GitHub App Description: Puppet Enterprise OAuth Integration to support GitHub Token workflow for Puppet automated code deployment pipelines.
Homepage URL: https://<Puppet Primary Server FQDN>:8140/packages/github_app_get_code.html
```

*Identifying and authorizing users*
```
Callback URL: https://<Puppet Primary Server FQDN>:8140/packages/github_app_callback.html
Request user authentication (OAuth) during installation: [Unchecked] (optional)
Enable Device Flow: [Checked]
```

*Post Installation* - All options left blank and unchecked

*Webhook* - All options left blank and unchecked

3\. Install the GitHub App into your organization in GitHub. Ensure both a Client secret and private key are generated.

Make note of the `Client ID` and `Client Secret` as they will be needed for the next step. (Note: The `Client Secret` will only be shown once when created).

4\. Create encrypted hiera configuration and assign your GitHub App `Client ID` and `Client Secret` from the previous step to `github_app_pe_oauth_management::github_client_id` and `github_app_pe_oauth_management::github_client_secret`.

This hiera data should be applied at the `node level` to your Puppet Enterprise **Primary server only**.

**Example hiera config**
```
lookup_options:
 "^github_app_pe_oauth_management::github_client_*":
   convert_to: "Sensitive"

github_app_pe_oauth_management::github_client_id: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBAD
  MIt1/Niie1TfthJ7OaRyR3OH1Gz9PKDU6yEuxEsTL66vBDJNoPLWwQJJywSd
  goaxtGhg9mODBOBjA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBBQzareth
  xpvSKMscqqc4gpgBD9Azvt5IrG/iLQi0cT0SlI]

github_app_pe_oauth_management::github_client_secret: >
  ENC[PKCS7,MIIBiQYJKoZIhvcNAQcDoIIBejCCAXYCAQAxggEhMIIBHQIBAD
  AFMAACAQEwDQYJKoZIhvcNAQEBBQAEggEAFTGDJpDNp7KI5GzSi8Suj9fyMu
  UuB3sCdAt+lGTegCCRrNnVnUmYnCIaulVjGCBwcEak4fb/tckd89aa7cT8ig
  ==]
```

5\. Assign (classify) the module to your Puppet Primary server and configure other non-sensitive values appropriately.

6\. Run the `puppet agent` on your Puppet Primary server to apply the configuration. 

7\. Configure code manager as appropriate for your configuration. Note that you will need to modify the HTTPS URL provided by GitHub for the source repository to use the keyword `oauth2@` as the username part of the repo string.

For example, `https://github.com/myorg/control-repo.git` would become `https://oauth2@github.com/myorg/control-repo.git`

**Example Code Manager Configuration**
```
puppet_enterprise::profile::master::code_manager_auto_configure: true
puppet_enterprise::profile::master::r10k_private_key:
puppet_enterprise::profile::master::r10k_remote: https://oauth2@github.com/myorg/control-repo.git
puppet_enterprise::master::code_management::git_oauth_token: /etc/puppetlabs/github_oauth_token
```

Note: The `r10k_private_key` is intentionally left blank.

# Usage

When the module is applied, a set of Python scripts are generated from EPP templates and configured for use on your Primary Puppet server.

These scripts help facilitate the authorization workflow of obtaining and refreshing an OAuth Access Token from GitHub for your Puppet infrastructure to use with Code Manager deployments.

### 1\. Starting the workflow and obtaining a GitHub App Access Code

The module generated web page located at `https://<puppet server>:8140/packages/github_app_get_code.html` OR the `1_get_github_app_code.py` script will initiate the authentication workflow and provide a GitHub App code for the next step.

Using the web page is preferred if possible, but if using the python script, it will provide a URL to be copied and pasted into your web browser to start the process.

### 2\. Exchange the GitHub App Access Code for an Access Token

Run the `2_exchange_code_for_token.py` python script to exchange the access code for a set of OAuth tokens (Access and Refresh) for use with Puppet Enterprise Code Manager.

The functions in this script will obtain and write the tokens to files specified in the module parameters and also ensure that user/group permissions are set appropriately for Code Manager to be able to read the OAuth token from the file.

### 3\. Check a token for validity

The `3_check_token.py` script is provided for information purposes only. It will output json formatted information about the current GitHub Access Token. If this script fails, the token is likely invalid, expired or has been revoked and the workflow should be restarted at Step 1.

### 4\. Check for token freshness or expiry

The `4_check_refresh_needed.py` script is used to determine the "freshness" of the Access Token or if we are within the specified `refresh_threshold` and should refresh the token.

The script will return an exit code of `1` if we are under the refresh threshold and need to refresh, or an exit code of `0` if we are still outide of that time window and don't need to refresh.

By default, this threshold is set for within 4 hours of the Access Token exipry and is defined as number of seconds (14400). 

GitHub Access Tokens typically expire in 8 hours (28800 seconds) and 4 hours seems like a reasonable time to refresh without excessive interactions, but still well before the expiry so operations are not interrupted.

### 5\. Token Refresh

The `5_refresh_token.py` script will perform a refresh using the current Refresh Token.

This will refesh both the access token and refresh tokens as well as the expiry time and update the corresponding files defined in the module parameters.

# Notes 
- GitHub **Access Tokens** expire every 8 hours (28800 seconds), and GitHub **Refresh Tokens** expire at 6 months. 
- Using a **Refresh Token** to refresh the **Access Token** does NOT extend the expiry time of the **Refresh token**.
- In order to extend the expiry for a **Refresh Token** the process needs to be initiated from Step 1 using the full authorization workflow (essentially starting a new session with an entirely new token set).
- Automation can be configured to update the **Access Token** using the **Refresh Token**. It is reasonable to do this every 4 hours. This requires the use of scripts from steps `4` & `5` only.
- As a resonable security practice, the complete workflow should be run from step `1` through `5` about every `3 months` in order to completely rotate to a new set of tokens and ensure operations are not interrupted.
- If anything goes wrong, or in the event of a security incident, you can `revoke all tokens` in the specific GitHub App and start the process again from step `1`. 
- For added security, you could also rotate the `Client Secret` on the same `3 month` cycle, but this isn't strictly required. All steps will need to be performed after a `Client Secret` is rotated or if current Access/Refresh Tokens are revoked.

# Troubleshooting

Once configured, use `puppet code deploy --dry-run --log-level debug` on your Puppet Enterprise Primary server to see the results of the configuration for code deployment.

- Beware of the error below when running `puppet code deploy --dry-run`, this means you need a new `PE API Access Token`, not a new GitHub access token. Get a new one with `puppet access login` command.
```
{"kind":"puppetlabs.rbac/token-revoked","msg":"Authentication token has been revoked."}
2025/04/29 13:49:01 DEBUG - [POST /deploys][401] Deploy default  &{Details:<nil> Kind:puppetlabs.rbac/token-revoked Msg:Authentication token has been revoked.}
2025/04/29 13:49:01 ERROR - [POST /deploys][401] Authentication token has been revoked.
```
