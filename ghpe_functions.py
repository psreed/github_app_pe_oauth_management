"""
A collection of functions used for GitHub App workflow with Puppet Enterprise

GitHub Token information for Personal and Machine Users found here: 
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

Information on GitHub App Token workflow:
https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app

Information on refreshing User Access tokens that expire: 
https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/refreshing-user-access-tokens

"""

import requests
import random
import string
import array
import os
import pwd
import grp
from lxml import html
from urllib.parse import urlencode
import json
import time

# Globals

# Constants

# 
def load_config(config_file='config.json'):
    """
    Function to load configuration from a JSON format file. Default is 'config.json'
    """
    try:
        with open(config_file, 'r') as cf:
            data = json.load(cf)
            if isinstance(data, dict):
                return data
            else:
                print("JSON file does not contain a list at the top level.")
                return None
    except FileNotFoundError:
        print(f"Error: File not found at '{file_path}'.")
        return None
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in '{file_path}'.")
        return None

def get_random_string(character_count=20):
    """
    Returns a random string of uppercase, lowercase and digit characters.
    Input "character_count" determines number of characters returned, defaults to 20

    Based on information originally found in this thread:
    https://stackoverflow.com/questions/2257441/random-string-generation-with-upper-case-letters-and-digits
    """
    return ''.join(random.choices(string.ascii_lowercase + string.ascii_uppercase + string.digits, k=character_count))

def generate_code_url(config):
    """
    Returns a URL string generated from the supplied config values for starting an authentication workflow with a GitHub App
    """
    params  = {
        'client_id'   : config['github_client_id'],
        'redirect_uri': config['callback_uri'],
        'scope'       : config['scope'],
        'state'       : get_random_string()
    }
    return config['github_oauth_login_url'] + "?" + urlencode(params) 

def post_data_to_url(url,data_dict):
    try:
        response = session.post(url, data=data_dict)
        if response.status_code == 200:
            print("POST request successful!")
            return response.text
        else:
            print(f"POST request failed with status code: {response.status_code}")
            print("Response:", response.text)
            exit()
    except requests.exceptions.RequestException as e:
        print(f"An error occurred while attempting a POST request: {e}")        
        exit()

def get_github_authorization(code, config):
    data = {
        "client_id"    : config['github_client_id'],
        "client_secret": config['github_client_secret'],
        "code"         : code,
        "redirect_uri" : config['callback_uri']
    }
    headers = {'Accept': 'application/json'}
    response = requests.post(config['github_token_url'], data=data, headers=headers)
    response.raise_for_status()
    return response.json()

def load_token(config):
    try:
        with open(config['token_file'],'r') as tf:
            token = tf.read()
        return token.strip()
    except FileNotFoundError:
        print("Error: File not found.")
    except IOError:
        print("Error: An I/O error occurred.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

def load_refresh_token(config):
    try:
        with open(config['refresh_token_file'],'r') as tf:
            refresh_token = tf.read()
        return refresh_token.strip()
    except FileNotFoundError:
        print("Error: File not found.")
    except IOError:
        print("Error: An I/O error occurred.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

def check_token_status(token, config):
    """
    Checks the status of a GitHub token
    Based on information found here: https://docs.github.com/en/rest/apps/oauth-applications?apiVersion=2022-11-28#check-a-token
    """

    data = { 
        "access_token": token
    }
    headers = {
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    
    url = 'https://api.github.com/applications/' + config['github_client_id'] + '/token'

    try:
        response = requests.post(url, 
            json=data, 
            headers=headers, 
            auth=requests.auth.HTTPBasicAuth(config['github_client_id'], config['github_client_secret'])
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        if response.status_code == 404:
            print("Resource is not found. The token has expired or doesn't exist. [code 404]")
            exit()
        if response.status_code == 422:
            print("Validation failed, or the endpoint has been spammed. [code 442]")
            exit()
        print(f"An error occurred while attempting a POST request: {e}")
        exit()        
    except:
        print("Some unknown error has occured during the attempt to check the status of the token with the GitHub API.")
        exit()

def write_token_to_file(token, file, owner='pe-puppet', group='pe-puppet', permissions=0o600):
    """
    Write a token to a file and set owner, group and file permissions
    """
    with open(file, 'w') as f:
        f.write(token)        
    uid = pwd.getpwnam(owner).pw_uid
    gid = grp.getgrnam(group).gr_gid
    os.chown(file, uid, gid)
    os.chmod(file, permissions)

def refresh_token(refresh_token, config):
    try:
        data = { 
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }
        headers = {
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        url = config['github_token_url']
        response = requests.post(url, 
            json=data, 
            headers=headers, 
            auth=requests.auth.HTTPBasicAuth(config['github_client_id'], config['github_client_secret'])
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        if response.status_code == 404:
            print("Resource is not found. The token has expired or doesn't exist. [code 404]")
            exit()
        if response.status_code == 422:
            print("Validation failed, or the endpoint has been spammed. [code 442]")
            exit()
        print(f"An error occurred while attempting a POST request: {e}")
        exit()        
    except:
        print("An unknown error occurred and we could not refresh the token.")
        exit()

def check_sudo_needed():
    return os.geteuid() != 0

