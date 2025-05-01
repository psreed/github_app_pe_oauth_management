#!/usr/bin/python3
"""
Step 5 in the GitHub App Puppet Enterprise Token Authentication workflow

Refresh token before token has expired.

"""
from ghpe_functions import *
import json
import time
import math

if check_sudo_needed():
    print("Please use sudo to run this script.")
    exit()

config = load_config()

current_refresh_token = load_refresh_token(config)
json_data = refresh_token(current_refresh_token, config)

new_token = json_data.get('access_token')
new_refresh_token = json_data.get('refresh_token')
new_expiry = int(json_data.get('expires_in')) + math.trunc(time.time())

#print(json.dumps(json_data, indent=4))

print(f'New Access Token: {new_token}')
print(f'New Expiry: {new_expiry}')
print(f'New Refresh Token: {new_refresh_token}')

print(f"Saving new token to file: {config['token_file']}")
write_token_to_file(new_token, config['token_file'])

print(f"Saving new expiry to file: {config['token_expiry_file']}")
write_token_to_file(str(new_expiry), config['token_expiry_file'])

print(f"Saving new refresh token to file: {config['refresh_token_file']}")
write_token_to_file(new_refresh_token, config['refresh_token_file'])
