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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

class HistoryControllerMessagingTest < ActionController::TestCase
  include HistoryHelper
  include MessagingTestHelper
  
  def setup
    Clock.reset_fake
    @controller = create_controller HistoryController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
    ActionMailer::Base.deliveries = []
    
    @member_user = User.find_by_login('member')
    login_as_member

    @project = create_project :users => [@member_user]
    setup_property_definitions :feature => ['email', 'atom'], :status => ['open', 'new'], :old_type => ['card']
    
    @project.update_attributes(:email_address =>  'email@address.com', :email_sender_name => 'thoughtworks')
  end
  
  def teardown
    Clock.reset_fake
  end

  def test_atom_feed_should_show_version_info_for_card
    #version 1
    card = create_card!(:name => "I am a card")
    # version 2
    card.cp_status = 'open'
    card.save!
    HistoryGeneration.run_once
    get_history_atom
    assert @response.body.include?("View this version (v1)")
    assert @response.body.include?("View latest version")
  end
  

  def test_can_get_history_feed_based_on_encrypted_history_spec_based_on_tag
    card1 = create_card 1
    card1.update_attributes :cp_feature => 'email', :cp_status => 'open'    
    card2 = create_card 2
    HistoryGeneration.run_once
    encrypted_history_spec = @project.encrypt("acquired_filter_tags=&involved_filter_properties[feature]=email")
    get :feed, {:format => "atom", :project_id => @project.identifier, :encrypted_history_spec => encrypted_history_spec}

    assert_response :success
    
    assert_card_included card1
    assert_card_not_included card2
  end

  def test_can_get_history_feed_based_on_encrypted_history_spec_with_empty_set
    card1 = create_card(1)
    card1.update_attributes(:description => 'Blah blah #123 blah blah')
    HistoryGeneration.run_once

    encrypted_history_spec = @project.encrypt("")
    get :feed, {:format => "atom", :project_id => @project.identifier, :encrypted_history_spec => encrypted_history_spec }
    assert_response :success
    assert_tag 'link', :attributes => {:href => /http:\/\/test.host/}
    assert_match(/http:\/\/test.host\/projects\/#{@project.identifier}\/cards\/123/, @response.body)
    assert_card_included card1 
  end

  def test_can_render_revisions
    using_configured_subversion_for(@project) do |project|
      project.revisions.create(:identifier => '10', :number => 10, :commit_time => 2.minutes.ago.utc, :commit_message => 'This is a revision', :commit_user => 'revisionUser')
      HistoryGeneration.run_once
      get :index, :project_id => @project.identifier, :period => 'all_history'
    
      assert_tag :body, :content => /This is a revision/
    end  
  end

  def test_history_atom_feed_should_format_for_revision
    does_not_work_without_subversion_bindings do
      using_configured_subversion_for(@project) do |project|
        project.revisions.create(:identifier => '1', :number => 1, :commit_time => 2.minutes.ago.utc, :commit_message => 'This is a revision', :commit_user => 'revisionUser')
        HistoryGeneration.run_once
        get_history_atom
        assert_tag :tag => 'title', :content  => "Revision 1 committed by revisionUser"
      end  
    end
  end
  
  def test_history_atom_feed_show_last_limited_changes
    @controller.instance_eval do
      def history_atom_limit
        4
      end  
    end  
    card1 = create_card 1
    card2 = create_card 2
    card3 = create_card 3
    card4 = create_card 4
    HistoryGeneration.run_once
    get_history_atom(:page_size => 5)
    assert_card_included card1 
    
    card5 = nil
    perform_as('member@email.com') do
      card5 = create_card 5
    end
    HistoryGeneration.run_once
    get_history_atom(:page_size => 5)
    assert_card_included card5
    assert_card_not_included card1
  end
  
  def test_history_feeds_do_not_filter_by_period
    card1 = create_card 1
    HistoryGeneration.run_once
    get_history_atom
    assert_card_included card1
  end
  
  # bug 3032
  def test_html_injection_on_history_page
    using_configured_subversion_for(@project) do |project|
      project.revisions.create(:identifier => '10', :number => 10, :commit_time => 10.minutes.ago.utc, :commit_message => "<font style='color: red'> dddd", :commit_user => 'revisionUser')
      HistoryGeneration.run_once
      get :index, :project_id => @project.identifier, :period => 'all_history'    
      assert_select 'li', :html => /&lt;font style=&#39;color: red&#39;&gt; dddd/
    end  
  end 
  
  def test_render_with_filter_values
    card = create_card 1
    card.update_attributes :cp_old_type => 'card'
    HistoryGeneration.run_once
    get :index, :project_id => @project.identifier, :period => 'all_history', :involved_filter_properties => {"old_type" => "card", "feature" => nil}
    assert_response :success
    assert_card_included card
    get :index, :project_id => @project.identifier, :period => 'all_history', :involved_filter_properties => {"old_type" => "bug"}
    assert_response :success
    assert_card_not_included card
  end
  
  def test_filter_history_atom_feed
    card1 = create_card 1
    card1.update_attributes :cp_feature => 'email', :cp_status => 'open'    
    card2 = create_card 2
    HistoryGeneration.run_once
    get_history_atom
    assert_card_included card1
    assert_card_included card2
    get_history_atom :involved_filter_properties => {'feature' => 'email', 'status' => 'open'}
    assert_card_included card1
    assert_card_not_included card2
  end
  
  def test_history_atom_feed_should_format_for_card
    # version 1
    card = create_card 'My first card'
    # version 2
    card.update_attribute(:description, '<b>This is my first card</b>')
    # version 3
    card.update_attribute(:description, 'h3.This is my first card')
    # version 4
    card.tag_with('xxddss')    
    card.cp_status = 'new'
    card.cp_feature = 'atom' 

    card.save!
    #version5
    card.add_comment :content => "This is card commet"
    HistoryGeneration.run_once
    get_history_atom
    
    card_versions = @project.card_versions.find(:all, :conditions => "card_id = #{card.id}", :order => 'version')
    assert_equal 5, card_versions.size
    first_version = card_versions[0]
    second_version = card_versions[1]
    
    # assert card title : Card # [card_number | card_title | card_version | created/changed by user]
    assert_tag :tag  =>'title', :content => "Card ##{first_version.number} #{first_version.name} created by #{@member_user.name}"
    assert_tag :tag  =>'title', :content => "Card ##{second_version.number} #{second_version.name} changed by #{@member_user.name}"
    
    # assert card content html
    # I don't know why assert_tag cannot be used for content tag, so...
    
    assert @response.body.include?('&lt;b&gt;This is my first card&lt;/b&gt;')
    assert @response.body.include?('h3.This is my first card')

    # assert show card's tag as autom content
    assert_property_present('status','new')
    assert_property_present('feature','atom')
    assert_ungrouped_tag_present('xxddss')
    
    # assert comment
    assert @response.body.include?('This is card commet')
    
  end

  def test_rss_feeds_for_a_card_should_only_provide_events_for_that_card
    card_1 = create_card!(:name => 'quite unlike any other card')
    card_2 = create_card!(:name => 'quite like every other card')
    
    card_1.update_attributes(:description => 'cardy')
    card_1.update_attributes(:description => 'more cardy')

    card_2.update_attributes(:description => 'candy')
    
    HistoryGeneration.run_once

    get_history_atom(:card_number => card_1.number)
    assert_card_included card_1
    assert_card_not_included card_2
    assert_feed_size 3

    get_history_atom(:card_number => card_2.number)
    assert_card_included card_2
    assert_card_not_included card_1
    assert_feed_size 2
  end  

  def test_should_escape_html_for_content
     setup_property_definitions '<h1>status</h1>' => ['open', 'close']
     status = @project.find_property_definition('<h1>status</h1>')
     card = create_card!(:name => 'I am card')
     status.update_card(card, 'open')
     card.save!
     HistoryGeneration.run_once
     get :index, :project_id => @project.identifier, :period => 'all_history' 
     assert_select 'ul.change>li', :text => '&lt;h1&gt;status&lt;/h1&gt; set to open'
  end

  def test_history_atom_feed_should_format_for_page
    page = @project.pages.create!(:name =>"I am page name", :content => "<b>This is content</b>")
    page.update_attribute(:content ,'h2.This is the content with h2')
    
    page_versions = @project.page_versions.find_all_by_page_id(page.id,:order => 'version')
    first_version = page_versions[0]
    second_version = page_versions[1]
    
    HistoryGeneration.run_once
    get_history_atom
    
    # assert page title :Page [page_title] created/changed by [user]
    assert_tag :tag  =>'title', :content => "Page #{first_version.name} created by #{@member_user.name}"
    assert_tag :tag  =>'title', :content => "Page #{second_version.name} changed by #{@member_user.name}"
    
    # assert card content
    assert @response.body.include?('&lt;b&gt;This is content&lt;/b&gt;')
    assert @response.body.include?('h2.This is the content with h2')
  end

  def test_should_let_anonymous_access_plain_feed
    card = create_card!(:name => 'a new card')
    card.tag_with('first_tag')
    card.save!
    HistoryGeneration.run_once
    set_anonymous_access_for(@project, true)
    logout_as_nil
    change_license_to_allow_anonymous_access

    get :plain_feed, :format => "atom", :project_id => @project.identifier, :acquired_filter_tags => ['first_tag']
    assert_response :success
    assert !assigns['history'].empty?
  ensure
    set_anonymous_access_for(@project, false)
  end
  
  private
  def get_history_atom(options = {})
    encrypted_history_spec = @project.encrypt(HistoryFilterParams.new(options).serialize)
    get :feed, {:format => "atom", :project_id => @project.identifier, :encrypted_history_spec => encrypted_history_spec }

    assert_response :success
    assert_template 'index.atom.rxml'
    assert @response.headers['Content-Type'].include?("application/atom+xml")
  end
  
  def assert_property_present(property_def, value)
    assert @response.body.include?("#{property_def}:&amp;nbsp;#{value}")
  end
  
  def assert_ungrouped_tag_present(tag)
    assert @response.body =~ /content.*#{tag}.*\/content/m
  end

  def create_card(number)
    card =create_card!(:name => "card (#{number})")
    set_modified_time(card, 1, 2004, 1, 1, 10, 10, number)
    card
  end

  def assert_card_included(card)
    assert_match card.number.to_s, @response.body
    failure_message = "Cards updated at:" + @project.cards.map(&:updated_at).join(",") + @response.body
    begin
      assert @response.body.include?(card.name), failure_message
    rescue Exception => ex
      ActiveRecord::Base.logger.debug("Exception caught: #{__FILE__}:#{__LINE__}\n" + failure_message)
      raise ex
    end
    card.tags.each{|tag| assert @response.body.include?(tag.name)}
  end  
  
  def assert_card_not_included(card)
    assert !@response.body.include?(card.name)
  end

  def assert_feed_size(expected_size)
    actual = 0
    REXML::Document.new(@response.body).elements.each("//entry") {|e| actual += 1} #I am sure there is a smarter way of doing this
    assert_equal expected_size, actual
  end  

  def using_configured_subversion_for(project)
    driver = with_cached_repository_driver(name + '_setup') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
    end
    configure_subversion_for(project, {:repository_path => driver.repos_dir})
    yield project
  end  
end
