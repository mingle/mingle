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
require "rexml/document"

# Tags: api, wiki
class WikiCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld') do |project|
        3.times do |index|
          project.pages.create(:name => "hello #{index}", :content => "welcome")
        end
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_error_message_when_delete_attachment_for_page_use_old_api_format
    create_wiki_by_api
    url = basic_auth_url_for "/projects", @project.identifier, "wiki", "new_wiki", "attachments", "not_exist.jpg"
    output = %x[curl -i -X DELETE "#{url}"]
    assert_response_code(410, output)
    assert_include('<message>The resource URL has changed. Please use the correct URL.</message>', output)
  end

  def test_to_create_wiki
    page = create_wiki_by_api
    assert_not_nil page
    assert_equal 'new wiki', page.name
  end

  def test_to_create_wiki_by_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = wiki_list_url :user => login, :password => password
    output = %x[curl -X POST -i -d "page[name]=new wiki&page[content]=welcome" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_to_create_wiki_by_anon_user
    User.find_by_login('admin').with_current do
      @project.update_attribute :anonymous_accessible, true
      @project.save
    end
    change_license_to_allow_anonymous_access

    url = wiki_list_url :user => nil
    output = %x[curl -X POST -i -d "page[name]=new wiki&page[content]=welcome" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_to_create_wiki_with_duplicate_name
    create_wiki_by_api
    url = wiki_list_url
    output = %x[curl -X POST -i -d "page[name]=new wiki&page[content]=welcome" #{url}]
    assert_response_code(422, output) #status code 422 = correct command but cannot process
    assert_not_include '<html>', output
  end

  def test_to_create_wiki_with_wrong_url
    url = project_base_url_for "wikiekvjoeijweqwerbejejejjjjeeeqq.xml"
    output = %x[curl -X POST -i -d "page[name]=new wiki&page[content]=welcome" #{url}]
    assert_response_code(404, output)

    assert_not_include '<html>', output
    assert_not_include '<head>', output
    assert_not_include '<body>', output
  end

  def test_to_view_single_wiki_page
    url = wiki_url_for create_wiki_by_api
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<content>welcome<\/content>/ && /<name>new wiki<\/name>/, "Cannot view expected page."
  end

  # bug 10134
  def test_to_view_overview_wiki_page
    create_wiki_by_api('Overview_Page', 'overview page')
    page = Page.find_by_identifier("Overview_Page")
    url = wiki_url_for page
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<content>overview page<\/content>/ && /<name>Overview Page<\/name>/, "Cannot view expected page."
  end

  def test_to_view_all_wiki_pages
    url = wiki_list_url
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<content>welcome<\/content>/ && /<name>hello 0<\/name>/ && /<name>hello 1<\/name>/ && /<name>hello 2<\/name>/, "Cannot view expected page."
  end

  def test_to_all_wiki_pages_by_anon_user
    User.find_by_login('admin').with_current do
      @project.update_attribute :anonymous_accessible, true
      @project.save
    end
    change_license_to_allow_anonymous_access

    url = wiki_list_url
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<content>welcome<\/content>/ && /<name>hello 0<\/name>/ && /<name>hello 1<\/name>/ && /<name>hello 2<\/name>/, "Cannot view expected page."
  end

  def test_to_view_all_wiki_pages_by_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = wiki_list_url :user => login, :password => password
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<content>welcome<\/content>/ && /<name>hello 0<\/name>/ && /<name>hello 1<\/name>/ && /<name>hello 2<\/name>/, "Cannot view expected page."
  end

  def test_to_update_wiki_by_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)
    page = @project.pages.first
    url = wiki_url_for page, :user => login, :password => password
    output = %x[curl -X PUT -i -d "page[content]=I want to write something" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_to_update_wiki_with_wrong_url
    url = project_base_url_for "wiki", "e_kvjoeijweqwerbejejejjjjeeeqq.xml"
    output = %x[curl -X PUT -i -d "page[content]=hey let me write something!" #{url}]
    assert_response_code(404, output)

    assert_not_include '<html>', output
  end

  def test_to_update_wiki_by_pointing_old_version
    page = @project.pages.first
    url = wiki_url_for page
    output = %x[curl -X PUT -i -d "page[content]=welcome to something_else!" #{url}]
    assert output =~ /welcome to something_else!/ && />2<\/version>/

    url = wiki_url_for page, :query => "version=1"
    output = %x[curl -X PUT -i -d "page[content]=hey let me write something!" #{url}]
    assert output =~ /hey let me write something!/ && />3<\/version>/
  end

  def test_to_update_wiki_page_with_long_command_line
    url = wiki_url_for @project.pages.first
    output = %x[curl -X PUT -i -d "page[content]={{
      pie-chart
        data: SELECT priority, count(*) WHERE type = story
    }}

    {{
      stack-bar-chart
        conditions:
        labels: SELECT DISTINCT status
        cumulative: true
        series:
        - label: Series 1
          color: green
          type: bar
          data: SELECT status, count(*) WHERE priority = high
          combine: overlay-bottom
        - label: Series 2
          color: blue
          type: bar
          data: SELECT status, count(*) WHERE priority = medium
          combine: overlay-bottom
    }}

    {{
      ratio-bar-chart
        totals: SELECT status, count(*) WHERE priority = high
        restrict-ratio-with: type = story
    }}

    {{
     data-series-chart
        conditions: type = story
        cumulative: true
        x-labels-start:
        x-labels-end:
        x-labels-step:
        series:
        - label: Series 1
          color: black
          type: line
          data: SELECT status, count(*) WHERE priority = high
          trend: true
          trend-line-width: 2
        - label: Series 2
          color: green
          type: line
          data: SELECT status, count(*) WHERE priority = medium
          trend: true
          trend-line-width: 2
    }}" #{url}]
    assert output =~ /data-series-chart/ && /ratio-bar-chart/ && /pie-chart/, output
  end

  def create_wiki_by_api(name="new wiki", content="welcome")
    url = wiki_list_url
    output = %x[curl -X POST -i -d "page[name]=#{name}&page[content]=#{content}" #{url}]
    assert_response_code(201, output) #status code 201 = created
    Page.find_by_name(name)
  end

end
