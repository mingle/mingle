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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class TransitionPropertyEditorHelperTest < ActiveSupport::TestCase
  include ApplicationHelper, TransitionPropertyEditorHelper, PropertyEditorHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_transition_popup_property_value_for_required_should_display_select_as_not_set
    status = @project.find_property_definition('status')
    transition = create_transition(@project, 'whoa jeez', :set_properties => { 'status' => Transition::USER_INPUT_REQUIRED })
    card = create_card!(:name => "card 1")
    options = transition_popup_property_editor(status, transition, card, nil, [status])
    assert_equal '(Select...)', options[:locals][:options][:display_value]
  end
end
