#
# Author:: Paul Mooring (paul@opscode.com)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'ruby-wmi'

Ohai.plugin do
  provides "uptime", "uptime_seconds"

  collect_data do
    uptime_seconds ::WMI::Win32_PerfFormattedData_PerfOS_System.find(:first).SystemUpTime.to_i
    uptime seconds_to_human(uptime_seconds)
  end
end
