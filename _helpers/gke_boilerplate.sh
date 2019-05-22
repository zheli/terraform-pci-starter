#!/bin/bash
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Fail fast when a command fails or a variable is undefined
set -eu

#
# Default usage:
# `./_helpers/gke_boilerplate.sh`
#
# Use non-default in-scope/out-of-scope project names:
# `OUT_OF_SCOPE_SUFFIX=foo IN_SCOPE_SUFFIX=baz ./_helpers/gke_boilerplate.sh`
#
out_of_scope_suffix="${OUT_OF_SCOPE_SUFFIX:-out-of-scope}"
in_scope_suffix="${IN_SCOPE_SUFFIX:-in-scope}"
helper_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}" )" )"

echo ''
echo '+---------------------------------------------------------------+'
echo '| Fetching Cluster credentials and setting contexts for kubectl |'
echo '+---------------------------------------------------------------+'
echo ''
gcloud container clusters get-credentials out-of-scope --zone us-central1-a --project "${TF_VAR_project_prefix:?}-${out_of_scope_suffix}"
if ! kubectl config rename-context "$(kubectl config current-context)" out-of-scope
then
    echo 'Error occurred while setting context. Check if there is already a context'
    echo 'named "out-of-scope" and delete it with "kubectl config delete-context'
    echo 'out-of-scope" before trying again'
fi
gcloud container clusters get-credentials in-scope --zone us-central1-a --project "${TF_VAR_project_prefix:?}-${in_scope_suffix}"
if ! kubectl config rename-context "$(kubectl config current-context)" in-scope
then
    echo 'Error occurred while setting context. Check if there is already a context'
    echo 'named "in-scope" and delete it with "kubectl config delete-context'
    echo 'in-scope" before trying again'
fi

echo ''
echo '+-------------------------------------------------------+'
echo '| Installing tiller service account on in-scope cluster |'
echo '+-------------------------------------------------------+'
echo ''
kubectl --context in-scope -n kube-system create sa tiller
kubectl --context in-scope \
    -n kube-system \
    create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
helm --kube-context in-scope  init --history-max 200 --service-account tiller

echo ''
echo '+-----------------------------------------------------------+'
echo '| Installing tiller service account on out-of-scope cluster |'
echo '+-----------------------------------------------------------+'
echo ''
kubectl --context out-of-scope -n kube-system create sa tiller
kubectl --context out-of-scope \
    -n kube-system \
    create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
helm --kube-context out-of-scope  init --history-max 200 --service-account tiller

echo ''
echo '+---------------------------------------------------------+'
echo '| Generating a TLS Secret for Encrypting Internal Traffic |'
echo '+---------------------------------------------------------+'

# Execute in subshell so we don't mess up directory stack
if ! (
cd "${helper_dir}" || exit
openssl genrsa -out hipsterservice.key 2048
openssl req -new -key hipsterservice.key -out hipsterservice.csr \
        -subj "/CN=internal.hipsterstore.net"
openssl x509 -req -days 365 -in hipsterservice.csr -signkey hipsterservice.key \
        -out hipsterservice.crt

if ! kubectl --context out-of-scope create secret tls tls-hipsterservice \
      --cert hipsterservice.crt --key hipsterservice.key || \
   ! kubectl --context in-scope create secret tls tls-hipsterservice \
   --cert hipsterservice.crt --key hipsterservice.key
then
    exit 1
fi
rm "hipsterservice.crt"
rm "hipsterservice.key"
rm "hipsterservice.csr"

)
then
    echo 'Error setting up TLS secret. Check the _helpers directory to see if the Certificate was generated correctly'
    exit 1
fi

echo ''
echo '+---------+'
echo '| Success |'
echo '+---------+'
echo ''
echo 'kubectl contexts and tiller installed successfully. To continue run "_helpers/install_microservices.sh"'
echo ''
