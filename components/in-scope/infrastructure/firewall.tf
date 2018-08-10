/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
resource "google_compute_firewall" "allow_1443" {
  name    = "allow-1443"
  project = "${data.terraform_remote_state.project_network.project_id}"
  network = "${data.terraform_remote_state.project_network.network_name}"

  source_ranges = ["10.11.0.0/16"]
  target_tags   = ["in-scope"]

  allow {
    protocol = "tcp"
    ports    = ["1443"]
  }
}

resource "google_compute_firewall" "allow_10256_from_LB" {
  name    = "allow-10256"
  project = "${data.terraform_remote_state.project_network.project_id}"
  network = "${data.terraform_remote_state.project_network.network_name}"

  # Required for health checks from the load balancer
  # See https://cloud.google.com/load-balancing/docs/https/#firewall_rules
  source_ranges = ["130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]

  target_tags = ["in-scope"]

  allow {
    protocol = "tcp"
    ports    = ["10256"]
  }
}
