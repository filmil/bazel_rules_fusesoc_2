# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
load("@rules_pkg//pkg:providers.bzl", "PackageVariablesInfo")


def _name_part_from_command_line_naming_impl(ctx):
    values = {"name_part": ctx.build_setting_value}
    return PackageVariablesInfo(values = values)


name_part_from_command_line = rule(
    implementation = _name_part_from_command_line_naming_impl,
    build_setting = config.string(flag = True),
)
