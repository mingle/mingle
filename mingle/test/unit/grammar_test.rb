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

class GrammarTest < ActiveSupport::TestCase
  
  def test_can_not_as_two_words_should_not_be_used
    if not_windows?
      ruby_folders_to_check = %w(app lib).map { |name| %Q|"#{File.join(Rails.root, name)}"| }.join(' ')
      check_can_not_cmd = %Q{ find #{ruby_folders_to_check} -name "*.rb" | xargs grep -inH "can not" }
      assert_equal false, system(check_can_not_cmd)
      
      help_doc_folder_to_check = File.join(Rails.root, 'help', 'topics')
      check_can_not_cmd = %Q{ find "#{help_doc_folder_to_check}" -name "*.xml" | xargs grep -inH "can not" }
      assert_equal false, system(check_can_not_cmd)
    end
  end
  
  protected
  
  def not_windows?
    not (Config::CONFIG['host_os'] =~ /mswin32/i || Config::CONFIG['host_os'] =~ /Windows/i)
  end
  
end
