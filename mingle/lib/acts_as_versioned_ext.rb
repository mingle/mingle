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

module ActiveRecord
  module Acts
    module Versioned
      
      module ClassMethods
        def find_versions_in(period, project)
          start_time, end_time = period.boundaries            
          find_versions ["#{versioned_table_name}.project_id = ? and updated_at >= ? and updated_at < ?", project.id, start_time.utc, end_time.utc]
        end  

        def find_versions_for(project)
          find_versions ["#{versioned_table_name}.project_id = ?", project.id]
        end

        def find_versions(conditions)            
          versioned_class.find(:all, :conditions => conditions, :order => 'updated_at desc', :include => [{:taggings => :tag}, :modified_by, :changes, :project])
        end
        
        def acts_as_versioned_ext(options={})
          keep_versions = options.delete(:keep_versions_on_destroy)

          options[:association_options] ||= {}
          options[:association_options].merge!(:dependent => :destroy)

          acts_as_versioned(options)
          
          if keep_versions
            #override has_many destroy method to do nothing, i.e. to not delete the versions
            define_method(:has_many_dependent_destroy_for_versions) { }
          end
        end
                
      end
      
      module ActMethods
        
        def find_version(version_number)
          self.versions.find(:first, :conditions => ['version = ?', version_number])
        end  
        
        def versions_with_eager_loads_for_history_performance
          full_versioned_class = "#{self.class}::#{self.versioned_class_name}".constantize
          earliest_available_version = full_versioned_class.minimum(:version, :conditions => ["#{full_versioned_class.quoted_table_name}.#{self.class.versioned_foreign_key} = #{self.id}"])
          
          select_condition_column = "project_id"
          full_versioned_class.find(:all,
               :select => "#{full_versioned_class.quoted_table_name}.*, CASE WHEN #{full_versioned_class.quoted_table_name}.version = #{earliest_available_version} THEN 1 ELSE 0 END AS earliest_available_version",
               :include => [:event, {:event => :changes}, :modified_by],
               :conditions => [
                 "#{full_versioned_class.quoted_table_name}.#{select_condition_column} = #{self.project_id}",
                 "#{full_versioned_class.quoted_table_name}.#{self.class.versioned_foreign_key} = #{self.id}"].compact.join(' AND '),
               :order => "#{full_versioned_class.quoted_table_name}.version DESC")
        end
      end
    end
  end
end
