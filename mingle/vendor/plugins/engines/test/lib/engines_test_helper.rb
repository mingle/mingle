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

module TestHelper
  def self.report_location(path)
    [RAILS_ROOT + '/', 'vendor/plugins/'].each { |part| path.sub! part, ''}
    path = path.split('/')
    location, subject = path.first, path.last
    if subject.sub! '.rb', ''
      subject = subject.classify
    else 
      subject.sub! '.html.erb', ''
    end
    "#{subject} (from #{location})"
  end
  
  def self.view_path_for path
    [RAILS_ROOT + '/', 'vendor/plugins/', '.html.erb'].each { |part| path.sub! part, ''}
    parts = path.split('/')
    parts[(parts.index('views')+1)..-1].join('/')
  end
end

class Test::Unit::TestCase
  # Add more helper methods to be used by all tests here...  
  def get_action_on_controller(*args)
    action = args.shift
    with_controller *args
    get action
  end
  
  def with_controller(controller, namespace = nil)
    classname = controller.to_s.classify + 'Controller'
    classname = namespace.to_s.classify + '::' + classname unless namespace.nil?
    @controller = classname.constantize.new
  end
  
  def assert_response_body(expected)
    assert_equal expected, @response.body
  end
end

# Because we're testing this behaviour, we actually want these features on!
Engines.disable_application_view_loading = false
Engines.disable_application_code_loading = false
