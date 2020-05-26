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
require 'brakeman'

namespace :brakeman do
  task :verify_no_high_risk_warnings do
    report = Brakeman.run app_path: '.', config_file: 'config/brakeman.yml'
    raise 'Security warnings found with high confidence' if report.warnings.any? { |warning| warning.confidence >= 2}
  end
end