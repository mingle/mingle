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

#This patch is needed to get import_export_test.rb -n test_can_import_template_into_projects_that_keeps_cards_and_pages to work
#without throwing an exception while updating the message on an asynch request
#This is the final patch for this issue: https://rails.lighthouseapp.com/projects/8994/tickets/3608

module ActiveSupport
  # Hash is ordered in Ruby 1.9!
  if MingleUpgradeHelper.ruby_1_9?
    class OrderedHash < ::Hash #:nodoc:
      #backported from 3.2.22.1 to get to get OrderedHash.to_yaml working
      def encode_with(coder)
        coder.represent_seq '!omap', map { |k,v| { k => v } }
      end
    end
  else
    class OrderedHash < Hash #:nodoc:
      def to_yaml_type
        "!tag:yaml.org,2002:omap"
      end

      def to_yaml(opts = {})
        YAML.quick_emit(self, opts) do |out|
          out.seq(taguri, to_yaml_style) do |seq|
            each do |k, v|
              seq.add(k => v)
            end
          end
        end
      end
    end

    #The original patch contains the following lines, but they break in JRuby.
    #The test that fails runs without these lines, but they cause test/unit/xml_serializer_test.rb
    #to fail. So I have commented them out.
    # YAML.add_builtin_type("omap") do |type, val|
    #   ActiveSupport::OrderedHash[val.map(&:to_a).map(&:first)]
    # end
  end
end
