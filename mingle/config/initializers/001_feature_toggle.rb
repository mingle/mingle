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

require 'feature_toggle'

ENV['deactivate.features'] ||= java.lang.System.getProperty('deactivate.features')

FEATURES = FeatureToggle.load(File.join(Rails.root, 'config', 'features.yml'))
deactivated_features = ENV['deactivate.features'].to_s.split(',').map(&:strip)
FEATURES.deactivate(*deactivated_features)
Kernel.logger.info("deactivated features: #{deactivated_features.inspect}")


# to support use by ClassMethodServlet during tests
class MingleFeatureToggler

  def self.activate_feature(options)
    feature = options.with_indifferent_access['feature']
    FEATURES.activate(feature)
  end

  def self.deactivate_feature(options)
    feature = options.with_indifferent_access['feature']
    FEATURES.deactivate(feature)
  end

end
