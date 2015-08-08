#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Check if a pull request id was specified
prId=$1
if [ -z ${prId} ]; then
  echo "No PR number specified. Quiting."
  exit 1
fi

# Vars we need
jsonTmp="${PWD}/${prId}.json"
tmpMessageFile="${PWD}/.git-tmp-message.txt"

# Stop executing when we encounter errors
set -e

# We need UTF-8 to support the GitHub '...' 3-dots-in-1-char, for example.
export LANG="en_EN.UTF-8"

# Get json data from Github API
curl -s https://api.github.com/repos/apache/cloudstack/pulls/${prId} > ${jsonTmp}

# Get vars from the GitHub API and parse the returned json
prAuthor=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["user"]["login"].encode("utf-8").decode("ascii","ignore")')
prTitle=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["title"].encode("utf-8").decode("ascii","ignore")')
prBody=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["body"].encode("utf-8").decode("ascii","ignore")')
prOriginBranch=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["head"]["ref"].encode("utf-8").decode("ascii","ignore")')
prState=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["state"]')
prMergeableState=$(cat ${jsonTmp} | python -c 'import sys, json; print json.load(sys.stdin)["mergeable_state"]')

# Do some sanity checking
if [ "${prState}" != "open" ]; then
  echo "ERROR: We couldn't merge the PR because the state is not 'open' but '${prState}'."
  exit
fi
if [ "${prMergeableState}" != "clean" ]; then
  echo "ERROR: We couldn't merge the PR because it cannot be merged 'clean' ('${prMergeableState}')."
  exit
fi
if [ ${#prAuthor} -eq 0 ]; then
  echo "ERROR: We couldn't grab the PR author. Something went wrong querying the GitHub API."
  exit
fi
if [ ${#prTitle} -eq 0 ]; then
  echo "ERROR: We couldn't grab the PR title. Something went wrong querying the GitHub API."
  exit
fi
if [ ${#prOriginBranch} -eq 0 ]; then
  echo "ERROR: We couldn't grab the PR branch name. Something went wrong querying the GitHub API."
  exit
fi

# Construct commit merge message
echo "Merge pull request #${prId} from ${prAuthor}/${prOriginBranch}" > ${tmpMessageFile}
echo "" >> ${tmpMessageFile}
echo "${prTitle}${prBody}" >> ${tmpMessageFile}

# Do the actual merge
git fetch origin pull/${prId}/head:pr/${prId}
git merge --no-ff --log -m "$(cat .git-tmp-message.txt)" pr/${prId}
git commit --amend -s --allow-empty-message -m ''

# Clean up
git branch -D pr/${prId}
rm ${jsonTmp} ${tmpMessageFile}
