#!/usr/bin/python

#***************************************************************************
# Copyright 2015 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#***************************************************************************

import json
import os
import os.path
import sys
import time
import timeit
import requests
from datetime import datetime
from subprocess import call, Popen, PIPE

# export PPE_POKE=1
# export PPE_TARGET_ID=<specific id to force>
#./parse_pipeline_extensions.sh $HOST_TO_CHECK "$TARGET_EXTENSION"


DEBUG=os.environ.get('DEBUG')
PPE_POKE=os.environ.get('PPE_POKE')
PPE_TARGET_ID=os.environ.get('PPE_TARGET_ID')
CREATE_IF_NOT_FOUND=os.environ.get('CREATE_IF_NOT_FOUND')

SCRIPT_START_TIME = timeit.default_timer()

# print a quick usage/help statement
def print_help ():
    print "usage: parse_pipeline_extensions.py targetip extensionURL"
    print
    print "\toptions (as env vars):"
    print "\t PPE_POKE            : if 1, submits PUT against the URL, else just gets info"
    print "\t PPE_TARGET_ID       : if set, and this ID matches the URL, will just poke this one"
    print "\t CREATE_IF_NOT_FOUND : if 1, submits POST against the URL to create new extension if needed"
    print

# begin main execution sequence

try:
    exit_code = 0
    argc=0
    for arg in sys.argv:
        print "arg " + str(argc) + " is " + str(arg)
        if (argc == 1):
            target_ip = arg
        elif (argc == 2):
            target_ext = arg
        argc += 1

    # get the full list of extensions on this environment
    url = "https://" + str(target_ip) + ":9443/pipeline/extensions?all=true"
    response = requests.get(url, verify=False)
    print "get responded " + str(response.status_code)

    full_list = response.json()

    target_id = None
    target_enabled = False
    target_id_list = []
    target_count = 0
    for ext in full_list:
        if ext["url"] == target_ext:
            print "Found extension for url " + str(target_ext)
            if PPE_TARGET_ID:
                if ext["_id"] == PPE_TARGET_ID:
                    print "Found exact id requested"
                    print "\tid is " + ext["_id"]
                    target_id = ext["_id"]
                    target_enabled = ext["enabled"]
                    target_id_list.append(target_id)
                    target_count += 1
                else:
                    print "Extension ID doesn't match, skipping"
            else:
                print "\tid is " + ext["_id"]
                target_id = ext["_id"]
                target_enabled = ext["enabled"]
                target_id_list.append(target_id)
                target_count += 1

    if target_id != None:
        if target_count > 1:
            print "warning - multiple extensions found for that id:"
            print "\t" + str(target_id_list)
            print "set env var PPE_TARGET_ID to the one to be updated"
        else:
            print "Poking " + str(target_ext) + " on " + str(target_ip)
            url = "https://%s:9443/pipeline/extensions/%s" % (target_ip, target_id)
            payload = '{"url":"%s"}' % target_ext
            headers = { "Content-Type": "application/json" }
            if PPE_POKE == "1":
                response = requests.put(url, data=payload, headers=headers, verify=False)
                print "put responded " + str(response.status_code)
                if response.status_code != 200: 
                    print "poke failed"
                    print response.text
                    exit_code = 1
                else:
                    # if it was enabled, re-enable it
                    if target_enabled:
                        print "Re-enabling %s" % target_ext
                        url = "https://%s:9443/pipeline/extensions/%s/enable" % (target_ip, target_id)
                        response = requests.post(url, verify=False)
                        print "re-enable post responded " + str(response.status_code)
            else:
                print "poke not set, would have sent:"
                print str(payload)
                print "with headers " + str(headers)
                print "to url " + str(url)
    elif CREATE_IF_NOT_FOUND == "1":
        print "Creating " + str(target_ext) + " on " + str(target_ip)
        url = "https://%s:9443/pipeline/extensions" % (target_ip)
        payload = '{"url":"%s"}' % target_ext
        headers = { "Content-Type": "application/json" }
        response = requests.post(url, data=payload, headers=headers, verify=False)
        print "post responded " + str(response.status_code)

    endtime = timeit.default_timer()
    print "Script completed in " + str(endtime - SCRIPT_START_TIME) + " seconds"

    sys.exit(exit_code)

except Exception, e:
    print "Exception received: " + str(e)
    endtime = timeit.default_timer()
    print "Script completed in " + str(endtime - SCRIPT_START_TIME) + " seconds"
    sys.exit(1)
