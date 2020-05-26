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

require File.expand_path(File.dirname(__FILE__) + '/../../acceptance_test_helper')
require File.expand_path("api_url_test_helper", File.dirname(__FILE__))

require 'active_resource'
require 'net/http'
require 'uri'

class ActiveSupport::TestCase

  teardown :clear_project_cache

  def clear_project_cache
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=ProjectCacheFacade.instance&method=clear")
  rescue Exception => e
    puts message = <<-EOS
      Clear project cache failed.
        Exception: #{e}
        Message  : #{e.message}
        Trace    : #{e.backtrace.join("\n")}
    EOS
    ActiveRecord::Base.logger.debug(message)
  end

  def enable_basic_auth
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=AuthConfiguration&method=enable_basic_authentication&basic_auth_enabled=true")
  end

  def with_saas_env_set(&block)
    set_saas_env
    yield if block_given?
    unset_saas_env
  end

  def set_saas_env
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=MingleConfiguration&method=override_configs&saas_env=true")
  end

  def unset_saas_env
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=MingleConfiguration&method=override_configs&saas_env=false")
  end

  def disable_basic_auth
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=AuthConfiguration&method=enable_basic_authentication&basic_auth_enabled=false")
  end

  def fake_clock(year, month, day, hour=12)
    Net::HTTP.get URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/_class_method_call?class=Clock&method=fake_now&year=#{year}&month=#{month}&day=#{day}&hour=#{hour}")
  end

  def assert_unauthorized(&block)
    e = assert_raise(ActiveResource::UnauthorizedAccess, &block)
    assert_equal '401', e.response.code
    e
  end

  def assert_forbidden(&block)
    e = assert_raise(ActiveResource::ForbiddenAccess, &block)
    assert_equal '403', e.response.code
    e
  end

  def assert_not_found(&block)
    e = assert_raise(ActiveResource::ResourceNotFound, &block)
    assert_equal '404', e.response.code
    e
  end

  def assert_server_error(&block)
    e = assert_raise(ActiveResource::ServerError, &block)
    assert_equal '500', e.response.code
    e
  end

  def get(url, params)
    make_request(Net::HTTP::Get, url, params)
  end

  def put(url, params)
    make_request(Net::HTTP::Put, url, params)
  end

  def post(url, params)
    make_request(Net::HTTP::Post, url, params)
  end

  def delete(url)
    make_request(Net::HTTP::Delete, url, {})
  end

  def follow_link_to_created_resource(response)
    get(response.header["location"].gsub(/http:\/\//, "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@"), {})
  end

  def make_request(klass, url, params)
    url = URI.parse(url) unless url.respond_to?(:path)

    request = klass.new(url.request_uri)
    request.form_data = params
    request.basic_auth url.user, url.password if url.user
    Net::HTTP.new(url.host, url.port).start { |http| http.request(request) }
  end

  def post_json(url, params)
    make_json_request(Net::HTTP::Post, url, params)
  end

  def make_json_request(klass, url, params)
    url = URI.parse(url) unless url.respond_to?(:path)

    request = klass.new(url.request_uri)
    request.basic_auth url.user, url.password if url.user
    request.body = params.to_json
    request['Content-Type'] ='application/json'

    response = Net::HTTP.new(url.host, url.port).start { |http|
      http.request(request)
    }
  end

end

ActiveResource::Base.logger = ActiveRecord::Base.logger

module API
  class Card < ActiveResource::Base
    class << self
      def reset_user_and_password_cache
        @user = nil
        @password = nil
      end
    end
  end
  class Murmur < ActiveResource::Base
  end

  class Comment < ActiveResource::Base
  end

  class Page < ActiveResource::Base
    self.collection_name = 'wiki'
  end

  class PerforceConfiguration < ActiveResource::Base
  end

  class SubversionConfiguration < ActiveResource::Base
  end

  class HgConfiguration < ActiveResource::Base
  end

  class GitConfiguration < ActiveResource::Base
  end

  class Project < ActiveResource::Base
  end

  class CardType < ActiveResource::Base
  end

  class CardListView < ActiveResource::Base
  end

  class PropertyDefinition < ActiveResource::Base
  end

  class TransitionExecution < ActiveResource::Base
  end

  class User < ActiveResource::Base
  end

  class Favorite < ActiveResource::Base
  end

  class Transition < ActiveResource::Base
  end
end


def run_it(common_tests_file)
  # Dollar-Zero denotes the ruby file being run
  if File.basename(common_tests_file) == File.basename($0)
    puts "*** Running all versions of the file #{File.basename($0)} ***"
    current_filename = File.basename(common_tests_file)
    including_class_name_prefix = current_filename.scan(/(.+)_common_tests.rb/).to_s
    Dir[File.join(File.dirname(common_tests_file), "**", "#{including_class_name_prefix}*_test.rb")].uniq.each do |path|
      require path
    end
  end
end
