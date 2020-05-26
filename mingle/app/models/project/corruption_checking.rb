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

class Project
  module CorruptionChecking
    
    class NormalPropertyDefinitionCorruption
      def initialize(prop_def)
        @prop_def = prop_def
      end
      
      def render
        "Property <%= link_to '#{@prop_def.name.bold}', property_definitions_list_url, :title => 'click to go to card properties page to delete' %> is corrupt. You can rectify this issue by deleting this property."
      end
    end
    
    class AggregatePropertyDefinitionCorruption
      def initialize(prop_def)
        @prop_def = prop_def
      end
      
      def render
        "Property <%= link_to '#{@prop_def.name.bold}', edit_aggregate_properties_url(:id => #{@prop_def.tree_configuration.id}), :title => 'click to go to configure aggregate properties page to delete' %> is corrupt. You can rectify this issue by deleting this property."
      end
    end
    
    class TreeRelationshipPropertyDefinitionCorruption
      def initialize(prop_def)
        @prop_def = prop_def
      end
      
      def render
        "Property #{@prop_def.name.bold} is corrupt, please contact support."
      end
    end
    
    def corruption_check
      self.corruption_info = render_corruptions(property_column_sync_check)
    ensure
      self.corruption_checked = true
      save_by_first_admin!
    end
    
    def corrupt?
      corruption_info != nil
    end
    
    def force_corruption_check
      self.corruption_checked = false
      save_by_first_admin!
    end
    
    def corruption_info
      info = super
      return if info.blank?
      self.admin?(User.current) ? info : "Mingle found a problem it couldn't fix. Please contact your Mingle administrator. When the administrator accesses this project they should be able to rectify the issue by deleting the corrupt property."
    end
    
    private
    
    def render_corruptions(corruptions)
      return if corruptions.empty?
      ret = "<%= render_help_link('Corruption Propeties', :class => 'special-help-in-message-box') %>"
      ret << "<ul>" 
      ret << corruptions.collect{ |c| "<li>" + c.render + "</li>" }.join 
      ret << "</ul>"
    end
    
    def save_by_first_admin!
      User.with_first_admin { project.save! }
    end
    
    def property_column_sync_check
      card_schema.column_not_insync_properties.collect { |prop_def| corruption_for_prop_def(prop_def) }
    end
    
    def corruption_for_prop_def(prop_def)
      corruption_class(prop_def).new(prop_def)
    end
    
    def corruption_class(prop_def)
      { AggregatePropertyDefinition => AggregatePropertyDefinitionCorruption, 
        TreeRelationshipPropertyDefinition => TreeRelationshipPropertyDefinitionCorruption 
      }[prop_def.class] || NormalPropertyDefinitionCorruption
    end
  end
end
