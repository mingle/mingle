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

class Change < ActiveRecord::Base
  class DeletedResource
    def initialize(type, attributes={})
      @type = type
      @attributes = attributes
    end

    def to_xml(options = {})
      builder = options[:builder]
      builder.tag! "deleted_#{@type}" do
        @attributes.each do |key, value|
          builder.tag!(key, value)
        end
      end
    end
  end



  belongs_to :tag, :with_deleted => true
  belongs_to :attachment
  belongs_to :event

  named_scope :desc_order_by_id, order: 'id DESC'
  class << self
    def create_change(field_name, old_value, new_value)
      FieldChange.create(current_scoped_methods[:create].merge(:field => field_name, :old_value => old_value, :new_value => new_value))
    end

    def create_name_change(old_value, new_value)
      NameChange.create(current_scoped_methods[:create].merge(:field => 'Name', :old_value => old_value, :new_value => new_value))
    end

    def create_description_change(field_name="Description")
      DescriptionChange.create(current_scoped_methods[:create].merge(:field => field_name))
    end

    def create_property_change(old_property_name, old_property_db_identifier, new_property_db_identifier)
      PropertyChange.create(current_scoped_methods[:create].merge(:field => old_property_name, :old_value => old_property_db_identifier, :new_value => new_property_db_identifier))
    end

    def create_dependency_property_change(property_name, old_value, new_value)
      DependencyPropertyChange.create(current_scoped_methods[:create].merge(:field => property_name, :old_value => old_value, :new_value => new_value))
    end

    def create_raising_card_change(card)
      DependencyRaisingCardChange.create(current_scoped_methods[:create].merge(:field => 'Raising card', :new_value => card.number))
    end

    def create_dependency_resolving_project_change(property_name, old_value, new_value)
      DependencyResolvingProjectChange.create(current_scoped_methods[:create].merge(:field => property_name, :old_value => old_value, :new_value => new_value))
    end

    def create_dependency_new_cards_linked_change(new_linked_cards)
      DependencyCardLinkChange.create(current_scoped_methods[:create].merge(:field => 'New cards linked', :new_value => new_linked_cards.map(&:number).join(",")))
    end

    def create_dependency_cards_unlinked_change(unlinked_cards)
      DependencyCardLinkChange.create(current_scoped_methods[:create].merge(:field => 'Unlinked cards', :new_value => unlinked_cards.map(&:number).join(",")))
    end

    def create_dependency_deletion_change
      DependencyDeletionChange.create(current_scoped_methods[:create])
    end


    def create_card_type_change(old_value, new_value)
      CardTypeChange.create(current_scoped_methods[:create].merge(:field => Project.card_type_definition.name, :old_value => old_value, :new_value => new_value))
    end

    def create_tag_addition_change(tag)
      TagAdditionChange.create(current_scoped_methods[:create].merge(:field => 'tags', :new_value => tag.name, :tag => tag))
    end

    def create_tag_deletion_change(tag)
      TagDeletionChange.create(current_scoped_methods[:create].merge(:field => 'tags', :old_value => tag.name, :tag => tag))
    end

    def create_attachment_added_change(attachment)
      AttachmentChange.create(current_scoped_methods[:create].merge(:field => 'attachment', :attachment => attachment, :new_value => attachment.file_name))
    end

    def create_attachment_removed_change(attachment)
      AttachmentChange.create(current_scoped_methods[:create].merge(:field => 'attachment', :attachment => attachment, :old_value => attachment.file_name))
    end

    def create_attachment_replaced_change(attachment)
      AttachmentChange.create(current_scoped_methods[:create].merge(:field => 'attachment', :attachment => attachment, :old_value => attachment.file_name, :new_value => attachment.file_name))
    end

    def create_card_deletion_change
      CardDeletionChange.create(current_scoped_methods[:create])
    end

    def create_page_deletion_change
      PageDeletionChange.create(current_scoped_methods[:create])
    end

    def create_objective_deletion_change
      ObjectiveDeletionChange.create(current_scoped_methods[:create])
    end

    def create_revision_change
      RevisionChange.create(current_scoped_methods[:create])
    end

    def create_comment_change(comment)
      CommentChange.create(current_scoped_methods[:create].merge(:field => 'Comment', :new_value => comment[0..250]))
    end

    def create_system_generated_comment_change(comment)
      SystemGeneratedCommentChange.create(current_scoped_methods[:create].merge(:field => 'System generated comment', :new_value => comment[0..250]))
    end

    def create_card_copy_to_change
      CardCopiedToChange.create(current_scoped_methods[:create])
    end

    def create_card_copy_from_change
      CardCopiedFromChange.create(current_scoped_methods[:create])
    end

    def versions_in(project, period, pagination_options)
      sql = %{
        SELECT DISTINCT c.version_type, c.version_id, c.created_at
        FROM changes c
        WHERE c.project_id = #{project.id}
        #{period_conditions(period)}
        ORDER BY c.created_at
      }
      self.connection.add_limit_offset!(sql, pagination_options)
      results = self.connection.select_all(sql)
      results.collect do |row|
        row['version_type'].constantize.load_history_event(project, row["version_id"])
      end
    end

    def period_conditions(period)
      start_time, end_time = period.boundaries
      sql = "".tap do |result|
        result << " AND c.created_at >= ? " if start_time
        result << " AND c.created_at < ? " if end_time
      end
      sanitize_conditions [sql, *period.boundaries.compact.collect(&:utc)]
    end

    def rename_change_value(project_id, field, old_value, new_value)
      ['new_value', 'old_value'].each do |column_name|
        sql = SqlHelper.sanitize_sql("UPDATE #{self.table_name} SET #{column_name} = ? WHERE field = ? AND #{column_name}= ?
            AND event_id in (SELECT id FROM #{Event.table_name} WHERE deliverable_id = ? )", new_value, field, old_value, project_id)
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end

  def added_tag
    nil
  end

  def removed_tag
    nil
  end

  def matches?(options)
    options.keys.all? { |k| send(k.to_sym) == options[k] }
  end

  def from_property_definition?(property_definition)
    false
  end

  def descriptive?
    !describe.blank?
  end

  def project
    Project.current
  end

  def version
    self.event.origin
  end

  def property_name
    ''
  end

  def from
    ''
  end

  def to
    ''
  end

  def murmur
    ''
  end

  def attachment_name
    ''
  end

  def description_changes_for_export
    ''
  end

  def content_changes_for_export
    ''
  end

  def describe_type_for_export
    change_type = type.titlecase.split(' ')
    "#{change_type.shift} #{change_type.join(' ').downcase}"
  end

  def to_xml(options={})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.change :type => feed_category, :mingle_timestamp => event.mingle_timestamp do
      change_xml(options)
    end
  end

  def related_card_numbers
    []
  end

  protected

  def feed_category
    raise "#{self.class} must implement feed_category method!"
  end

  def compact_xml(obj, options)
    return unless obj
    obj.to_xml(:builder => options[:builder], :skip_instruct => true, :compact => true, :view_helper => options[:view_helper], :version => options[:api_version])
  end


  def change_xml(options)
    xml_serialize(:old_value, old_value, options)
    xml_serialize(:new_value, new_value, options)
  end

  def xml_serialize(tag, value, options)
    builder = options[:builder]
    if value.respond_to?(:to_xml)
      builder.tag!(tag) { compact_xml(value, options) }
    else
      serialize_scalar(builder, tag, value)
    end
  end

end

class NameChange < Change
  def describe
    "#{field.to_s} changed from #{old_value} to #{new_value}" if old_value and new_value
  end

  def feed_category
    'name-change'
  end

  def from
    old_value
  end

  def to
    new_value
  end

  def describe_type_for_export
    old_value.blank? ? 'Name set' : 'Name changed'
  end

end

class FieldChange < Change
  def describe
    "#{field.to_s} changed"
  end

  def feed_category
    "#{field.to_s}-change"
  end
end

class DescriptionChange < Change
  def describe
    "#{field.to_s} changed"
  end

  def feed_category
    'description-change'
  end

  def change_xml(options)
  end

  def describe_type_for_export
    'Description changed'
  end

  def description_changes_for_export
    old_description = version.first? ? '' : version.previous.description
    changes_in_text(old_description, version.description)
  end

  def content_changes_for_export
    old_content = version.first? ? '' : version.previous.content
    changes_in_text(old_content, version.content)
  end
  private

  def changes_in_text(old_text , new_text, options={})
    old = create_java_list(old_text)
    diff = Java::difflib.DiffUtils.diff(old, create_java_list(new_text))
    unified_diff = Java::difflib.DiffUtils.generateUnifiedDiff("", "", old, diff, 0)
    unified_diff.to_a.join("\n")
  end

  def create_java_list(text)
    text ||= ''
    java.util.Arrays.asList(text.to_java.split("\\r?\\n"))
  end
end

class DependencyPropertyChange < Change
  def describe
    "#{field.to_s} changed from #{old_value} to #{new_value}" if old_value and new_value
  end

  def feed_category
    'dependency-property-change'
  end

  def from
    old_value
  end

  def to
    new_value
  end

  def describe_type_for_export
    old_value.blank? ? 'Property set' : 'Property changed'
  end
end

class DependencyResolvingProjectChange < Change
  def describe
    old_project_exists = old_value.blank? ? false : Project.exists?(old_value)
    new_project_exists = new_value.blank? ? false : Project.exists?(new_value)
    if !old_project_exists && new_project_exists
      "#{field.to_s} set to #{Project.find(new_value).name}"
    elsif old_project_exists && !new_project_exists
      "#{field.to_s} removed"
    elsif old_project_exists && new_project_exists
      "#{field.to_s} changed from #{Project.find(old_value).name} to #{Project.find(new_value).name}" if old_value and new_value
    else
      ""
    end
  end

  def feed_category
    'dependency-resolving-project-change'
  end

  def from
    old_value.blank? ? old_value : Project.find(old_value).name
  end

  def to
    new_value.blank? ? new_value : Project.find(new_value).name
  end

  def describe_type_for_export
    old_value.blank? ? 'Resolving project set' : 'Resolving project changed'
  end
end

class DependencyCardLinkChange < Change
  def describe
    "#{field.to_s}: #{format_cards(new_value)}"
  end

  def format_cards(card_numbers)
    event.origin.resolving_project.with_active_project do
      card_numbers.split(",").map do |num|
        card = Project.current.cards.find_by_number(num.to_i)
        if card.present?
          %Q{<span title="#{card.name}">##{num}</span>}
        else
          %Q{<span title="Deleted Card">##{num}</span>}
        end
      end.join(", ")
    end
  end

  def from
    old_value.blank? ? old_value : "#{event.origin.resolving_project.identifier}/##{old_value}"
  end

  def to
    new_value.blank? ? new_value : "#{event.origin.resolving_project.identifier}/##{new_value}"
  end

  def describe_type_for_export
    old_value.blank? ? 'Card linked' : 'Linked card removed'
  end

  def feed_category
    'dependency-linked-cards-change'
  end
end

class DependencyRaisingCardChange < Change
  def describe
    "#{field.to_s} set to: #{format_card(new_value)}"
  end

  def format_card(card_number)
    event.origin.raising_project.with_active_project do
      card = Project.current.cards.find_by_number(card_number.to_i)
      if card.present?
        %Q{<span title="#{card.name}">##{card_number}</span>}
      else
        %Q{<span title="Deleted Card">##{card_number}</span>}
      end
    end
  end

  def feed_category
    'dependency-raising-card-change'
  end

  def from
    old_value.blank? ? old_value : "#{event.origin.raising_project.identifier}/##{old_value}"
  end

  def to
    new_value.blank? ? new_value : "#{event.origin.raising_project.identifier}/##{new_value}"
  end

  def field
    'Raising card'
  end
  def describe_type_for_export
    old_value.blank? ? 'Raising card set' : 'Raising card changed'
  end
end

class PropertyChange < Change
  def feed_category
     "property-change"
  end

  def change_xml(options)
    builder = options[:builder]
    compact_xml(property_definition, options)
    xml_serialize(:old_value, old_property_resource, options)
    xml_serialize(:new_value, new_property_resource, options)
  end

  def from_property_definition?(property_definition)
    field.to_s == property_definition.name
  end

  def describe
    (old_property.not_set? and new_property.set?) ? "#{field.to_s} set to #{new_property.display_value}" : "#{field.to_s} changed from #{old_property.display_value} to #{new_property.display_value}"
  end

  def property_name
    field.to_s
  end

  def from
    old_value
  end

  def to
    new_value
  end

  def describe_type_for_export
    old_value.blank? ? 'Property set' : 'Property changed'
  end
  private

  def property_definition
    project.find_property_definition(field.to_s, :with_hidden => true)
  end

  def old_property_resource
    old_property.value
  rescue PropertyDefinition::InvalidValueException
    Change::DeletedResource.new(old_property.property_type.to_sym)
  end

  def new_property_resource
    new_property.value
  rescue PropertyDefinition::InvalidValueException
    Change::DeletedResource.new(new_property.property_type.to_sym)
  end

  def old_property
    property_definition.property_value_from_db(old_value)
  end

  def new_property
    property_definition.property_value_from_db(new_value)
  end

end

class CardTypeChange < Change
  def describe
    if old_value.blank? and new_value
      "#{Project.card_type_definition.name} set to #{new_value}"
    else
      "#{Project.card_type_definition.name} changed from #{old_value} to #{new_value}"
    end
  end

  def feed_category
    "card-type-change"
  end

  def change_xml(options)
    builder = options[:builder]
    old_card_type = project.find_card_type(old_value) rescue Change::DeletedResource.new('card_type', :name => old_value)
    new_card_type = project.find_card_type(new_value) rescue Change::DeletedResource.new('card_type', :name => new_value)
    xml_serialize(:old_value, old_card_type, options)
    xml_serialize(:new_value, new_card_type, options)
  end

  def from
    old_value
  end

  def to
    new_value
  end

  def describe_type_for_export
    old_value.blank? ? 'Card type set' : 'Card type changed'
  end

end

class TagAdditionChange < Change
  def feed_category
    "tag-addition"
  end

  def change_xml(options)
    xml_serialize(:tag, tag.name, options)
  end

  def added_tag
    tag
  end

  def describe
    "Tagged with #{tag.name}"
  end

  def describe_type_for_export
    'Tag added'
  end
end

class TagDeletionChange < Change

  def feed_category
    "tag-removal"
  end

  def change_xml(options)
    xml_serialize(:tag, tag.name, options)
  end

  def removed_tag
    tag
  end

  def describe
    "Tag removed #{tag.name}"
  end

  def describe_type_for_export
    'Tag removed'
  end
end

class AttachmentChange < Change
  def feed_category
    if new_value.blank?
      "attachment-removal"
    elsif old_value.blank?
      "attachment-addition"
    else
      "attachment-replacement"
    end
  end

  def describe
    if new_value.blank?
      "#{field.to_s.humanize} removed #{old_value}"
    elsif old_value.blank?
      "#{field.to_s.humanize} added #{new_value}"
    else
      "#{field.to_s.humanize} replaced #{old_value}"
    end
  end

  def change_xml(options)
    compact_xml(attachment, options)
  end

  def describe_type_for_export
    old_value.blank? ? 'Attachment added' : 'Attachment removed'
  end

  def attachment_name
    (new_value || old_value)
  end
end

class CardDeletionChange < Change
  def feed_category
    "card-deletion"
  end

  def change_xml(options)
  end

  def describe_type_for_export
    'Card deleted'
  end
end

class DependencyDeletionChange < Change
  def feed_category
    "dependency-deletion"
  end

  def change_xml(options)
  end

end

class PageDeletionChange < Change
  def feed_category
    "page-deletion"
  end

  def change_xml(options); end

  def describe_type_for_export
    'Page deleted'
  end
end

class ObjectiveDeletionChange < Change
  def feed_category
    "objective-removed"
  end

  def change_xml(options)
  end

end

class RevisionChange < Change

  def feed_category
    "revision-commit"
  end

  def describe
    event.description
  end

  def related_card_numbers
    project.card_keywords.card_numbers_in(event.origin.commit_message).uniq
  end

  def to_xml(options={})
    rev = event.origin
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.change :type => feed_category, :mingle_timestamp => event.mingle_timestamp do
      xml.changeset do
        xml_serialize(:user, rev.commit_user, options)
        xml_serialize(:check_in_time, rev.commit_time, options)
        xml_serialize(:revision, rev.identifier, options)
        xml_serialize(:message, rev.commit_message, options)
      end
    end
  end
end

class CommentChange < Change
  def feed_category
    "comment-addition"
  end

  def change_xml(options)
    xml_serialize(:comment, new_value, options)
  end

  def related_card_numbers
    project.card_keywords.card_numbers_in(new_value).uniq
  end

  def describe
    "#{field} added: #{new_value[0..46]}".tap do |result|
      result << "..." if new_value.size > 47
    end
  end

  def murmur
    new_value
  end

  def describe_type_for_export
    'Comment added'
  end
end

class SystemGeneratedCommentChange < Change
  def feed_category
    "system-comment-addition"
  end

  def change_xml(options)
    xml_serialize(:comment, new_value, options)
  end

  def describe
    "#{field}: #{new_value}"
  end
end

class CardCopiedChange < Change
  def feed_category
    raise "subclasses must implement feed_category"
  end

  def change_xml(options)
    xml = options[:builder]
    view_helper = options[:view_helper]

    if event.source.nil?
      xml.source :deleted => true, :url => ''
    else
      xml.source :url => view_helper.send(:rest_card_show_url, url_opts(event.source))
    end

    if event.destination.nil?
      xml.destination({:deleted => true, :url => ''})
    else
      xml.destination :url => view_helper.send(:rest_card_show_url, url_opts(event.destination))
    end
  end

  private

  def url_opts(options)
    :number
    :project_id
    {:api_version=>"v2", :format=>"xml"}.merge(options)
  end
end

class CardCopiedToChange < CardCopiedChange
  def feed_category
    "card-copied-to"
  end
end

class CardCopiedFromChange < CardCopiedChange
  def feed_category
    "card-copied-from"
  end
end

