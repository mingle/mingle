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

class CardDefaultsChecklistItemTest < ActiveSupport::TestCase

  def test_default_checklist_item_is_incomplete_when_created
    with_new_project do |project|
      card_type = project.card_types.create!(:name => "another card type")
      card_type.create_card_defaults_if_missing
      card_defaults_checklist_item = card_type.card_defaults.checklist_items.create(:text => "Freaky Friday")
      assert_false card_defaults_checklist_item.completed
    end
  end
end
