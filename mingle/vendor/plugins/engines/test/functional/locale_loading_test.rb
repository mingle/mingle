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

# Tests in this file ensure that:
#
# * translations in the application take precedence over those in plugins
# * translations in subsequently loaded plugins take precendence over those in previously loaded plugins

require File.dirname(__FILE__) + '/../test_helper'

class LocaleLoadingTest < ActionController::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # app takes precedence over plugins
	
  def test_WITH_a_translation_defined_in_both_app_and_plugin_IT_should_find_the_one_in_app
    assert_equal I18n.t('hello'), 'Hello world'
  end
	
  # subsequently loaded plugins take precendence over previously loaded plugins
	
  def test_WITH_a_translation_defined_in_two_plugins_IT_should_find_the_latter_of_both
    assert_equal I18n.t('plugin'), 'beta'
  end
end
	
