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

require File.expand_path(File.dirname(__FILE__) + '/../curl_api_test_helper')

# Tags: objectives, api
class ObjectiveCurlAPITest < ActiveSupport::TestCase
  def setup
    enable_basic_auth
    login_as_admin
    @program = create_program
    @program.plan.update_attributes(:start_at => '2012-10-13', :end_at => '2012-11-25')
    @objective = @program.objectives.planned.create!(:name => 'first objective', :start_at => '2012-10-23', :end_at => '2012-11-15')
    @url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
  end

  def teardown
    disable_basic_auth
  end

  def test_get_objective_should_return_objective
    output = %x[curl -X GET #{@url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_equal @objective.identifier, get_element_text_by_xpath(output, "//objective/identifier/")
    assert_equal @objective.name, get_element_text_by_xpath(output, "//objective/name/")
    assert_equal @objective.start_at.to_s, get_element_text_by_xpath(output, "//objective/start_at/")
    assert_equal @objective.end_at.to_s, get_element_text_by_xpath(output, "//objective/end_at/")
  end

  def test_get_objective_should_return_objective_with_associated_cards
    with_new_project do |project|
      setup_property_definitions :status => %w[open closed]
      @program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'closed'}
      card1 = create_card!(:name => "story Card2")

      @program.plan.assign_card_to_objectives(project, card1, [@objective])

      @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')


      url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
      output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal(card1.number.to_s, get_element_text_by_xpath(output, "//objective/work/card/number"))
      assert_equal(@objective.works.first.completed.to_s, get_element_text_by_xpath(output, "//objective/work/card/completed").to_s)
      assert_equal("false", get_element_text_by_xpath(output, "//objective/work/card/completed"))
      assert_equal(@objective.number.to_s, get_element_text_by_xpath(output, "//objective/number"))

      card_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}/cards/#{card1.number}.xml"

      assert_equal(card_url, get_attribute_by_xpath(output, "//objective/work/card/@url"))
      assert_equal(project.identifier, get_element_text_by_xpath(output, "//objective/work/card/project/identifier"))
      project_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}.xml"
      assert_equal(project_url, get_attribute_by_xpath(output, "//objective/work/card/project/@url"))

      card1.update_properties('status' => 'closed')
      card1.save!
      output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal("true", get_element_text_by_xpath(output, "//objective/work/card/completed"))
    end
  end

  def test_get_objective_with_unauthorized_user_should_return_404
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml", :user => 'bob', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X GET #{url}].tap { raise "xml malformed!" unless $?.success? }
    assert_response_code(403, output)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
  end

  def test_get_objective_with_team_member_should_be_successful
    member = User.find_by_login('member')
    @program.add_member(member)

    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml", :user => 'member', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X GET #{url}].tap { raise "xml malformed!" unless $?.success? }
    assert_response_code(200, output)
  end

  def test_list_objectives
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml"
    output = %x[curl -i -X GET #{url}].tap { raise "xml malformed!" unless $?.success? }

    assert_response_code(200, output)

    assert_equal @objective.identifier, get_element_text_by_xpath(output, "//objectives/objective/identifier/")
    assert_equal @objective.name, get_element_text_by_xpath(output, "//objectives/objective/name/")
    assert_equal @objective.start_at.to_s, get_element_text_by_xpath(output, "//objectives/objective/start_at/")
    assert_equal @objective.end_at.to_s, get_element_text_by_xpath(output, "//objectives/objective/end_at/")
    assert_equal 0, get_number_of_elements(output, "//objectives/objective/work/")

    objective_url = "http://localhost:#{MINGLE_PORT}/api/v2/programs/#{@program.identifier}/plan/objectives/#{@objective.identifier}.xml"
    assert_equal objective_url, get_attribute_by_xpath(output, "//objectives/objective/@url")
  end

  def test_list_objectives_with_unauthorized_user_should_return_404
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml", :user => 'bob', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X GET #{url}].tap { raise "xml malformed!" unless $?.success? }
    assert_response_code(403, output)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
  end

  def test_list_objectives_with_team_member_should_be_successful
    member = User.find_by_login('member')
    @program.add_member(member)

    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml", :user => 'member', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X GET #{url}].tap { raise "xml malformed!" unless $?.success? }
    assert_response_code(200, output)
  end

  def test_update_objective
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
    new_name = "changed objective"

    new_start_date = @program.plan.start_at
    new_end_date = @program.plan.end_at

    output = %x[curl -i -X PUT -d "objective[name]=#{new_name}" -d "objective[start_at]=#{new_start_date}" -d "objective[end_at]=#{new_end_date}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_response_code(200, output)
    assert_equal new_name, @objective.reload.name
    assert_equal new_start_date, @objective.start_at
    assert_equal new_end_date, @objective.end_at

    assert_equal @objective.identifier, get_element_text_by_xpath(output, "//objective/identifier/")
    assert_equal @objective.name, get_element_text_by_xpath(output, "//objective/name/")
    assert_equal @objective.start_at.to_s, get_element_text_by_xpath(output, "//objective/start_at/")
    assert_equal @objective.end_at.to_s, get_element_text_by_xpath(output, "//objective/end_at/")

    event_url = base_api_url_for "programs", @program.identifier, "plan", "feeds", "events.xml"
    puts event_url
    output = %x[curl -i -X GET #{event_url}]
    assert_response_code(200, output)
    assert_equal [new_name, '2012-11-15'], get_elements_text_by_xpath(output, "//changes/change[2]/new_value")
    assert_equal ['first objective', nil], get_elements_text_by_xpath(output,"//changes/change[2]/old_value")
  end

  #Check regression for #14313
  def test_should_be_able_to_update_without_name
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
    new_start_date = @program.plan.start_at
    output = %x[curl -i -X PUT -d "objective[start_at]=#{new_start_date}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code 200, output
    assert_match /<start_at.*#{new_start_date}<\/start_at\>/, output
  end

  def test_update_objective_should_fail_for_incorrect_parameters
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
    new_name = "changed objective"

    old_start_date = @objective.start_at
    new_start_date = @program.plan.start_at

    output = %x[curl -i -X PUT -d "objective[start_date]=#{new_start_date}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_response_code(422, output)
    assert_equal old_start_date, @objective.reload.start_at
    assert_response_includes('Invalid parameter\(s\) provided: start_date', output)
  end

  def test_update_objective_should_fail_for_invalid_values
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"

    old_start_date = @objective.start_at

    output = %x[curl -i -X PUT -d "objective[start_at]=invalid date" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_response_code(422, output)
    assert_equal old_start_date, @objective.reload.start_at
    assert_response_includes("The parameter 'start_at' was in an incorrect format. Please use 'yyyy-mm-dd'.", output)
  end

  def test_update_objective_should_fail_for_duplicate_name
    @program.objectives.planned.create!(:name => 'second objective', :start_at => '2012-10-23', :end_at => '2012-11-15')
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
    duplicate_name = "second objective"
    old_name = @objective.name

    output = %x[curl -i -X PUT -d "objective[name]=#{duplicate_name}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_response_code(422, output)
    assert_equal old_name, @objective.reload.name
    assert_response_includes('Name already used for an existing Feature.', output)
  end

  def test_update_objective_should_allow_for_dates_beyond_plan
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"

    new_start_date = '2012-10-10'
    new_end_date = '2012-11-30'

    output = %x[curl -i -X PUT -d "objective[start_at]=#{new_start_date}" -d "objective[end_at]=#{new_end_date}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_equal new_start_date, @objective.reload.start_at.to_s
    assert_equal new_end_date, @objective.end_at.to_s

    assert_equal '2012-10-08', @objective.program.plan.reload.start_at.to_s # plan gets adjusted to previous monday
    assert_equal '2012-12-02', @objective.program.plan.end_at.to_s # plan gets adjusted to next sunday
  end

  def test_update_objective_should_validate_end_date_greater_than_start_date
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml"
    output = %x[curl -i -X PUT  -d "objective[end_at]= '2012-10-22'" #{url}].tap do
       raise "xml malformed!" unless $?.success?
     end
     assert_response_code(422, output)
     assert_response_includes('End date should be after start date', output)
  end

  def test_update_objective_with_unauthorized_user_should_return_404
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml", :user => 'bob', :password => MINGLE_TEST_DEFAULT_PASSWORD
    new_name = "changed objective"
    output = %x[curl -i -X PUT -d "objective[name]=#{new_name}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(403, output)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
  end

  def test_update_objective_with_team_member_should_be_successful
    member = User.find_by_login('member')
    @program.add_member(member)

    new_name = "changed objective"
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{@objective.identifier}.xml", :user => 'member', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X PUT -d "objective[name]=#{new_name}" #{url}].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(200, output)
    assert_equal new_name, @objective.reload.name
  end

  def test_create_objective
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml"

    output = %x[curl -i -X POST  #{url} -d "objective[name]=created from api" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(200, output)

    @objective = Objective.find_by_identifier('created_from_api')
    assert_equal @objective.identifier, get_element_text_by_xpath(output, "//objective/identifier/")
    assert_equal @objective.name, get_element_text_by_xpath(output, "//objective/name/")
    assert_equal @objective.start_at.to_s, get_element_text_by_xpath(output, "//objective/start_at/")
    assert_equal @objective.end_at.to_s, get_element_text_by_xpath(output, "//objective/end_at/")
  end

  def test_create_objective_should_throw_error_if_objective_name_is_taken
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml"

    output = %x[curl -i -X POST  #{url} -d "objective[name]=#{@objective.name}" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(422, output)
    assert_response_includes('Name already used for an existing Feature.', output)
  end

  def test_create_objective_should_fail_for_incorrect_parameters
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml"

    output = %x[curl -i -X POST  #{url} -d "objective[name]=invalid objective" -d "objective[start_date]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end

    assert_response_code(422, output)
    assert_response_includes('Invalid parameter\(s\) provided: start_date', output)
  end

  def test_create_objective_with_unauthorized_user_should_return_404
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml", :user => 'bob', :password => MINGLE_TEST_DEFAULT_PASSWORD
    output = %x[curl -i -X POST  #{url} -d "objective[name]=objective" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(403, output)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
  end

  def test_create_objective_with_team_member_should_be_successful
    member = User.find_by_login('member')
    @program.add_member(member)

    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml", :user => 'member', :password => MINGLE_TEST_DEFAULT_PASSWORD

    output = %x[curl -i -X POST  #{url} -d "objective[name]=objective" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(200, output)
    @objective = Objective.find_by_identifier('objective')
    assert_equal @objective.identifier, get_element_text_by_xpath(output, "//objective/identifier/")
    assert_equal @objective.name, get_element_text_by_xpath(output, "//objective/name/")
    assert_equal @objective.start_at.to_s, get_element_text_by_xpath(output, "//objective/start_at/")
    assert_equal @objective.end_at.to_s, get_element_text_by_xpath(output, "//objective/end_at/")
  end

  def test_create_objective_gets_correct_position
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives.xml"

    output = %x[curl -i -X POST  #{url} -d "objective[name]=first api objective" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(200, output)

    output = %x[curl -i -X POST  #{url} -d "objective[name]=second api objective" -d "objective[start_at]=2012-10-24" -d "objective[end_at]=2012-11-05" ].tap do
      raise "xml malformed!" unless $?.success?
    end
    assert_response_code(200, output)

    first_objective = @program.objectives.planned.find_by_identifier('first_api_objective')
    second_objective = @program.objectives.planned.find_by_identifier('second_api_objective')

    assert_not_equal first_objective.vertical_position, second_objective.vertical_position
  end

  def test_delete_should_delete_an_objective_and_create_event_feed
    objective = @program.objectives.planned.create!(:name => 'objective2', :start_at => '2012-10-23', :end_at => '2012-11-15')
    url = base_api_url_for "programs", @program.identifier, "plan", "objectives", "#{objective.identifier}.xml"
    output = %x[curl -i -X DELETE #{url}]
    assert_response_code(200, output)
    assert_nil @program.objectives.planned.find_by_identifier(objective.identifier)

    event_url = base_api_url_for "programs", @program.identifier, "plan", "feeds", "events.xml"
    output = %x[curl -i -X GET #{event_url}]
    assert_response_includes('<change type="objective-removed" mingle_timestamp="', output)
    assert_response_includes('<title>Feature removed</title>', output)

  end

  def test_objective_event_feeds
    event_url = base_api_url_for "programs", @program.identifier, "plan", "feeds", "events.xml"
    output = %x[curl -i -X GET #{event_url}]
    assert_response_code(200, output)
    assert_equal ["Mingle Plan Events for Program: #{@program.identifier}", "Feature planned"], get_elements_text_by_xpath(output, "//title/")
  end


  def test_random_xml_request_gives_404_with_error_xml
    output = %x[curl -X GET #{base_api_url_for("invalid.xml")}].tap { raise "xml malformed!" unless $?.success? }
    assert_equal IO.read("#{Rails.root}/public/404.xml").strip, output.strip
  end
end
