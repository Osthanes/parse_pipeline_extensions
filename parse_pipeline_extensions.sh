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

#export PPE_POKE=1
#./parse_pipeline_extensions.sh $HOST_TO_CHECK "$TARGET_EXTENSION"


DEBUG=os.environ.get('DEBUG')
PPE_POKE=os.environ.get('PPE_POKE')

SCRIPT_START_TIME = timeit.default_timer()

# print a quick usage/help statement
def print_help ():
    print "usage: parse_pipeline_extensions.py targetip extensionURL"
    print
    print "\toptions (as env vars):"
    print "\t   PPE_POKE    : if 1, submits PUT against the URL, else just gets info"
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
    for ext in full_list:
        if ext["url"] == target_ext:
            print "Found extension for url " + str(target_ext)
            print "\tid is " + ext["_id"]
            target_id = ext["_id"]

    if target_id != None:
        print "Poking " + str(target_ext) + " on " + str(target_ip)
        url = "https://" + str(target_ip) + ":9443/pipeline/extensions/" + str(target_id)
        payload = '{"url":"'+str(target_ext)+'"}'
        headers = { "Content-Type": "application/json" }
        if PPE_POKE == "1":
            response = requests.put(url, data=payload, headers=headers, verify=False)
            print "put responded " + str(response.status_code)
            if response.status_code != 200: 
                print "poke failed"
                exit_code = 1
        else:
            print "poke not set, would have sent:"
            print str(payload)
            print "with headers " + str(headers)
            print "to url " + str(url)

    endtime = timeit.default_timer()
    print "Script completed in " + str(endtime - SCRIPT_START_TIME) + " seconds"

    sys.exit(exit_code)

except Exception, e:
    print "Exception received: " + str(e)
    endtime = timeit.default_timer()
    print "Script completed in " + str(endtime - SCRIPT_START_TIME) + " seconds"
    sys.exit(1)
