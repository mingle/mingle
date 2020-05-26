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
  module Acts #:nodoc:
    module Taggable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods    
        
        def acts_as_taggable(options = {})
    
          write_inheritable_attribute(:acts_as_taggable_options, {
            :taggable_type => ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s,
            :from => options[:from]
          })
          
          class_inheritable_reader :acts_as_taggable_options

          has_many :taggings, :as => :taggable, :dependent => :delete_all, :class_name => '::Tagging',
            :include => :tag, :order => 'position'

          include ActiveRecord::Acts::Taggable::InstanceMethods
          extend ActiveRecord::Acts::Taggable::SingletonMethods
        end
      end
      
      module SingletonMethods
        def find_tagged_with(list)
          # need to propagate project_id scope from acts_as_taggable to tag
          project_id = current_scoped_methods[:create]['project_id']
          Tag.with_project_scope(project_id) do
            
            tag_ids = Tag.parse(list).collect do |tag|
              if tag.respond_to?(:to_str)
                Tag.find_by_name(tag)
              else
                tag.id
              end
            end
            
            find(:all,
              :include => {:taggings => :tag},
              :joins => %{
                JOIN taggings tagged_with_taggings ON tagged_with_taggings.taggable_id = #{self.table_name}.id AND
                                                         tagged_with_taggings.taggable_type = '#{acts_as_taggable_options[:taggable_type]}'
                JOIN tags tagged_with_tags ON tagged_with_tags.id = tagged_with_taggings.tag_id
              },
              :conditions => ['tagged_with_tags.id IN (?)', tag_ids])
            
          end
        end

      end
      
      module InstanceMethods
        def add_tag(name)
          begin
            tag = project.tags.lookup_by_name_case_insensitively(name)
            if tag.errors.empty?
              unless taggings.any?{|tagging| tagging.tag.id == tag.id}
                new_taggings = self.taggings.collect{|tagging| ::Tagging.new(:tag => tagging.tag)}
                new_taggings << ::Tagging.new(:tag => tag)
                self.taggings = new_taggings
              end
            else
              tag.errors.each_full {|message| self.errors.add_to_base message}
            end
          rescue Exception => e
            self.errors.add_to_base(e.message)
          end
        end
        

        
        def remove_tag(name)
          tag = project.tags.case_insensitive_find_by_tag_name(name)
          self.taggings = taggings.select{|tagging| tagging.tag.id != tag.id} if tag
        end
                
        def tag_with(list)
          self.taggings = []
          Tag.parse(list).each{|tag| add_tag(tag)}
          self
        end
        
        def reorder_tags(new_order)
          new_order.each do |tag_name|
            tag = project.tags.case_insensitive_find_by_tag_name(tag_name)
            tagging = taggings.find_by_tag_id(tag.id)
            tagging.move_to_bottom
          end
        end

        def tags
          taggings.collect{|tagging| tagging.tag}
        end
        
        def has_tag?
          if taggings.loaded?
            !taggings.empty?
          else
            taggings.count > 0
          end
        end

        def tag_list
          tags.collect{|tag| tag.name }.sort.join(" ")
        end

        def tagged_with?(tag)
          tag = tag.respond_to?(:taggings) ? tag : project.tags.find_by_name(tag)
          self.taggings.any?{|t| t.tag_id == tag.id}
        end               
        
        def clone_taggings(orig_model, new_model)
          new_model.taggings = orig_model.tags.collect{|tag| Tagging.new(:tag => tag)}
        end
        
        def tags_not_represented_in(other_taggable)
          self.tags.select{|t| !(other_taggable.tags.include? t)}.collect{|t| t.name}.sort
        end               
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)
