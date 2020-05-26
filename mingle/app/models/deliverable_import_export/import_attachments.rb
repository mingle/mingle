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

module DeliverableImportExport
  module ImportAttachments

    def import_attachments(table, include_content=true)
      return if table.nil?

      unless include_content
        table.imported = true
      else
        source_file_map = {}

        copy_files = lambda do |record, old_id, new_id|
          source = source_file_map.delete(new_id)

          if !source.nil? && File.exist?(source)
            attachment = Attachment.find_by_id(new_id)
            File.open(source) do |io|
              # recalculate root path again because we may have surpassed the directory file limit in the previous upload
              attachment.update_attribute(:path, DataDir::Attachments.random_directory.pathname)

              attachment.update_attribute(:file, io)
            end
          end
        end

        import_table(table, :after_insert => copy_files) do |record, old_id, new_id|
          source = File.join(directory, record["path"], old_id.to_s, record["file"])
          record["path"] = DataDir::Attachments.random_directory.pathname
          source_file_map[new_id] = source
        end
      end

    end

    def import_attachings(include_types=[], &select)
      table = table("attachings")
      return if table.nil? || table.imported?
      step("Importing #{table.name}...") do
        if include_types.empty?
          table.imported = true
        else
          import_table(table) do |record, old_id, new_id|
            result = check_attachable_ids_exist?(record) && include_types.include?(record["attachable_type"])

            if block_given?
              result = result && select.call(record, old_id, new_id)
            end

            result
          end
        end
      end
    end

    def check_attachable_ids_exist?(record)
      # check attachable_id exists; as some old project exports may have this missing and we should not import these records
      record["attachable_id"] && record["attachment_id"]
    end

  end
end
