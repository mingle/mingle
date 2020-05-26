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

class Tag < ActiveRecord::Base
  
  has_many :taggings, :class_name => '::Tagging'
  belongs_to :project
  before_update :update_saved_views, :update_history_subscriptions

  named_scope :used, :conditions => ["deleted_at IS NULL"]  
  named_scope :deleted, :conditions => ["deleted_at IS NOT NULL"]  
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:project_id, :deleted_at], :case_sensitive => false
  validates_format_of :name, :with => /^[^,]+$/, :message => "Comma is not allowed", :unless => 'name.blank?'
  
  acts_as_paranoid
  strip_on_write
  use_database_limits_for_all_attributes

  class << self
    def with_project_scope(project_id)
      with_scope(:create => {'project_id' => project_id}, :find => {:conditions => {'project_id' => project_id}}) do
        yield
      end
    end
    
    def case_insensitive_find_by_tag_name(name)
      find(:first, :conditions => ["LOWER(name) = ?", name.downcase]).tap { |tag| tag.deleted_at = nil if tag }
    end

    def lookup_by_name_case_insensitively(name)
      case_insensitive_find_by_tag_name(name) || create(:name => name)
    end
        
    def parse(list)
      return [] if list.nil?
    
      if list.respond_to?(:to_str)
        list = list.to_str.dup
        tag_names = []

        # first, pull out the quoted tags
        list.gsub!(/\"(.*?)\"\s*/ ) { tag_names << $1; "" }

        # then, get whatever's left
        tag_names.concat list.split(/,/)
      else
        tag_names = list
      end

      # strip whitespace from the names
      tag_names = tag_names.map { |t| t.strip.gsub(/ +/, ' ') }

      # delete any blank tag names
      tag_names = tag_names.delete_if { |t| t.empty? }
      tag_names.uniq
    end
  
  end
  
  #todo : we need to revisit this ... can we still not rename to a previously deleted tag?
  def validate_on_update
    old_tag = self.project.tags.find_by_name(self.name)
    if old_tag and old_tag.id != self.id
      if old_tag.deleted_at
        errors.add(:name, %{
          cannot currently be renamed to a previously deleted tag name.
        })
      else
        errors.add_to_base "Tag #{self.name.bold} already exists."
      end
    end
  end

  def tagged
    @tagged ||= taggings.collect { |tagging| tagging.taggable }
  end
  
  def tagged_cards
    tagged.select { |taggable| taggable.instance_of? Card }
  end
  
  def tagged_pages
    tagged.select { |taggable| taggable.instance_of? Page }
  end

  def tagged_count_on(model)
    conditions = model == :all ? "taggable_type not like '%::Version'": "taggable_type = '#{model}'"
    taggings.count(:conditions => conditions).to_i
  end
    
  def active_taggings?
    tagged_count_on(:all) > 0
  end

  def safe_delete
    taggings.each do |tagging|
      unless (tagging.taggable.instance_of?(Card::Version) || tagging.taggable.instance_of?(Page::Version)) #todo: need a better way to do this
        id = tagging.taggable_id
        tagging.destroy
        if tagging.taggable.respond_to? :versions
          tagging.taggable.reload.save!  #force new version
        end
      end
    end
    self.destroy
  end
  
  def name=(new_name)
    @old_name = self.name
    write_attribute(:name, new_name)
  end
  
  def update_saved_views
    project.card_list_views.each do |view|
      view.on_tag_renamed(@old_name, name)
    end
  end
  
  def update_history_subscriptions
    project.history_subscriptions.each do |subscription|
      subscription.rename_tag(@old_name, name) unless @old_name.blank?
      subscription.save!
    end
  end
  
  def ==(comparison_object)
    super || (name.downcase == comparison_object.to_s.downcase)
  end
  
  def to_s
    name
  end
  
  # optimization
  def project
    return Project.current
  end  

end

