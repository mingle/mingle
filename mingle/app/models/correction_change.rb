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

class CorrectionChange < ActiveRecord::Base
  belongs_to :event

  CHANGE_TYPES = {
    'property-rename' => { :feed_category => 'property-change', :source_type => 'PropertyDefinition' },
    'tag-rename' => { :feed_category => 'tag-change' },
    'managed-property-value-change' => { :feed_category => 'property-change', :source_type => 'PropertyDefinition' },
    'property-deletion' => { :feed_category => 'property-deletion', :source_type => 'PropertyDefinition' },
    'card-type-rename' => { :feed_category => 'card-type-change', :source_type => 'CardType' },
    'card-type-deletion' => { :feed_category => 'card-type-deletion', :source_type => 'CardType' },
    'card-type-and-property-disassociation' => { :feed_category => ['card-type-change', 'property-change'], :source_type => 'CardType', :secondary_source_type => 'PropertyDefinition' },
    'card-keywords-change' => { :feed_category => 'project-change', :source_type => 'Project' },
    'numeric-precision-change' => { :feed_category => 'project-change', :source_type => 'Project' },
    'repository-settings-change' => { :feed_category => 'repository-settings-change', :source_type => 'Project' }
  }

  def feed_category
    CHANGE_TYPES[self.change_type][:feed_category]
  end

  def source_type
    CHANGE_TYPES[self.change_type][:source_type]
  end

  def secondary_source_type
    CHANGE_TYPES[self.change_type][:secondary_source_type]
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.change :type => change_type, :mingle_timestamp => event.mingle_timestamp do
      source_xml(options.merge(:version => options[:api_version])) if resource_1
      secondary_source_xml(options.merge(:version => options[:api_version])) if resource_2
      serialize_scalar(options[:builder], "old_value", old_value) if old_value
      serialize_scalar(options[:builder], "new_value", new_value) if new_value
    end
  end

  def related_card_numbers
    []
  end

  private

  def source_xml(options)
    options[:builder].tag! source_type.underscore, :url => source_url(source_type, resource_1, options)
  end

  def secondary_source_xml(options)
    options[:builder].tag! secondary_source_type.underscore, :url => source_url(secondary_source_type, resource_2, options)
  end

  def source_url(source_type, source_id, options)
    source_link =  source_type == 'Project' ? event.project.resource_link : source_type.constantize.resource_link(nil, :id => source_id)
    source_link.xml_href(options[:view_helper], options[:version])
  end
end
