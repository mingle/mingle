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

class DeletedCardTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def test_find_deleted_card
    card = create_card!(:name => 'first card', :description => 'hello')
    card.update_attribute(:cp_iteration, 2)
    card.destroy

    assert_nil @project.cards.find_by_id(card.id)
    deleted_card = DeletedCard.new_from_last_version(card.id)
    assert_not_nil deleted_card
    assert_equal card.id, deleted_card.id
    assert_equal card.number, deleted_card.number
    assert_equal card.name, deleted_card.name
    assert_equal @project.find_card_type('Card'), deleted_card.card_type
    assert_nil deleted_card.description
    assert_nil deleted_card.cp_iteration
  end

  def test_find_deleted_card_with_deleted_card_type
    card_type = @project.card_types.create!(:name => 'Task')
    card = create_card!(:name => 'first card', :description => 'hello', :type => 'Task')
    assert_equal 'Task', card.card_type.name
    card.destroy
    card_type.destroy

    deleted_card = DeletedCard.new_from_last_version(card.id)
    assert_equal 'Task', deleted_card.card_type.name
  end

  def test_deleted_card_can_not_be_saved!
    card = create_card!(:name => 'first card', :description => 'hello')
    card.destroy

    deleted_card = DeletedCard.new_from_last_version(card.id)
    assert_raise(RuntimeError) { deleted_card.save }
  end

  def test_compact_xml_format
    card = create_card!(:name => 'first card', :description => 'hello')
    card.destroy

    deleted_card = DeletedCard.new_from_last_version(card.id)
    view_helper.default_url_options = { :host => 'example.com' }
    compact_xml = deleted_card.to_xml(:skip_instruct => true, :compact => true, :version => 'v2', :view_helper => view_helper)
    assert_equal_ignoring_spaces <<-XML, compact_xml
<card url="http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml">
  <number type="integer">#{card.number}</number>
</card>
XML

  end

  def test_card_snapshot
    card = create_card!(:name => 'first card', :description => 'hello')
    card.destroy
    card_versions = Card::Version.find(:all, :conditions => {:card_id => card.id})
    assert_equal 2, card_versions.size
    assert_equal({:Number => card.number}, card_versions[0].card_snapshot)
    assert_equal({:Number => card.number}, card_versions[1].card_snapshot)
  end

end
