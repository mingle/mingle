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

class CardQueryWithCardTypeTest < ActiveSupport::TestCase
  
  def setup
    @project = create_project
    login_as_member
    
    setup_property_definitions :status => ['new', 'open', 'done'], :test_status => ['testing', 'has test']
    setup_numeric_property_definition 'size' , ["1", "2", "3"]

    @story_type = @project.card_types.create :name => 'story'
    @bug_type = @project.card_types.create :name => 'bug'

    @story_type.add_property_definition @project.find_property_definition(:size)
    @story_type.add_property_definition @project.find_property_definition(:status)
    @story_type.save!

    @bug_type.add_property_definition @project.find_property_definition(:size)
    @bug_type.add_property_definition @project.find_property_definition(:test_status)
    @bug_type.save!
  end

  def test_can_parse_card_type
    assert_equal "Type is story", CardQuery.parse("type = story").to_s
    assert_equal [], CardQuery.parse("select name where type = story").single_values
  end
  
  def test_find_cards_by_type
    story_card = create_card!(:name => 'story 1', :card_type => @story_type)
    assert_equal [story_card.name], CardQuery.parse("select name where type = story").single_values
    
    bug1 = create_card!(:name => 'bug 1', :card_type => @bug_type)
    bug2 = create_card!(:name => 'bug 2', :card_type => @bug_type)
    assert_equal [bug1.name, bug2.name].sort, CardQuery.parse("select name where type = bug").single_values.sort
    
    bug1.cp_test_status = 'testing'
    bug1.save!
    bug2.cp_test_status = 'has test'
    bug2.save!
    
    assert_equal '1', CardQuery.parse("select count(*) where type = bug AND test_status = testing").single_value
    
    assert_equal ['bug 1'], CardQuery.parse('SELECT Name WHERE type=bug AND test_status = testing ORDER BY Name').single_values
  end
  
  def test_find_cards_without_type_condition
    story_card = create_card!(:name => 'story 1', :card_type => @story_type, :size => '1')
    
    bug1 = create_card!(:name => 'bug 1', :card_type => @bug_type, :size => '2')
    bug2 = create_card!(:name => 'bug 2', :card_type => @bug_type, :size => '1')
    
    assert_equal ['bug 2', 'story 1'].sort, CardQuery.parse('SELECT Name WHERE size = 1 ORDER BY Name').single_values.sort
  end
  
  def test_group_by_card_type
    story_card = create_card!(:name => 'story 1', :card_type => @story_type, :size => '1')
    
    bug1 = create_card!(:name => 'bug 1', :card_type => @bug_type, :size => '2')
    bug2 = create_card!(:name => 'bug 2', :card_type => @bug_type, :size => '1')
    
    result = CardQuery.parse('SELECT type, SUM(Size) GROUP BY type').values
    
    # need to convert size to string because postgres adapters under cruby return bigdecimals and under jruby return strings
    # mysql adapters behave well under both cruby and jruby and return strings. the following is an attempt to get only one
    # decimal point under all platforms. Hence the twistedness.
    result.collect {|x| x["Sum size"] = BigDecimal.new(x["Sum size"].to_s).to_f.to_s}
    expected = [{"Sum size"=>"3.0", "Type"=>"bug"}, {"Sum size"=>"1.0", "Type"=>"story"}]
    
    assert_equal expected.sort_by{|row| row['Type']}, result.sort_by{|row| row['Type']}
  end
  
  def test_order_by_card_type
    @card_type = @project.card_types.find_by_name("Card")
    @card_type.position = 2
    @card_type.save_without_reorder_values!
    
    @story_type.position = 3
    @story_type.save_without_reorder_values!

    @bug_type.position = 1
    @bug_type.save_without_reorder_values!
    
    card1 = create_card!(:name => 'card 1', :card_type => @card_type)
    story1 = create_card!(:name => 'story 1', :card_type => @story_type)
    bug1 = create_card!(:name => 'bug 1', :card_type => @bug_type)

    assert_equal [bug1.name, card1.name, story1.name], CardQuery.parse('SELECT name ORDER BY type').single_values
  end
end
