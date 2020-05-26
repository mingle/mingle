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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class ProgramFeedsControllerTest < ActionController::TestCase
  NOT_EMPTY = /.+/
  URI_FORMAT = /^((urn:uuid:.*)|(http|https):\/\/.*)/
  OBJECTIVE_LINK_FORMAT = /^((http|https):\/\/.*)\/api\/.*\/programs\/.*\/plan\/objectives\/.*.xml$/
  RFC3339_DATE_FORMAT = /[0-9\-]{8}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-][0-9]{2}:[0-9]{2})/
  EMAIL_FORMAT = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

  def setup
    login_as_admin
    @controller = ProgramFeedsController.new
    @program = create_program
  end

  def test_should_generate_valid_feed_structure
    @program.objectives.planned.create!(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    get :events, :program_id => @program.identifier, :api_version => 'v2', :format => 'xml', :page => 1
    assert_response :success

    assert_select 'body', :count => 0 # should not use layout

    assert_select 'feed', :count => 1 do
      assert_select "[xmlns=?]", "http://www.w3.org/2005/Atom"
      assert_select "[xmlns:mingle=?]", Mingle::API.ns
    end

    assert_select 'feed title', NOT_EMPTY

    assert_select 'feed link[rel=self]', :count => 1 do
      assert_select "[href=?]", URI_FORMAT
    end

    assert_select 'feed link[rel=current]', :count => 1 do
      assert_select "[href=?]", URI_FORMAT
    end

    assert_select 'feed updated', RFC3339_DATE_FORMAT
    assert_select 'feed id', URI_FORMAT, :count => 1

    assert_select 'feed entry' do |entries|
      assert_equal @program.objectives.count, entries.count
      entries.each do |entry|
        assert_select entry, 'title', NOT_EMPTY, :count => 1
        assert_select entry, "category[scheme=#{Mingle::API.ns('categories')}][term=?]", NOT_EMPTY
        assert_select entry, 'id', URI_FORMAT, :count => 1
        assert_select entry, 'author', :count => 1 do |author|
          assert_select author.first, 'name', NOT_EMPTY, :count => 1
          assert_select author.first, 'email', EMAIL_FORMAT, :count => 1
          assert_select author.first, 'uri', URI_FORMAT, :count => 1
        end
        assert_select entry, 'updated', RFC3339_DATE_FORMAT, :count => 1
        
        assert_select entry, 'content[type=application/vnd.mingle+xml]', NOT_EMPTY, :count => 1
        assert_select entry, 'link[href=?]', OBJECTIVE_LINK_FORMAT, :count => 1
      end
    end

    assert_content_uniq 'feed entry id'
  end

  private

  def assert_content_uniq(selector)
    assert_select selector do |elements|
      assert_unique elements.collect { |element| element.children.first.content }
    end
  end

  def assert_unique(collection)
    assert_equal collection.size, collection.uniq.size, "#{collection.inspect} is not uniq"    
  end

end
