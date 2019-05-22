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

project_prefix="${TF_VAR_project_prefix:?}"
management_suffix="${MANAGEMENT_SUFFIX:-management}"

helper_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}" )" )"
helm_path="$(realpath "${helper_dir}/../helm/")"
domain_name="${DOMAIN_NAME:-}"

echo ''
echo '+--------------------------+'
echo '| Installing Microservices |'
echo '+--------------------------+'
echo ''
echo "==================================================="
echo "Helm Path: ${helm_path:?}"
echo "Management Project: ${project_prefix:?}-${management_suffix}"
echo "Deidentification Template: ${DEIDENTIFY_TEMPLATE_NAME:?}"
echo "Fluentd Image Repo: ${FLUENTD_IMAGE_REMOTE_REPO:?}"
echo "Domain Name: ${domain_name}"
echo "==================================================="
echo ""
echo "Continuing in 10 seconds. Ctrl+C to cancel"
sleep 10

echo ''
echo '+---------------------+'
echo '| Out Of Scope Charts |'
echo '+---------------------+'
echo ''
echo '(this may take a few minutes)'
echo ''
echo 'Installing fluentd Daemonset...'
echo ''
helm install --wait \
    --kube-context out-of-scope \
    --name fluentd-custom-target-project \
    --namespace kube-system \
    --set project_id="${project_prefix}-${management_suffix}" \
    "${helm_path}/fluentd-custom-target-project"

echo 'Installing Microservices...'
echo ''

helm install --wait \
    --kube-context out-of-scope \
    --name out-of-scope-microservices \
    "${helm_path}/out-of-scope-microservices"

echo ''
echo '+-----------------+'
echo '| In Scope Charts |'
echo '+-----------------+'
echo ''
echo '(this may take a few minutes)'
echo ''
echo 'Installing Fluentd Daemonset...'
echo ''

helm install --wait \
    --kube-context in-scope \
    --name fluentd-filter-dlp \
    --namespace kube-system \
    --set project_id="${project-prefix}-${management_suffix}" \
    --set deidentify_template_name="${DEIDENTIFY_TEMPLATE_NAME:?}" \
    --set fluentd_image_remote_repo="${FLUENTD_IMAGE_REMOTE_REPO:?}" \
    "${helm_path}/fluentd-filter-dlp"

echo 'Installing Microservices...'
echo ''

# Setting `DOMAIN_NAME` environment variable will create a Managed Certificate
# resource. Don't set this variable if you can't manage your domain's DNS
# record.  You will need to point the DNS record to your Ingress' external IP.
if [[ "${domain_name}" != "" ]]
then
    helm install --wait \
        --kube-context in-scope \
        --name in-scope-microservices \
        --set nginx_listener_1_ip="$(kubectl --context out-of-scope get svc nginx-listener-1 -o jsonpath="{.status.loadBalancer.ingress[*].ip}")" \
        --set nginx_listener_2_ip="$(kubectl --context out-of-scope get svc nginx-listener-2 -o jsonpath="{.status.loadBalancer.ingress[*].ip}")" \
        --set domain_name="${domain_name}" \
        "${helm_path}/in-scope-microservices"
else
    helm install --wait \
        --kube-context in-scope \
        --name in-scope-microservices \
        --set nginx_listener_1_ip="$(kubectl --context out-of-scope get svc nginx-listener-1 -o jsonpath="{.status.loadBalancer.ingress[*].ip}")" \
        --set nginx_listener_2_ip="$(kubectl --context out-of-scope get svc nginx-listener-2 -o jsonpath="{.status.loadBalancer.ingress[*].ip}")" \
        "${helm_path}/in-scope-microservices"
fi

echo ''
echo 'All microservices are installed on your Kubernetes clusters'
echo -n 'Waiting for Loadbalancer to finish setting up...'

until [[ "$(kubectl --context in-scope get ingress frontend-external-tls -o jsonpath="{.status.loadBalancer.ingress[*].ip}")" != "" ]]
do
    sleep 1
    echo -n '.'
done
echo '.'
echo -n 'IP Address is attached. Waiting for service to become healthy...'

ip="$(kubectl --context in-scope get ingress frontend-external-tls -o jsonpath="{.status.loadBalancer.ingress[*].ip}")"
until [[ "$(curl -s -k -o /dev/null -w '%{http_code}' "https://${ip}/")" == "200" ]]
do
    sleep 5
    echo -n '.'
done

echo ''
echo '+---------+'
echo '| Success |'
echo '+---------+'
echo "You can now visit https://${ip}/"
echo ''
