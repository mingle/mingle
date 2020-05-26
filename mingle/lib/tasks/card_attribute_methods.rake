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

namespace :card do
  desc "generate card class default attribute methods"
  task :generate => :environment do
    $default_attribute_methods = []
    User.with_first_admin do
      id = 'attribute_methods'.uniquify
      Project.create!(:identifier => id, :name => id).with_active_project do |project|
        c = project.cards.create(:number => 1, :name => 'card', :card_type_name => 'Card')
        cc = c.class
        cc.instance_eval do
          def generated_methods?
            false
          end

          def evaluate_attribute_method(attr_name, method_definition, method_name=attr_name)
            $default_attribute_methods << method_definition.gsub(/ConnectionAdapters\:\:\w+Column/, "ConnectionAdapters\:\:Column")
          end
        end
        Card::DefaultAttributeMethods.instance_methods.each do |m|
          cc.send(:undef_method, m)
        end
        cc.reset_column_information
        c = cc.create(:number => 2, :name => 'card2', :card_type_name => 'Card')
        c.project_id
      end
    end
    $default_attribute_methods << "def id; (v=@attributes['id']) && (v.to_i rescue v ? 1 : 0); end"
    puts "[DEBUG] $default_attribute_methods.size => #{$default_attribute_methods.size.inspect}"
    
    File.open(File.join(Rails.root, 'app/models/card/default_attribute_methods.rb'), 'w') do |io|
      io.write(<<-RUBY)
# DO NOT MODIFY THIS FILE, IT IS GENEREATED FROM card_attribute_methods.rake
class Card
  module DefaultAttributeMethods
    #{$default_attribute_methods.uniq.join("\n    ")}
  end
end
RUBY
    end
  end
end
