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

class AggregateTest < ActiveSupport::TestCase  
  
  def setup
    login_as_member
    @project = first_project
    @project.activate
  end
  
  def test_count
    @aggregate = Aggregate.new(@project, AggregateType::COUNT)
    
    card1 = @project.cards.create!(:name => "card1", :card_type_name => 'Card')
    card2 = @project.cards.create!(:name => "card2", :card_type_name => 'Card')
    
    assert_equal 2, @aggregate.result([card1, card2])
  end
  
  def test_sum
    release = @project.find_property_definition('release')
    @aggregate = Aggregate.new(@project, AggregateType::SUM, release)
    
    card1 = @project.cards.create!(:name => "card1", :card_type_name => 'Card', :cp_release => 1)
    card2 = @project.cards.create!(:name => "card2", :card_type_name => 'Card', :cp_release => 2)
    
    assert_equal 3, @aggregate.result([card1, card2])
  end
  
  def test_average
    release = @project.find_property_definition('release')
    @aggregate = Aggregate.new(@project, AggregateType::AVG, release)
    
    card1 = @project.cards.create!(:name => "card1", :card_type_name => 'Card', :cp_release => 1)
    card2 = @project.cards.create!(:name => "card2", :card_type_name => 'Card', :cp_release => 2)
    card3 = @project.cards.create!(:name => "card3", :card_type_name => 'Card', :cp_release => nil)
    
    assert_equal '1.5', @aggregate.result([card1, card2]).to_s
    assert_equal '1.5', @aggregate.result([card1, card2, card3]).to_s
  end
  
  def test_average_with_empty_set_of_values
    release = @project.find_property_definition('release')
    @aggregate = Aggregate.new(@project, AggregateType::AVG, release)
    
    assert_equal '0', @aggregate.result([]).to_s
  end
  
  def test_min_and_max
    release = @project.find_property_definition('release')
    
    card1 = @project.cards.create!(:name => "card1", :card_type_name => 'Card', :cp_release => 1)
    card2 = @project.cards.create!(:name => "card2", :card_type_name => 'Card', :cp_release => 2)
    card3 = @project.cards.create!(:name => "card3", :card_type_name => 'Card', :cp_release => nil)
    
    @aggregate = Aggregate.new(@project, AggregateType::MIN, release)
    assert_equal '1', @aggregate.result([card1, card2]).to_s
    assert_equal '1', @aggregate.result([card1, card2, card3]).to_s
    
    @aggregate = Aggregate.new(@project, AggregateType::MAX, release)
    assert_equal '2', @aggregate.result([card1, card2]).to_s
    assert_equal '2', @aggregate.result([card1, card2, card3]).to_s
  end
  
  def test_aggregate_from_none_cards
    assert_aggregate_result_for_none_cards_equal nil, AggregateType::MIN
    assert_aggregate_result_for_none_cards_equal nil, AggregateType::MAX
    assert_aggregate_result_for_none_cards_equal "0", AggregateType::COUNT
    assert_aggregate_result_for_none_cards_equal nil, AggregateType::SUM
    assert_aggregate_result_for_none_cards_equal nil, AggregateType::AVG
  end
  
  def test_from_params_should_parse_aggregate_type_and_aggregate_column
    aggregate = Aggregate.column_from_params(@project, {:aggregate_type => {:column => 'SUM'}, :aggregate_property => {:column => 'release'}})
    assert_equal AggregateType::SUM, aggregate.aggregate_type
    assert_equal "Release", aggregate.property_definition.name
  end
  
  def test_from_params_should_parse_aggregate_column_for_count
    aggregate = Aggregate.column_from_params( @project, {:aggregate_type  => {:column => 'COUNT'} } )
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
  end
  
  def assert_aggregate_result_for_none_cards_equal(expected, aggregate_type)
    release = @project.find_property_definition('release')
    aggregate = Aggregate.new(@project, aggregate_type, release)
    assert_equal expected, aggregate.result_by_sql("1 != 1")
  end

  def test_count_should_be_valid_aggregate_type
    assert Aggregate.column_valid?(@project, {:aggregate_type  => {:column => 'COUNT'} } )
    assert Aggregate.row_valid?(@project, {:aggregate_type  => {:row => 'COUNT'} } )
  end

  def test_lowercase_count_should_be_valid_aggregate_type
    assert Aggregate.column_valid?(@project, {:aggregate_type  => {:column => 'count'} } )
    assert Aggregate.row_valid?(@project, {:aggregate_type  => {:row => 'count'} } )
  end

  def test_aggregate_property_should_be_valid_when_type_is_count_and_property_is_blank
    assert Aggregate.column_valid?(@project, {:aggregate_type  => {:column => 'count'}, :aggregate_property => {:column => "" } } )
    assert Aggregate.row_valid?(@project, {:aggregate_type  => {:row => 'count'}, :aggregate_property => {:row => "" } } )
  end

  def test_type_and_property_should_be_valid
    assert Aggregate.column_valid?(@project, {:aggregate_type => {:column  => "SUM"}, :aggregate_property  => {:column => "release"} } )
    assert Aggregate.row_valid?(@project, {:aggregate_type => {:row  => "SUM"}, :aggregate_property  => {:row => "release"} } )
  end
  
  def test_nil_should_be_valid_aggregate_type
    assert Aggregate.column_valid?(@project, {:aggregate_type  => {:column => nil} } )
    assert Aggregate.row_valid?(@project, {:aggregate_type  => {:row => nil} } )
  end
  
  def test_NOT_VALID_should_be_invalid_aggregate_type
    assert !Aggregate.column_valid?(@project, {:aggregate_type  => {:column => "NOT_VALID"} } )
    assert !Aggregate.row_valid?(@project, {:aggregate_type  => {:row => "NOT_VALID"} } )
  end
  
  def test_NOT_VALID_should_be_invalid_aggregate_property
    assert !Aggregate.column_valid?(@project, {:aggregate_type  => {:column => "SUM"}, :aggregate_property  => {:column => "NOT_VALID"} } )
    assert !Aggregate.row_valid?(@project, {:aggregate_type  => {:row => "SUM"}, :aggregate_property  => {:row => "NOT_VALID"} } )
  end
  
  def test_should_support_aggregate_for_row
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => {:row => 'SUM'}, :aggregate_property => {:row => 'release'}})
    assert_equal AggregateType::SUM, aggregate.aggregate_type
    assert_equal "Release", aggregate.property_definition.name
  end

  def test_should_support_aggregate_for_row_count
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => {:row => 'COUNT'}})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
    
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => {:row => 'count'}})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
    
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => {:row => 'count'}, :aggregate_property => {:row => ""}})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
  end
  
  def test_row_for_params_should_default_to_count
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => nil})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
  end

  def test_column_for_params_should_default_to_count
    aggregate = Aggregate.column_from_params(@project, {:aggregate_type => nil})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
  end
  
  def test_should_default_to_count_when_property_does_not_exist
    aggregate = Aggregate.row_from_params(@project, {:aggregate_type => {:row => 'SUM'}, :aggregate_property => {:row => 'doesnt exist'}})
    assert_equal AggregateType::COUNT, aggregate.aggregate_type
    assert_nil aggregate.property_definition
  end

end
