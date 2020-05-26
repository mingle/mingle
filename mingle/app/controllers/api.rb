#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

module API
  SUPPORTED_VERSIONS = %w(v2)

  def self.detect_version(params, project, controller)
    version_class = choose_version_from_params(params)
    api_delegate = resolve_delegate_class(controller, version_class).new(project, params)

    controller.instance_variable_set('@api_delegate', api_delegate)
    controller.instance_variable_set('@api_version', version_class.new)
  end

  def self.resolve_delegate_class(controller, version_class)
    version_class.const_get("#{controller.class.name}APIDelegate")
  end

  def self.choose_version_from_params(params)
    version = params[:api_version]
    if version
      raise "Mingle only supports API #{SUPPORTED_VERSIONS.join(", ")}. Requested: #{version}" unless SUPPORTED_VERSIONS.include?(version)
    end

    # right now, we only have one choice
    VersionTwo
  end

end
