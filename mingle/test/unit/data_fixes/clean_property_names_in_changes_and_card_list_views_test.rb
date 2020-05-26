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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CleanPropertyNamesInChangesAndCardListViewsTest < ActiveSupport::TestCase
  include MigrationHelper

  def setup
    login_as_admin
  end

  def test_applying_fix_will_repair_changes_and_card_list_views
    with_new_project do |project|
      property = setup_managed_text_definition("old name", ["a", "b"])
      setup_managed_text_definition("status", ["open", "closed"])

      # create some bad data
      card, change = create_change_with_bad_field(project, property.name, "b")
      view_id = create_card_list_view_with_bad_property_name(project, ["old name", "status"])

      assert_equal "old name   ", change.field
      view = CardListView.find(view_id) # reload() doesn't do what you think it does...
      assert !view.uses?(property)
      assert view.columns.include?("old name ")
      assert view.canonical_string.include?("old name ,")

      # because the "field" attribute has whitespace, renaming the property will no longer update
      # the "field" attribute of the change. addtionally, favorites aren't updated either for a
      # similar reason
      property.name = "new name"
      assert_equal "old name   ", change.reload.field
      view = CardListView.find(view_id)
      assert !view.uses?(property)
      assert view.columns.include?("old name ")
      assert view.canonical_string.include?("old name ,")
      assert !view.columns.include?("new name")
      assert !view.canonical_string.include?("new name")

      # rename property to restore history
      property.name = "old name"

      DataFixes::CleanPropertyNamesInChangesAndCardListViews.apply
      project.reload
      change.reload
      view = CardListView.find(view_id)

      assert_equal "old name", change.field
      assert view.uses?(property)

      # now that the field is fixed, a property rename will update the change as well
      property.name = "new name"
      assert_equal "new name", change.reload.field

      # the favorite's columns are also now updated
      view = CardListView.find(view_id)
      assert view.uses?(property)
      assert view.columns.include?("new name")
      assert view.canonical_string.include?("new name,")
      assert !view.columns.include?("old name")
      assert !view.columns.include?("old name ")
      assert !view.canonical_string.include?("old name")
    end
  end

  private

  def create_change_with_bad_field(project, property_name, value)
    card = project.cards.create!(:name => "a card", :card_type_name => "Card")
    card.update_properties({property_name => value})
    card.save!
    event = card.reload.versions.last.event
    Event.lock_and_generate_changes!(event.id)
    change = event.changes.first
    change.update_attribute(:field, "#{change.field}   ")
    [card, change]
  end

  def create_card_list_view_with_bad_property_name(project, columns=[])
    bad_view = CardListView.construct_from_params(project, :filters => ["[Type][is][Card]"], :tagged_with => "type-story", :columns => columns.join(","), :sort => "status", :order => "desc")
    # bad_view.columns.each {|c| c.insert(-1, " ")}
    bad_view.update_attributes(:name => "bad view")
    bad_view.tab_view = true
    bad_view.save!

    yml = YAML.load(bad_view.params)
    yml[:columns].gsub!("old name", "old name ")
    canonical_string = bad_view.canonical_string.gsub("old name", "old name ")

    bad_view.update_attributes(:params => yml, :canonical_string => canonical_string)
    project.connection.execute SqlHelper.sanitize_sql(<<-SQL, canonical_string, yml.to_yaml, bad_view.id)
      update card_list_views
         set canonical_string=?, params=?
       where id=?
    SQL
    project.reload
    bad_view.id
  end

end
