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

require 'data_fixes/create_missing_login_access_for_users'
require 'data_fixes/fix_orphan_property_changes'
require 'data_fixes/remove_orphaned_property_columns'
require 'data_fixes/clean_property_names_in_changes_and_card_list_views'
require 'data_fixes/clean_orphan_card_defaults'
require 'data_fixes/set_redcloth_for_cards_and_versions'
require 'data_fixes/redistribute_card_ranks'
require 'data_fixes/tree_configurations_last_relationship_multiple_card_type_mapping'
require 'data_fixes/remove_properties_with_missing_columns'

module DataFixes
  class << self
    @@fixes = {}

    # register a data fix, a data fix should response to following
    # methods: name, description, required? and apply
    def register(data_fix)
      @@fixes[data_fix.name] = data_fix
    end

    def reset
      @@fixes.clear
      self.register(CreateMissingLoginAccessForUsers)
      self.register(FixOrphanPropertyChanges)
      self.register(CleanOrphanCardDefaults)
      self.register(RemoveOrphanedPropertyColumns)
      self.register(CleanPropertyNamesInChangesAndCardListViews)
      self.register(SetRedclothForCardsAndVersions)
      self.register(RedistributeCardRanks)
      self.register(TreeConfigurationsLastRelationshipMultipleCardTypeMapping)
      self.register(RemovePropertiesWithMissingColumns)
    end

    def list
      @@fixes.values.sort_by(&:name).inject([]) do |memo, fix|
        if fix.respond_to?(:info_hash)
          memo << fix.info_hash
        else
          memo << {
            'name' => fix.name,
            'description' => fix.description,
            'project_ids' => [],
            'queued' => fix.queued?
          }
        end
      end
    end

    def apply(fix_hash={})
      fix = resolve(fix_hash)
      if fix.present? && (fix_hash["required"] || fix.required?)
        ActiveRecord::Base.transaction do
          fix.apply(fix_hash["project_ids"])
        end
      end
    end

    def resolve(fix_hash={})
      @@fixes[fix_hash["name"]]
    end

  end

  self.reset
end
