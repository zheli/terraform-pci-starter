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

echo ''
echo 'Deleting installed Helm charts from this project...'


helm delete \
    --kube-context out-of-scope \
    --purge fluentd-custom-target-project || true

helm delete \
    --kube-context out-of-scope \
    --purge out-of-scope-microservices || true

helm delete \
    --kube-context in-scope \
    --purge fluentd-filter-dlp || true

helm delete \
    --kube-context in-scope \
    --purge in-scope-microservices || true

