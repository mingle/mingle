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

require File.expand_path(File.dirname(__FILE__) + '/../../app/helpers/help_doc_helper')
require 'test/unit'
class BrokenHelpLinksFromTheAppTest < Test::Unit::TestCase

  def test_broken_links
    links = HelpDocHelper::PAGES.merge(HelpDocHelper::COMPONENTS.merge(HelpDocHelper::SPECIALS))
    existing_help_topic_files = Dir["#{File.expand_path(File.dirname(__FILE__))}/../../help/topics/*.xml"]
    help_files_that_get_created_from_help_topics = existing_help_topic_files.collect { |fname| fname.gsub(/^(.*)\/([^\/]*)\.xml$/, '/\2.html') }
    linked_pages = links.values.collect { |link| link.include?('#') ?  /(.*)\#/.match(link)[1] : link }
    assert_equal ['/index.html'], (linked_pages - help_files_that_get_created_from_help_topics)
  end

end
