#!/usr/bin/python3
"""
Step 1 in the GitHub App Puppet Enterprise Token Authentication workflow

Generate a GitHub App Authentication URL and then get a `code` to be exchanged later for an OAuth Token

"""
from ghpe_functions import *

config=load_config()

print('Get the GitHup App `code` from the following URL.')
print('Note: You may want to use a private/incognito browser session to ensure you are using the correct machine account.')
print(generate_code_url(config))
