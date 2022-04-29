#!/usr/bin/env python3

import os
import sys
import shutil
import subprocess
import json
import boto3
import configparser
from pathlib import Path

class Colors(object):
    normal = "\033[39m"
    white = "\033[97m"
    red = "\033[31m"
    yellow = "\033[33m"

def getJSON():
    try:
        p = Path(__file__).with_name('awslogin.json')
        with p.open("r") as accountlist:
            data = json.load(accountlist)
        return data
    except:
        return {}

def main(ACCOUNTS, SSO_LOGIN_URL, SSO_LOGIN_REGION):

    home = str(Path.home())
    dotaws = os.path.join(home, ".aws")
    configPath = os.path.join(home, ".aws", "config")
    credentialsPath = os.path.join(home, ".aws", "credentials")

    # DELETE OLD CREDENTIALS
    if os.path.exists(dotaws):
        shutil.rmtree(dotaws)
    os.mkdir(dotaws)

    # NEW CONFIGS
    config = configparser.ConfigParser()
    config.read(configPath)
    for acc in ACCOUNTS:
        id = acc["id"]
        role = acc["role"]
        region = acc["region"]
        profile = acc["profile"]
        configprofile = acc["configprofile"]

        config[configprofile] = {}
        config[configprofile]["sso_start_url"] = SSO_LOGIN_URL
        config[configprofile]["sso_region"] = SSO_LOGIN_REGION
        config[configprofile]["sso_account_id"] = id
        config[configprofile]["sso_role_name"] = role
        config[configprofile]["region"] = region

    # Write ~/.aws/config file
    with open(configPath, 'w') as configfile:
        config.write(configfile)

    # ACTUAL SSO LOGIN
    subprocess.run(["aws", "sso", "login"])

    # CREATE NEW CREDENTIALS FILE (needed by some legacy applications)
    creds = configparser.ConfigParser()
    creds.read(credentialsPath)
    for acc in ACCOUNTS:
        id = acc["id"]
        role = acc["role"]
        region = acc["region"]
        profile = acc["profile"]
        configprofile = acc["configprofile"]

        # Open Named Profile Session with Boto3 to retrieve credentials 
        session = boto3.Session(profile_name=profile)
        credentials = session.get_credentials().get_frozen_credentials()
        aws_access_key_id = credentials.access_key
        aws_secret_access_key = credentials.secret_key
        aws_session_token = credentials.token
       
        creds[profile] = {}
        creds[profile]["aws_access_key_id"] = aws_access_key_id
        creds[profile]["aws_secret_access_key"] = aws_secret_access_key
        creds[profile]["aws_session_token"] = aws_session_token

        print(
            "Now logged into {}{}{}@{}{}{}".format(
                Colors.red,
                role,
                Colors.white,
                Colors.yellow,
                profile,
                Colors.normal
            )
        )

    # Write ~/.aws/credentials file
    with open(credentialsPath, 'w') as credentialsfile:
        creds.write(credentialsfile)

if __name__ == '__main__':

    setDefault = ""
    if len(sys.argv) == 2:
        setDefault = str(sys.argv[1]).strip()

    data = getJSON()
    try:
        SSO_LOGIN_URL = data["SSO_LOGIN_URL"]
        SSO_LOGIN_REGION = data["SSO_LOGIN_REGION"]
        ACCOUNTS = data["ACCOUNTS"]
        if len(ACCOUNTS) == 0:
            print("awslogin.json must contain at least 1 account")
            exit(0)
    except:
        print("awslogin.json error")
        exit(0)
    # Set Default Account - The First Account is used if no Command Line Argument
    defaultAccount = ACCOUNTS[0].copy()

    for count, acc in enumerate(ACCOUNTS):
        id = acc["id"]
        role = acc["role"]
        region = acc["region"]
        profile = acc["profile"]
        ACCOUNTS[count]["configprofile"] = "profile " + profile
        if profile == setDefault:
            defaultAccount = ACCOUNTS[count].copy()

    defaultAccount["configprofile"] = "default"
    defaultAccount["profile"] = "default"
    ACCOUNTS.insert(0,defaultAccount)

    main(ACCOUNTS, SSO_LOGIN_URL, SSO_LOGIN_REGION)
