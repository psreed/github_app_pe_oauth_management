# github_app_pe_oauth_management

A set of Bash and Python scripts to aid in the management of GitHub App authentication workflow for Puppet Enterprise.

Create a GitHub App for your organization, then use these scripts to manage the authentication and refresh workflow for OAuth tokens used for Puppet Enterprise Code Manager.


# Setup

1. Have your control repository available on GitHub and ensure it's part of your organization
2. Create a "GitHub App" for authentication and attach it to your organization. Ensure the App has permissions to the specific (or all organization) repos.
3. Create a `config.json` file based on the `example_config.json`. 

# Process

1. Use `1_get_github_app_code.py` to initiate the authentication workflow and provide a code for the next step. Note that using a callback url of `https://127.0.0.1` will show the `code` as part of the address in the address bar of your browser, even though it won't bring up an actual web page. This code can still be used for the next step.

2. Use `2_exchange_code_for_token.py` to get an actual OAuth token for use with Puppet Enterprise Code Manager. By default, the functions in this script will ensure that user/group is set to `pe-puppet`, which is required for Code Manager to be able to read the OAuth token from the file. As a result, if you are testing this on a system without Puppet Enterprise installed, you may need to change those defaults in your `ghpe_finctions.py` file for the `write_token_to_file` function.

3. Use `3_check_token.py` to show information about the current token. This is for information about the current token only, and is not a required part of the authentication or code deployment workflow.

4. Use `4_check_refresh_needed.py` to determine if we are within the `refresh_threshold` and should refresh the token. The script will return an exit code of `1` if we are within the refresh threshhold and `0` if we are still outide of that time. By default, this threshold is set for within 4hrs of token exipry and is defined in `config.json` in number of seconds [14400]. GitHub tokens typically expire in 8hrs [28800 seconds] and 4hrs [14400 seconds] seems like a reasonable refresh time.

5. Use `5_refresh_token.py` to perform the refresh using the current `refresh_token` saved in the file defined in `config.json`. This will refesh both the access token and refresh tokens as well as the expiry time and update the corresponding files defined in `config.json`.

Note: 
- Currently, GitHub access tokens expire every 8 hours, and refresh tokens expire after 6 months.
- Automation can be configured to automatically update the access token using the refresh token. It is reasonable to do this every 4 hours. This requires the use of scripts 4 & 5 only.
- As a resonable security practice, the complete workflow should be run from step 1 through 5 every 3 months to completely rotate to a new set of keys, well within the 6 month expiry window.
- If anything goes wrong, you can revoke all tokens used for the specific GitHub App and start again at step 1. 
- For added security, you could also rotate the Client Secret on the same 3 month cycle. All steps will need to be performed after a Client Secret is rotated.

