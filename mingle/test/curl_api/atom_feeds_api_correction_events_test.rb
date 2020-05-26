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
class AtomFeedsApiCorrectionTest < ActiveSupport::TestCase

#Tag: api_version_2
  fixtures :users, :login_access

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

  def test_managed_property_value_rename
    User.find_by_login('admin').with_current do
      managed_number = setup_managed_number_list_definitions('size' => ['1'])
      enumeration_value = @project.find_enumeration_value('size', '1')
      enumeration_value.update_attributes(:value => '7')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_response_includes('<change type="managed-property-value-change" mingle_timestamp="', output)

    assert_equal('1', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal('7', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_property_rename
    User.find_by_login('admin').with_current do
      date_property = create_date_property('start date')
      date_property.update_attributes(:name => 'end date')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="property-rename" mingle_timestamp="', output)

    assert_equal('start date', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal('end date', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_property_deletion
    User.find_by_login('admin').with_current do
      formula_property = create_formula_property("formula", '2+1')
      formula_property.destroy
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="property-deletion" mingle_timestamp="', output)
  end

  def test_disassociate_property_from_card_type
    User.find_by_login('admin').with_current do
      team_property = setup_user_definition("owner")
      card_type = @project.card_types.first
      card_type.property_definitions = card_type.property_definitions - [team_property]
      card_type.save!
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-type-and-property-disassociation" mingle_timestamp="', output)
    assert_response_includes(%{<property_definition url="http://#{Socket.gethostname}}, output)
    assert_response_includes(%{<card_type url="http://#{Socket.gethostname}}, output)
  end

  def test_card_type_rename
    User.find_by_login('admin').with_current do
      release_card = @project.card_types.create!(:name => 'Release')
      release_card.update_attributes(:name => 'Updated Release')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-type-rename" mingle_timestamp="', output)
    assert_response_includes(%{<card_type url="http://#{Socket.gethostname}}, output)

    assert_equal('Release', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal('Updated Release', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_card_type_deletion
    User.find_by_login('admin').with_current do
      release_card = @project.card_types.create!(:name => 'Release')
      release_card.destroy
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-type-deletion" mingle_timestamp="', output)
    assert_response_includes(%{<card_type url="http://#{Socket.gethostname}}, output)
  end

  def test_tag_rename
    User.find_by_login('admin').with_current do
      tag = @project.tags.find_or_create_by_name('tag')
      tag.update_attribute(:name, "tag renamed")
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="tag-rename" mingle_timestamp="', output)

    assert_equal('tag', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal('tag renamed', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_repository_deletion
    does_not_work_without_subversion_bindings do
      login_as_admin
      @repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
      end

      SubversionConfiguration.create!(:project_id => @project.id, :repository_path => @repos_driver.repos_dir)

      @project.reload
      RevisionsHeaderCaching.run_once

      @project.delete_repository_configuration
      RevisionsHeaderCaching.run_once

      output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('<change type="repository-settings-change" mingle_timestamp="', output)
    end
  end

  def test_numeric_precision_change
    old_precision = @project.precision.to_s
    new_precision = "4"

    User.find_by_login('admin').with_current do
      @project.update_attribute(:precision, new_precision)
    end

    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="numeric-precision-change" mingle_timestamp="', output)

    assert_equal(old_precision, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal(new_precision, get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

  def test_card_keyword_addition_deletion
    User.find_by_login('admin').with_current do
      @project.update_attribute(:card_keywords, 'key')
    end
    output = %x[curl -X GET #{feeds_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<change type="card-keywords-change" mingle_timestamp="', output)

    assert_equal('card, #', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/old_value"))
    assert_equal('key', get_element_text_by_xpath(output, "//entry[1]/content/changes/change/new_value"))
  end

end
