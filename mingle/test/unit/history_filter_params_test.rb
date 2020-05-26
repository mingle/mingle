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
class HistoryFilterParamsTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    login_as_member
    @filter_user = @project.users.first
    @hash_params = {'involved_filter_properties' => {"type" => "card"},
              'acquired_filter_properties'  =>  {"status" => "done"},
              'involved_filter_tags' => "apple",
              'acquired_filter_tags' => "orange",
              'filter_user' => @filter_user.id.to_s,
            }
    @str_params = URI.unescape(@hash_params.to_query)
  end

  def test_to_hash
    assert_equal(@hash_params, HistoryFilterParams.new(@hash_params).to_hash)
    assert_equal(@hash_params, HistoryFilterParams.new(@str_params).to_hash)
    assert_equal({}, HistoryFilterParams.new.to_hash)
  end

  def test_generate_history_filter
    filter_params = HistoryFilterParams.new(@hash_params)
    filter = filter_params.generate_history_filter(@project)
    assert_equal(@project, filter.project)
    excepted = {
      :involved_filter_properties => {"type" => "card"},
      :acquired_filter_properties =>  {"status" => "done"},
      :involved_filter_tags => ["apple"],
      :acquired_filter_tags => ["orange"],
      :filter_user => @filter_user.id.to_s,
    }
    assert_equal(excepted, filter.filters)
  end

  def test_init_by_params_hash
    filter_params = HistoryFilterParams.new(@hash_params)

    assert_equal(@str_params, filter_params.serialize)
    assert_equal(@hash_params, ActionController::Request.parse_query_parameters(filter_params.serialize))
  end

  def test_init_by_params_hash_using_symbol_as_keys
    assert_equal ['apple'], HistoryFilterParams.new(:involved_filter_tags => 'apple').involved_filter_tags
  end

  def test_init_by_params_str
    filter_params = HistoryFilterParams.new(@str_params)

    assert_equal @str_params, filter_params.serialize
    assert_equal @filter_user.id.to_s, filter_params.filter_user
    assert_equal ['apple'], filter_params.involved_filter_tags
    assert_equal ['orange'], filter_params.acquired_filter_tags
    assert_equal({'type' => 'card'}, filter_params.involved_filter_properties)
    assert_equal({"status" => "done"}, filter_params.acquired_filter_properties)
  end

  def test_init_by_params_str_should_ignore_params_not_need
    str = @hash_params.merge(:param_should_be_ignored => 'value').to_query

    filter_params = HistoryFilterParams.new(str)
    assert_equal(@str_params, filter_params.serialize)
  end

  def test_init_by_empty_params_hash
    assert_all_params_and_serialize_nil HistoryFilterParams.new
    assert_all_params_and_serialize_nil HistoryFilterParams.new(nil)
  end

  def test_should_reject_params_the_value_of_which_is_ignored
    params = {'involved_filter_properties' => {"type" => PropertyValue::IGNORED_IDENTIFIER},
              'acquired_filter_properties'  =>  {"status" => PropertyValue::IGNORED_IDENTIFIER},
              'involved_filter_tags' => '',
              'acquired_filter_tags' => '',
              'filter_user' => ''
            }

    filter_params = HistoryFilterParams.new(params)
    assert_all_params_and_serialize_nil filter_params
  end

  def test_involved_filter_tags_and_acquired_filter_tags
    tags_filters = ['involved_filter_tags', 'acquired_filter_tags']
    tags_filters.each do |filter_tags|
      assert_equal(['tech'], HistoryFilterParams.new(filter_tags => 'tech').send(filter_tags))
    end
  end

  def test_involved_filter_properties_and_acquired_filter_properties
    properties_filters = ['involved_filter_properties', 'acquired_filter_properties']
    properties = {'type' => 'card'}
    properties_filters.each do |filter_properties|
      assert_equal(properties, HistoryFilterParams.new(filter_properties => properties).send(filter_properties))
    end
  end

  def test_users_injected_into_involved_and_acquired_filter_properties
    member = User.find_by_login 'member'
    admin = User.find_by_login 'admin'
    @project.add_member(admin)
    params = {:involved_filter_properties => {'dev' => member.id.to_s}, :acquired_filter_properties => {'dev' => admin.id.to_s}}
    filter_params = HistoryFilterParams.new(params)
    assert_equal 1, filter_params.involved_filter_properties.size
    assert_equal member.id.to_s, filter_params.involved_filter_properties['dev']
    assert_equal 1, filter_params.acquired_filter_properties.size
    assert_equal admin.id.to_s, filter_params.acquired_filter_properties['dev']
  end

  def test_should_handle_nil_request_params_as_empty_values
    assert_equal({:type => ''}, HistoryFilterParams.new(:acquired_filter_properties => {:type => nil}).acquired_filter_properties)
    assert_equal({:type => ''}, HistoryFilterParams.new(:involved_filter_properties => {:type => nil}).involved_filter_properties)
  end

  def test_should_be_able_to_specify_proper_descriptions_for_cards_and_pages
    @project.with_active_project do |p|
      page_with_name_not_ending_in_page = @project.pages.create!(:name => 'Team Details')
      first_card = @project.cards.first
      assert_equal "Card #{first_card.number_and_name}", HistoryFilterParams.new(:card_number => first_card.number).description(@project)
      assert_equal "First Page", HistoryFilterParams.new(:page_identifier => @project.pages.find_by_name('First Page').identifier).description(@project)
      assert_equal "Team Details page", HistoryFilterParams.new(:page_identifier => page_with_name_not_ending_in_page.identifier).description(@project)
    end
  end

  def test_should_be_local_when_card_number_is_present
    params = HistoryFilterParams.new(:card_number => '2535')
    assert_is_local params
  end

  def test_should_be_local_when_page_number_is_present
    params = HistoryFilterParams.new(:page_identifier => 10)
    assert_is_local params
  end

  def test_card_returns_whether_card_number_is_present
    assert_equal true, HistoryFilterParams.new(:card_number => '2535').card?
    assert_equal false, HistoryFilterParams.new(:page_identifier => 10).card?
  end

  def test_page_returns_whether_page_identifier_is_present
    assert_equal true, HistoryFilterParams.new(:page_identifier => 10).page?
    assert_equal false, HistoryFilterParams.new(:card_number => '2535').page?
  end

  def test_should_have_global_criteria_when_involved_filter_properties_present
    params = HistoryFilterParams.new(:involved_filter_properties => {"type" => "card"})
    assert_has_global_criteria params
  end

  def test_should_have_global_criteria_when_involved_filter_tags_present
    params = HistoryFilterParams.new(:involved_filter_tags => "apple")
    assert_has_global_criteria params
  end

  def test_should_have_global_criteria_when_acquired_filter_properties_present
    params = HistoryFilterParams.new(:acquired_filter_properties  =>  {"status" => "done"})
    assert_has_global_criteria params
  end

  def test_should_have_global_criteria_when_acquired_filter_tags_present
    params = HistoryFilterParams.new(:acquired_filter_tags => "orange")
    assert_has_global_criteria params
  end

  def test_should_include_involved_filter_when_involved_filter_properties_or_tags_present
    assert HistoryFilterParams.new(:involved_filter_properties => {'status' => 'done'}).include_involved_filter?
    assert HistoryFilterParams.new(:involved_filter_tags => 'apple').include_involved_filter?
    assert !HistoryFilterParams.new(:acquired_filter_tags => 'apple').include_involved_filter?
  end

  def test_should_include_acquired_filter_when_acquired_filter_properties_or_tags_present
    assert HistoryFilterParams.new(:acquired_filter_properties => {'status' => 'done'}).include_acquired_filter?
    assert HistoryFilterParams.new(:acquired_filter_tags => 'apple').include_acquired_filter?
    assert !HistoryFilterParams.new(:involved_filter_tags => 'apple').include_acquired_filter?
  end

  def test_filter_types_should_receive_friendly_names
    with_first_project do |project|
      assert_equal ['Cards', 'Pages'], HistoryFilterParams.new(:filter_types => {'cards' => 'Card%3A%3AVersion', 'pages' => 'Page%3A%3AVersion'}).friendly_filter_types(project)
      assert_equal ['Pages', 'Revisions'], HistoryFilterParams.new(:filter_types => {'revisions' => 'Revision', 'pages' => 'Page%3A%3AVersion'}).friendly_filter_types(project)
    end
  end

  def test_should_have_global_criteria_when_filter_types_present
    params = HistoryFilterParams.new(:filter_types => {'cards' => 'Card%3A%3AVersion', 'revisions' => 'Revision'})
    assert_has_global_criteria params
    assert params.include_filter_types?
  end

  def test_should_ignore_filter_types_when_all_of_them_are_present
    params = HistoryFilterParams.new(:filter_types => {'cards' => 'Card%3A%3AVersion', 'revisions' => 'Revision', 'pages' => 'Page%3A%3AVersion'})
    assert !params.include_filter_types?
    assert !params.has_global_criteria?
    assert !params.local?
    assert params.global?
  end

  private

  def assert_is_local(params)
    assert params.local?
    assert !params.global?
    assert !params.has_global_criteria?
    assert !params.include_filter_types?
  end

  def assert_has_global_criteria(params)
    assert params.has_global_criteria?
    assert params.global?
    assert !params.local?
  end

  def assert_all_params_and_serialize_nil(params)
    assert_nil params.serialize
    assert_nil params.filter_user
    assert_nil params.involved_filter_tags
    assert_nil params.acquired_filter_tags
    assert_nil params.involved_filter_properties
    assert_nil params.acquired_filter_properties
  end

end
