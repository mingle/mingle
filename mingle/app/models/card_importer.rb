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

class CardImporter
  include ProgressBar

  attr_accessor :project, :user, :tree_configuration, :mapping, :ignore, :updated_count, :created_count, :progress, :tab_separated_import_preview_id
  delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :completed?, :to => :@progress
  delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

  def self.fromActiveMQMessage(message)
    new.tap do |importer|
      importer.project = Project.find(message[:project_id])
      importer.progress = AsynchRequest.find(message[:request_id])
      importer.user = User.find(message[:user_id])
      importer.tree_configuration = importer.project.tree_configurations.find_by_id(message[:tree_configuration_id])
      importer.mapping = message[:mapping]
      importer.ignore = message[:ignore]
      importer.tab_separated_import_preview_id = message[:tab_separated_import_preview_id]

      importer.mark_queued
    end
  end

  def create_card_reader
    CardImport::CardReader.new(project, CardImport::ExcelContent.new(tab_separated_import_path, ignore || []), mapping, User.current, tree_configuration)
  end

  def process!
    with_progress do |in_process|
      import_cards(&in_process)
    end
    ProjectCacheFacade.instance.clear_cache(project.identifier)
  end

  def import_cards
    @updated_count = 0
    @created_count = 0

    reader = create_card_reader
    reader.validate
    reader.update_schema
    update_attribute(:total, reader.size)
    reader.each_with_row_number do |card, row_number|
      import_error = nil
      begin
        transaction do 
          card.validate_tree_fully = true
          check_import_errors card
          new_card = card.new_record?
          card.save!
          if new_card
            @created_count += 1
          else
            @updated_count += 1
          end
          yield("#{pluralize(total, 'row')}, #{@updated_count} updated, #{@created_count} created", total, @updated_count + @created_count) if block_given?
          ignored_properties = card.properties_removed_as_not_applicable_to_card_type
          add_warning("Row #{row_number}: #{ignored_properties.names.join(', ').bold} ignored due to not being applicable to card type #{card.card_type_name.bold}.") if ignored_properties.any?
        end
      rescue Exception => import_error
        add_error("Row #{row_number}: #{import_error.message}")
      end
    end
    project.reset_card_number_sequence
  end

  private

  def tab_separated_import_path
    AsynchRequest.find_by_id(self.tab_separated_import_preview_id).localize_tmp_file
  end

  def check_import_errors(card)
    raise CardImport::CardImportException.new(card.errors.full_messages.join(', ')) if card.errors.any?

    card.tags.each do |tag|
      raise CardImport::CardImportException.new(tag.errors.full_messages.join(', ')) if tag.errors.any?
    end
  end

end
