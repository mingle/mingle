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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')
class AtomFeedsEventApiTest < ActiveSupport::TestCase

#Tag: api_version_2
  fixtures :users, :login_access

  CARD_NAME = "api card"
  CARD_NEW_NAME = "new api card"
  CARD = "Card"
  STORY = "Story"
  STATUS = "status"

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'atom api', :admins => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_card_creation
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes("<title>Mingle Events for Project: #{@project.name}</title>", output)
    assert_response_includes(Mingle::API.ns, output)
    assert_response_includes('<change type="card-creation"/>', output)
    assert_equal(nil, get_element_text_by_xpath(output, "//content/changes/change[2]/old_value"))
    assert_equal(CARD, get_element_text_by_xpath(output, "//content/changes/change[2]/new_value/card_type/name"))
    assert_equal(nil, get_element_text_by_xpath(output, "//changes/change[3]/old_value"))
    assert_equal(CARD_NAME, get_element_text_by_xpath(output, "//content/changes/change[3]/new_value"))
  end

  def test_card_deletion
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      card.destroy
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-deletion" mingle_timestamp="', output)
    # assert_equal(CARD_NAME, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/number"))
    # assert_equal(CARD_NAME, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/name"))
  end

  def test_card_name_change
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      card.update_attributes(:name => CARD_NEW_NAME)
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="name-change" mingle_timestamp="', output)

    assert_equal(CARD_NAME, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal(CARD_NEW_NAME, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_card_description_change
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      card.update_attributes(:description => "new description api")
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="description-change" mingle_timestamp="', output)
  end

  def test_card_property_change
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      setup_property_definitions(:status => ['new', 'open'])
      card.update_attributes(:cp_status => 'new')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    puts output
    assert_response_includes('<change type="property-change" mingle_timestamp="', output)
    assert_equal(nil, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal("new", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_card_copy_to_between_projects_create
    User.find_by_login('admin').with_current do
      source_project = create_project(:name => "project 1")
      dest_project = create_project(:name => "project 2")

      source_project.activate
      source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name

      dest = source.copier(dest_project).copy_to_target_project
      proj1_feed_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{source_project.identifier}/feeds/events.xml"
      output = %x[curl -X GET #{proj1_feed_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('<change type="card-copied-to" mingle_timestamp="', output)
      assert_response_includes("Card #1 copied to #{dest_project.identifier}/#1", output)

      proj2_feed_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{dest_project.identifier}/feeds/events.xml"
      output = %x[curl -X GET #{proj2_feed_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('<change type="card-copied-from" mingle_timestamp="', output)
      assert_response_includes("Card #1 copied from #{source_project.identifier}/#1", output)
    end
  end

  def test_card_type_change
    User.find_by_login('admin').with_current do
      card_a = create_card!(:name => CARD_NAME, :card_type => CARD)
      @project.card_types.create(:name => STORY)
      card_a.update_attributes(:card_type_name => STORY)
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-type-change" mingle_timestamp="', output)
    assert_equal("Card", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value/card_type/name"))
    assert_equal("Story", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value/card_type/name"))
  end

  def test_tag_addition
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      card.tag_with("api tag").save!
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="tag-addition" mingle_timestamp="', output)
    assert_equal("api tag", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/tag"))
  end

  def test_tag_removal
    User.find_by_login('admin').with_current do
      card = create_card!(:name => CARD_NAME)
      card.tag_with("removed_tag").save!
      tag = card.reload.tags.find { |tag| tag.name == 'removed_tag' }
      tag.safe_delete
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="tag-removal" mingle_timestamp="', output)
    assert_equal("removed_tag", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/tag"))
  end

  def test_attachment_addition
    User.find_by_login('admin').with_current do
      attachment = "api.jpg"
      card = create_card!(:name => CARD_NAME, :attachments => [attachment])
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="attachment-addition" mingle_timestamp="', output)
    assert('<url>/attachments/api.jpg', output)
    assert_equal("api.jpg", get_element_text_by_xpath(output, "//entry/content/changes/change[2]/attachment/file_name"))
  end

  def test_attachment_deletion
    User.find_by_login('admin').with_current do
      card =create_card!(:name => CARD_NAME)
      card.attach_files(sample_attachment('api.txt'))
      card.save!
      card.remove_attachment(card.attachments.first.file_name)
      card.save!
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="attachment-removal" mingle_timestamp="', output)
    assert('<url>/attachments/api.txt', output)
    assert_equal("api.txt", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/attachment/file_name"))
  end

  def test_attachmment_replacement_with_same_filename
    User.find_by_login('admin').with_current do
      card =create_card!(:name => CARD_NAME)
      file_path = File.expand_path(Rails.root) + "/tmp/attachment.txt"

      create_or_modify_file_content(file_path, 'first line')
      attach_file_for(card, file_path)

      card.remove_attachment(card.attachments.first.file_name)

      create_or_modify_file_content(file_path, 'write some thing')
      attach_file_for(card, file_path)

      FileUtils.rm(file_path)
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="attachment-replacement" mingle_timestamp="', output)
    assert('<url>/attachments/attachment.txt', output)
    assert_equal("attachment.txt", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/attachment/file_name"))
  end

  def test_card_comment_addition
    User.find_by_login('admin').with_current do
      card =create_card!(:name => CARD_NAME)
      card.add_comment(:content => "api comment")
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="comment-addition" mingle_timestamp="', output)
    assert_equal("api comment", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/comment"))
  end

  def test_system_generated_comment
    User.find_by_login('admin').with_current do
      card =create_card!(:name => CARD_NAME)
      formula = setup_formula_property_definition('formula', '2 + 3')
      formula.update_all_cards
      formula.change_formula_to('2 + 4')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="system-comment-addition" mingle_timestamp="', output)
    assert_equal("formula changed from 2 + 3 to 2 + 4", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/comment"))
  end

  def test_repository_changes
    does_not_work_without_subversion_bindings do
      driver = with_cached_repository_driver(name + '_setup') do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      Repository.new(driver.repos_dir)

      repo_project = with_new_project(:name => 'repo api', :repository_path => driver.repos_dir) do |project|
        User.find_by_login('admin').with_current do
          create_card!(:name => CARD_NAME)
          driver.unless_initialized do |driver|
            driver.add_file('afile.txt', 'file content123')
            driver.commit "check in for card #1"
          end
          project.repository_configuration.plugin.update_attribute :initialized, true
        end
      end

      HistoryGeneration.run_once
      sleep(0.1)
      RevisionsHeaderCaching.run_once

      repo_feeds_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{repo_project.identifier}/feeds/events.xml"
      output = %x[curl -X GET #{repo_feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal("Revision 2 committed", get_element_text_by_xpath(output, "//entry[1]/title"))
      assert_equal("ice_user", get_element_text_by_xpath(output, "//entry[1]/author/name"))
      assert_equal("ice_user", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/changeset/user"))
      assert_equal("2", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/changeset/revision"))
      assert_equal("check in for card #1", get_element_text_by_xpath(output, "//entry[1]/content/changes/change/changeset/message"))
    end
  end

  # bug 10897
  def test_changeset_ordering_should_be_stable_after_version_control_name_addition
    does_not_work_without_subversion_bindings do

      new_user = User.create!(:name => 'committer', :login => 'committer', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD)

      driver = with_cached_repository_driver(name + '_setup') do |driver|
        driver.user = 'committer'
        driver.initialize_with_test_data_and_checkout
      end
      Repository.new(driver.repos_dir)

      repo_project = with_new_project(:name => 'repo api', :repository_path => driver.repos_dir) do |project|
        User.find_by_login('admin').with_current do
          create_card!(:name => CARD_NAME)
          driver.unless_initialized do |driver|
            driver.add_file('afile.txt', 'file content123')
            driver.commit "check in for card #1"
          end
          project.repository_configuration.plugin.update_attribute :initialized, true
          HistoryGeneration.run_once
          sleep(0.1)
          RevisionsHeaderCaching.run_once

          create_card!(:name => 'Last Card Created')
        end
      end

      repo_feeds_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{repo_project.identifier}/feeds/events.xml"
      output = %x[curl -X GET #{repo_feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal('Card #2 Last Card Created created', get_element_text_by_xpath(output, "//entry[1]/title"))

      new_user.update_attribute(:version_control_user_name, 'committer')
      HistoryGeneration.run_once
      sleep(0.1)
      RevisionsHeaderCaching.run_once

      repo_feeds_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{repo_project.identifier}/feeds/events.xml"
      output = %x[curl -X GET #{repo_feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal('Card #2 Last Card Created created', get_element_text_by_xpath(output, "//entry[1]/title"))
    end
  end

  # bug 10387
  def test_previous_and_next_link
    opts = {:host => site_uri_from_server.host, :port => site_uri_from_server.port, :user => nil}

    expected_current_url = feeds_url opts
    expected_self_url = feeds_url opts.merge(:query => "page=2")
    expected_previous_url = feeds_url opts.merge(:query => "page=3")

    User.find_by_login('admin').with_current do
      1.upto(51) { |i| create_card!(:name => "card_#{i}") }
    end

    output = %x[curl -X GET #{feeds_url :query => "page=2"} | xmllint --format -].tap { |output| raise "xml malformed!\n\n#{output}" unless $?.success? }
    current_url, self_url, previous_url = %w(current self previous).map do |rel|
      Nokogiri::XML(output).search("link[rel='#{rel}']").first["href"]
    end

    assert_equal expected_current_url, current_url
    assert_equal expected_self_url, self_url
    assert_equal expected_previous_url, previous_url
  end

  # bug 10902
  def test_urls_should_use_updated_project_identifier
    @project.with_active_project do |project|
      output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes(project.identifier, output)

      old_identifier = project.identifier
      new_identifier = 'new_name'
      User.find_by_login('admin').with_current do
        project.update_attribute(:identifier, new_identifier)
        project.update_attribute(:name, new_identifier)
      end
      output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes(new_identifier, output)
      assert_absent_in_response(old_identifier, output)
    end
  end

  protected

  def attach_file_for(card, file_path)
    file = uploaded_file(file_path)
    card.attach_files(file)
    card.save!
  end

  def create_or_modify_file_content(file_path, content)
    File.open(file_path, 'w') { |file| file << content }
  end

end
