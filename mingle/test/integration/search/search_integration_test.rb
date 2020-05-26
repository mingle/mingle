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

require File.expand_path(File.dirname(__FILE__) + '/search_test_helper')

class SearchIntegrationTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  fixtures :users, :login_access

  def setup
    @admin = login_as_admin
    ElasticSearch.delete_index
  end

  def test_should_only_search_in_activated_project
    with_new_project do |project|
      project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki in project1')
      project.cards.create!(:name => 'a card has wiki desc', :card_type => project.card_types.first)
      run_all_search_message_processors
    end

    with_new_project do |project|
      page = project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki in project2')
      run_all_search_message_processors
      result = Search::Client.new(:highlight => false).find('wiki')
      assert_equal 1, result.size
      assert_equal 'This is my first wiki in project2', result.first.content
    end
  end

  def test_should_delete_indexed_data_on_project_deletion
    project1 = with_new_project do |project|
      project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki in project1')
      project
    end

    with_new_project do |project|
      project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki in project2')
      run_all_search_message_processors
      result = Search::Client.new(:highlight => false).find('wiki')
      assert_equal 1, result.size

      project.destroy
      result = Search::Client.new(:highlight => false).find('wiki')
      assert_equal 0, result.size
    end

    project1.with_active_project do |project|
      result = Search::Client.new(:highlight => false).find('wiki')
      assert_equal 1, result.size
      assert_equal "This is my first wiki in project1", result.first.content
    end
  end

  def test_should_treat_page_names_as_string
    with_new_project do |project|
      page1 = project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki')
      page2 = project.pages.create!(:name => '2011-10-10', :content => 'This is my first wiki')
      run_all_search_message_processors
      names = Search::Client.new.find('wiki').map(&:name)
      assert_equal [page1.name, page2.name], names
    end
  end

  def test_should_be_able_to_find_a_recently_created_page
    with_new_project do |project|
      page = project.pages.create!(:name => 'Elastic', :content => 'This is my first wiki')
      run_all_search_message_processors
      actual = Search::Client.new.find('wiki').first
      assert_equal page.id, actual.identifier.to_i
    end
  end

  def test_should_be_able_to_find_italicized_word_in_page
    with_new_project do |project|
      page = project.pages.create!(:name => 'Elastic', :content => 'This is my first _wiki_')
      run_all_search_message_processors
      result = Search::Client.new.find('wiki')
      assert result.any?
      actual = result.first
      assert_equal page.id, actual.identifier.to_i
    end
  end

  def test_should_be_able_to_find_terms_wrapped_in_html_on_wysiwyg_cards
    with_new_project do |project|
      card = create_card!(:name => 'card with html content', :card_type_name => 'Card', :description => '<h1>Heading</h1>\n<p>Hello!</p>')
      run_all_search_message_processors
      result = Search::Client.new.find('heading')
      assert result.any?
      actual = result.first
      assert_equal card.id, actual.identifier.to_i
    end
  end

  def test_should_be_able_to_find_italicized_word_in_card
    with_new_project do |project|
      card = create_card!(:name => 'emphasis in original', :card_type_name => 'Card', :description => 'This is my first _italics_')
      run_all_search_message_processors
      result = Search::Client.new.find('italics')
      assert result.any?
      actual = result.first
      assert_equal card.id, actual.identifier.to_i
    end
  end

  def test_deleted_page_should_be_removed_from_index
    with_new_project do |project|
      page = project.pages.create!(:name => 'Scarlet Witch', :content => 'And your little dog too!')
      run_all_search_message_processors
      assert_include page.id.to_s, Search::Client.new.find('witch').collect(&:identifier)
      page.destroy
      FullTextSearch::DeindexingSearchablesProcessor.run_once
      ElasticSearch.refresh_indexes
      assert Search::Client.new.find('witch').empty?
    end
  end

  def test_deleted_card_should_be_removed_from_index
    with_new_project do |project|
      card = project.cards.create!(:name => 'Ape X', :card_type => project.card_types.first)
      run_all_search_message_processors
      assert_include card.id.to_s, Search::Client.new.find('ape').collect(&:identifier)
      card.destroy
      FullTextSearch::DeindexingSearchablesProcessor.run_once
      ElasticSearch.refresh_indexes
      assert Search::Client.new.find('ape').empty?
    end
  end

  def test_bulk_destroy_cards_should_all_be_removed_from_the_index
    with_new_project do |project|
      card1 = project.cards.create!(:name => 'Ape X', :card_type => project.card_types.first)
      card2 = project.cards.create!(:name => 'Ape Z', :card_type => project.card_types.first)
      run_all_search_message_processors
      assert_equal [card1.id.to_s, card2.id.to_s].sort, Search::Client.new.find('ape').collect(&:identifier).sort
      CardSelection.new(project.reload, [card1, card2]).destroy
      ElasticSearch.refresh_indexes
      assert Search::Client.new.find('ape').empty?
    end
  end

  def test_murmurs_should_be_indexed_on_creation
    with_new_project do |project|
      murmur = create_murmur(:murmur => 'The history of moleskine notebooks')
      run_all_search_message_processors
      actual = Search::Client.new.find("moleskine").first
      assert_equal murmur.id, actual.identifier.to_i
    end
  end

  def test_search_should_retrieve_results_across_all_indexed_models
    with_new_project do |project|
      page = project.pages.create!(:name => 'Bohemian rhapsody', :content => 'By the same band as bicycle race')
      murmur = create_murmur(:murmur => 'Bicycle race')
      run_all_search_message_processors
      results = Search::Client.new.find('bicycle')
      assert_equal 2, results.size

      result_page = results.select{|r| r.is_a? Result::Page}.first
      result_murmur = results.select{|r| r.is_a? Result::Murmur}.first

      assert_equal page.id, result_page.identifier.to_i
      assert_equal murmur.id, result_murmur.identifier.to_i
    end
  end

  def test_cards_should_be_indexed_on_creation
    with_new_project do |project|
      card = create_card!(:name => 'Klaw', :card_type => project.card_types.first)
      run_all_search_message_processors
      klaw = Search::Client.new.find('Klaw').first
      assert_equal card.id, klaw.identifier.to_i
    end
  end

  def test_card_type_should_be_indexed_on_creation
    with_new_project do |project|
      card = create_card!(:name => 'card with some type', :card_type => project.card_types.first)
      run_all_search_message_processors
      klaw = Search::Client.new.find('some type').first
      assert_equal card.card_type_name, klaw.card_type_name
    end
  end

  def test_cards_should_be_indexed_on_update
    with_new_project do |project|
      card = create_card!(:name => 'Klaw', :card_type => project.card_types.first)
      run_all_search_message_processors
      card.name = "new name"
      card.save!
      run_all_search_message_processors
      klaw = Search::Client.new.find('new name').first
      assert_equal card.id, klaw.identifier.to_i
    end
  end

  def test_search_with_illegal_syntax_should_return_no_results
    with_new_project do |project|
      assert_equal [], Search::Client.new.find('AND OR')
    end
  end

  def test_search_with_empty_string_query_should_return_no_results
    with_new_project do |project|
      assert_equal [], Search::Client.new.find('')
    end
  end

  def test_search_should_default_to_AND
    with_new_project do |project|
      create_card!(:name => 'Bear Klaw', :card_type => project.card_types.first)
      create_card!(:name => 'Bear has a Klaw', :card_type => project.card_types.first)
      create_card!(:name => 'Klaw', :card_type => project.card_types.first)
      create_card!(:name => 'Bear', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_equal ["<span class='name fragment_highlight'>Bear</span> <span class='name fragment_highlight'>Klaw</span>", "<span class='name fragment_highlight'>Bear</span> has a <span class='name fragment_highlight'>Klaw</span>"], Search::Client.new.find('Bear Klaw').map(&:name).sort
      assert_equal ["<span class='name fragment_highlight'>Bear</span> <span class='name fragment_highlight'>Klaw</span>", "<span class='name fragment_highlight'>Bear</span> has a <span class='name fragment_highlight'>Klaw</span>"], Search::Client.new.find('Bear AND Klaw').map(&:name).sort
      assert_equal ["<span class='name fragment_highlight'>Bear</span>", "<span class='name fragment_highlight'>Bear</span> <span class='name fragment_highlight'>Klaw</span>", "<span class='name fragment_highlight'>Bear</span> has a <span class='name fragment_highlight'>Klaw</span>", "<span class='name fragment_highlight'>Klaw</span>"], Search::Client.new.find('Bear OR Klaw').map(&:name).sort
    end
  end

  def test_reindex_project_should_not_delete_old_project_index_first
    with_new_project do |project|
      card = create_card!(:name => 'Black Queen', :card_type => project.card_types.first)
      run_all_search_message_processors
      assert_equal 1, Search::Client.new.find('Black Queen').size
      project.update_full_text_index
      assert_equal 1, Search::Client.new.find('Black Queen').size
    end
  end

  def test_reindex_project_with_skip_delete_should_not_delete_old_project_index_first
    with_new_project do |project|
      card = create_card!(:name => 'Black Queen', :card_type => project.card_types.first)
      run_all_search_message_processors
      assert_equal 1, Search::Client.new.find('queen').size
      project.update_full_text_index(:skip_delete => true)
      assert_equal 1, Search::Client.new.find('queen').size
    end

  end

  def test_deindex_multiple_cards_should_remove_them_from_the_index
    with_new_project do |project|
      card1 = create_card!(:name => 'Omega I', :card_type => project.card_types.first)
      card2 = create_card!(:name => 'Omega II', :card_type => project.card_types.first)
      card3 = create_card!(:name => 'Omega III', :card_type => project.card_types.first)
      run_all_search_message_processors
      assert_equal 3, Search::Client.new.find('omega').size
      ElasticSearch.deindex([card1.id, card2.id, card3.id], project.search_index_name, "cards")
      ElasticSearch.refresh_indexes
      assert_equal 0, Search::Client.new.find('omega').size
    end
  end


  def test_destroy_project_should_remove_project_index
    project = create_project
    project.activate
    create_card!(:name => 'Lord Chaos', :card_type => project.card_types.first)
    run_all_search_message_processors
    project.deactivate
    assert_equal 1, search_cross_all_indexes('chaos').size

    project.destroy
    ElasticSearch.refresh_indexes
    assert_equal [], search_cross_all_indexes('chaos')
  end

  def test_should_reindex_all_projects_if_no_indices_found
    with_new_project do |project|
      create_card!(:name => 'Bear Klaw', :card_type => project.card_types.first)
    end
    run_all_search_message_processors
    ElasticSearch.delete_index
    assert FullTextSearch.rebuild_index_if_missing
    run_all_search_message_processors
    assert_equal 1, search_cross_all_indexes('Bear').size
  end

  def test_index_missing
    assert ElasticSearch.index_missing?
    with_new_project do |project|
      create_card!(:name => 'Bear Klaw', :card_type => project.card_types.first)
    end
    assert ElasticSearch.index_missing?
    run_all_search_message_processors
    assert !ElasticSearch.index_missing?
  end

  def test_card_with_html_content_should_be_escaped_as_human_readable_characters
    with_new_project do |project|
      card = project.cards.create!(:name => '<h1>Zip Zap</h1>', :content => 'Hello <b>horse</b>', :card_type => project.card_types.first)
      run_all_search_message_processors
      result = Search::Client.new.find('zip')
      assert_equal 'Hello horse', result.first.short_description
    end
  end

  def test_elastic_search_server_url
    original = ["mingle.search.host", "mingle.search.port", "mingle.search.url"].inject([]) do |r, prop|
      System.getProperty(prop)
      r
    end
    System.clearProperty("mingle.search.url")
    System.setProperty("mingle.search.host", "host")
    System.setProperty("mingle.search.port", "9999")
    assert_equal "http://host:9999", ElasticSearch.elastic_search_server_url

    # should take precedence over the previous two properties
    System.setProperty("mingle.search.url", "https://search.escluster.com")
    assert_equal "https://search.escluster.com", ElasticSearch.elastic_search_server_url
  ensure
    ["mingle.search.host", "mingle.search.port", "mingle.search.url"].each do |prop|
      value = original.shift
      value.nil? ? System.clearProperty(prop) : System.setProperty(prop, value)
    end
  end

  def test_search_card_with_added_term_filter
    with_new_project do |project|
      type_release = project.card_types.create :name => 'release'
      type_story = project.card_types.create :name => 'story'

      release_card = project.cards.create!(:name => 'release card', :card_type => type_release)
      story_card = project.cards.create!(:name => 'story card', :card_type => type_story)
      run_all_search_message_processors

      search = Search::Client.new

      cards = search.find(:q => 'card card_type_name:release').collect(&:identifier)

      assert_equal 1, cards.size

      assert_equal release_card.id.to_s, cards.first
    end
  end

  def test_search_card_with_multiple_term_filter
    with_new_project do |project|
      type_release = project.card_types.create :name => 'release'
      type_story = project.card_types.create :name => 'story'
      type_iteration = project.card_types.create :name => 'iteration'

      release_card = project.cards.create!(:name => 'release card', :card_type => type_release)
      story_card = project.cards.create!(:name => 'story card', :card_type => type_story)
      iteration_card = project.cards.create!(:name => 'iteration card', :card_type => type_iteration)
      run_all_search_message_processors

      search = Search::Client.new
      cards = search.find(:q => 'card AND (card_type_name:Release OR card_type_name:Story)').collect(&:identifier).map(&:to_i)
      assert_equal 2, cards.size
      assert_include release_card.id, cards
      assert_include story_card.id, cards
    end
  end

  def test_search_limits_result_size
    with_new_project do |project|
      type_release = project.card_types.create :name => 'release'
      type_story = project.card_types.create :name => 'story'
      type_iteration = project.card_types.create :name => 'iteration'

      release_card = project.cards.create!(:name => 'release card', :card_type => type_release)
      story_card = project.cards.create!(:name => 'story card', :card_type => type_story)
      iteration_card = project.cards.create!(:name => 'iteration card', :card_type => type_iteration)
      run_all_search_message_processors

      search = Search::Client.new(:results_limit => 2)
      cards = search.find(:q => 'card')

      assert_equal 2, cards.size
      assert_equal 3, cards.total_entries
    end
  end

  def test_search_matches_on_given_fields
    with_new_project do |project|
      type_release = project.card_types.create :name => 'release'
      type_story = project.card_types.create :name => 'story'
      type_iteration = project.card_types.create :name => 'iteration'

      release_card = project.cards.create!(:name => 'release card', :card_type => type_release)
      story_card = project.cards.create!(:name => 'story card', :card_type => type_story)
      iteration_card = project.cards.create!(:name => 'iteration card', :card_type => type_iteration, :description  => "neither story nor release")
      run_all_search_message_processors

      search = Search::Client.new

      card_ids = search.find(:q  => 'story', :search_fields => ['name'], :type => "cards").collect(&:identifier).map(&:to_i)
      assert_equal 1, card_ids.size
      assert_equal story_card.id, card_ids.first

      card_ids = search.find(:q  => "#{release_card.number}", :search_fields => ['name','number']).collect(&:identifier).map(&:to_i)
      assert_equal 1, card_ids.size
      assert_equal release_card.id, card_ids.first
    end
  end

  def test_include_specific_field_in_search_query
    with_new_project do |project|
      type_epic_story = project.card_types.create :name => 'Epic Story'
      type_story = project.card_types.create :name => 'Story'

      story_card = project.cards.create!(:name => 'story card', :card_type => type_story)
      iteration_card = project.cards.create!(:name => 'epic card', :card_type => type_epic_story)
      run_all_search_message_processors

      search = Search::Client.new
      cards = search.find(:q => 'card card_type_name:"epic story"')
      assert_equal 1, cards.size
      cards = search.find(:q => "card card_type_id:#{type_epic_story.id}")
      assert_equal 1, cards.size

      cards = search.find(:q => 'card card_type_name:"story"')
      assert_equal 2, cards.size

      cards = search.find(:q => "card card_type_id:#{type_story.id}")
      assert_equal 1, cards.size
    end
  end

  def test_should_reindex_user_info_for_murmur_when_user_profile_is_changed
    login_as_member
    with_new_project do |project|
      project.add_member(User.current)
      murmur = create_murmur(:murmur => "I love saloon music")

      run_all_search_message_processors
      result = Search::Client.new.find(:q => User.current.name).first
      assert_equal murmur.id.to_s, result.identifier

      User.current.update_attributes(:name => "Bilbo Baggins")
      run_all_search_message_processors
      result = Search::Client.new.find(:q => "Bilbo").first
      assert result
      assert_equal murmur.id.to_s, result.identifier
    end
  end

  def test_should_reindex_user_info_for_card_when_user_profile_is_changed
    login_as_member
    with_new_project do |project|
      project.add_member(User.current)
      card = project.cards.create!(:name => 'some card', :card_type_name => 'card')

      run_all_search_message_processors
      result = Search::Client.new.find(:q => User.current.name).first
      assert_equal card.id.to_s, result.identifier

      User.current.update_attributes(:name => "Bilbo Baggins")
      run_all_search_message_processors
      result = Search::Client.new.find(:q => "Bilbo").first
      assert result
      assert_equal card.id.to_s, result.identifier
    end
  end

  def test_should_reindex_user_info_for_card_modified_by_user_when_user_profile_is_changed
    login_as_member
    with_new_project do |project|
      project.add_member(User.current)
      bob = User.find_by_login('bob')
      project.add_member(bob)
      card = project.cards.create!(:name => 'some card', :card_type_name => 'card')
      login_as_bob
      card.update_attributes(:name => 'new name')

      run_all_search_message_processors
      result = Search::Client.new.find(:q => User.current.name).first
      assert_equal card.id.to_s, result.identifier

      bob.update_attributes(:name => "SuperBob")
      run_all_search_message_processors
      result = Search::Client.new.find(:q => "SuperBob").first
      assert result
      assert_equal card.id.to_s, result.identifier
    end
  end

  def test_should_reindex_user_info_for_page_when_user_profile_is_changed
    login_as_member
    with_new_project do |project|
      project.add_member(User.current)
      bob = User.find_by_login('bob')
      project.add_member(bob)
      page = project.pages.create!(:name => 'whoa', :content => 'What if the Monty Python cast sung the Bohemian Rhapsody ')
      login_as_bob
      page.update_attributes(:name => 'new name')

      run_all_search_message_processors
      result = Search::Client.new.find(:q => User.current.name).first
      assert_equal page.id.to_s, result.identifier

      bob.update_attributes(:name => "SuperBob")
      run_all_search_message_processors
      result = Search::Client.new.find(:q => "SuperBob").first
      assert result
      assert_equal page.id.to_s, result.identifier
    end
  end

  def test_should_reindex_user_info_for_pages_modified_by_user_when_user_profile_is_changed
    login_as_member
    with_new_project do |project|
      project.add_member(User.current)
      bob = User.find_by_login('bob')
      project.add_member(bob)
      page = project.pages.create!(:name => 'whoa', :content => 'What if the Monty Python cast sung the Bohemian Rhapsody ')
      login_as_bob
      page.update_attributes(:name => 'new name')

      run_all_search_message_processors
      result = Search::Client.new.find(:q => User.current.name).first
      assert_equal page.id.to_s, result.identifier

      bob.update_attributes(:name => "SuperBob")
      run_all_search_message_processors
      result = Search::Client.new.find(:q => "SuperBob").first
      assert result
      assert_equal page.id.to_s, result.identifier
    end
  end

  def test_creating_a_card_belonging_updates_the_card_index
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      type_story = project.card_types.find_by_name 'Story'
      story_card = project.cards.create!(:number => 1001, :name => 'story card', :card_type => type_story)
      run_all_search_message_processors

      configuration.add_child(story_card)
      run_all_search_message_processors
      search = Search::Client.new
      cards = search.find(:q => "number:1001 AND tree_configuration_ids:#{configuration.id}")
      assert_equal [1001], cards.map(&:number)
    end
  end

  def test_should_update_the_card_index_after_removed_card_from_tree
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      type_story = project.card_types.find_by_name 'Story'
      story_card = project.cards.create!(:number => 1001, :name => 'story card', :card_type => type_story)
      run_all_search_message_processors

      configuration.add_child(story_card)
      run_all_search_message_processors

      configuration.remove_card(story_card)
      run_all_search_message_processors

      search = Search::Client.new
      cards = search.find(:q => "number:1001 AND tree_configuration_ids:#{configuration.id}")
      assert_equal [], cards.map(&:number)
    end
  end

  def test_search_should_be_case_insensitive
    with_new_project do |project|
      page = project.pages.create!(:name => "news", :content => 'Thomson reuters')
      run_all_search_message_processors

      search = Search::Client.new
      results = search.find(:q => "thomson")
      assert_equal 1, results.size
      assert_equal "news", results.first.name

      search = Search::Client.new
      results = search.find(:q => "Reuters")
      assert_equal 1, results.size
      assert_equal "news", results.first.name

    end
  end

  def test_date_detection_should_be_disabled
    ElasticSearch.create_index_with_mappings
    with_new_project do |project|
      setup_property_definitions(:date_like => ['2014-01-01', '2014-01-02', 'foo'])
      card1 = create_card!(:name => 'first', :date_like => '2014-01-02')
      card2 = create_card!(:name => 'second', :date_like => 'zoo keeper')

      card1.reindex
      card2.reindex
    end
  end

  def test_should_not_full_text_index_ranking_infomation
    with_new_project do |project|
      card = create_card!(:name => 'first')
      card.update_attribute(:project_card_rank, 1234)
      run_all_search_message_processors
      assert_equal [], Search::Client.new(:highlight => false).find('1234')
    end
  end

  def test_should_update_card_search_index_directly_after_updated_tag_name
    with_new_project do |project|
      card = create_card!(:name => 'first')
      card.tag_with 'bar_foo'
      run_all_search_message_processors
      assert_equal "first", Search::Client.new(:highlight => false).find('bar_foo').first.name

      project.tags.find_by_name('bar_foo').update_attribute(:name, "bar_zoo")

      run_all_search_message_processors
      assert_equal "first", Search::Client.new(:highlight => false).find("bar_zoo").first.name
      assert_equal [], Search::Client.new(:highlight => false).find('bar_foo')
    end
  end


  def test_search_should_stem
    with_new_project do |project|
      content = "The operator caresses ponies and ties cats with gyroscopic irritant to formalize probation hence listing happiness. That lasted triplicate longer with fastest stemming and stayed merrily devoted"
      project.pages.create!(:name => "snowball", :content => content)
      run_all_search_message_processors
      search = Search::Client.new

      ['caress', 'pony', 'cat', 'operate', 'gyroscope', 'irritate', 'formal', 'probate', 'list', 'last', 'stem', 'happy', 'devote'].each do |search_term|
        results = search.find(:q => search_term)
        assert_equal 1, results.size, "Search term #{search_term} should have yielded 1 result"
        assert_equal "snowball", results.first.name
      end

      ['triple', 'long', 'fast', 'merry'].each do |search_term|
        results = search.find(:q => search_term)
        assert_equal 0, results.size, "Search term #{search_term} should not have yielded a result"
      end

    end
  end

  def test_should_update_card_indexing_when_rename_card_type
    with_new_project do |project|
      login_as_admin
      setup_property_definitions(:release => ['1','2'], :status => ['new', 'open'], :priority => ['low', 'high'])

      story_card_type = setup_card_type(project, 'story', :properties => ['release', 'status', 'priority'])
      story_1 = project.cards.create!(:card_type_name => 'story', :name => 'story 1', :cp_release => '1', :cp_status => 'new', :cp_priority => 'high')
      story_2 = project.cards.create!(:card_type_name => 'story', :name => 'story 2', :cp_release => '1', :cp_status => 'new', :cp_priority => 'high')
      run_all_search_message_processors

      assert_equal 2, Search::Client.new.find('story').size

      story_card_type.name = 'bunnies'
      story_card_type.save!

      run_all_search_message_processors

      assert_equal 2, Search::Client.new.find('bunnies').size
    end
  end

  def test_should_highlight_card_properties
    with_new_project do |project|
      login_as_admin
      setup_property_definitions(:status => ['new', 'open'], :release => ['willie wagtail', 'puffin'])
      story_card_type = setup_card_type(project, 'story', :properties => ['status', 'release'])
      story_1 = project.cards.create!(:card_type_name => 'story', :name => "Story 1", :cp_status => 'new', :cp_release => 'willie wagtail')

      run_all_search_message_processors
      results = Search::Client.new.find('new', { :properties => ['status'] })

      assert_equal 1, results.size
      assert results.first.highlighted? "status"
    end
  end

  def test_should_highlight_description
    with_new_project do |project|
      project.pages.create!(:name => 'highlight me', :content => "this is the term you're looking for")
      run_all_search_message_processors
      results = Search::Client.new.find('term')
      assert_equal 1, results.size
      assert results.first.highlighted? 'indexable_content'
    end
  end

  def test_should_highlight_user_property
    with_new_project do |project|
      bob = User.find_by_login('bob')
      owner_prop_def = setup_user_definition 'Owner'
      project.add_member(bob)
      card = project.cards.create!(:card_type_name => 'Card', :name => "Story 1", :cp_owner => bob)

      run_all_search_message_processors

      results = Search::Client.new.find('bob', :properties => ['owner'] )

      assert_equal 1, results.size
      assert results.first.highlighted? "owner"
    end
  end

  private

  def search_cross_all_indexes(q)
    ElasticSearch.search({}, Search::Query.new(q), '', nil)['hits']['hits']
  rescue ElasticSearch::SearchPhaseExecutionException
    []
  end
end
