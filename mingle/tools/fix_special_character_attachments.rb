#!/usr/bin/env ruby
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

require File.expand_path("../config/environment.rb", File.dirname(__FILE__))

if ENV["test"]
  require File.expand_path("../test/unit/unit_test_data_loader", File.dirname(__FILE__))

  def hijack_attachment_with_a_special_characters_file(attachment, filename)
    Dir.chdir(File.dirname(attachment.file)) do
      File.rename(attachment.file_name, filename)
    end

    # need to get around FileColumn::sanitize_filename(), so just update via SQL
    Attachment.update_all({:file => filename}, {:id => attachment.id})

    # reload isn't sufficient due to file_column magic
    Attachment.find(attachment.id)
  end

  def test_project
    identifier = "test_123"
    Project.find_by_identifier(identifier) || Project.create(:identifier => identifier, :name => identifier)
  end

  def setup_test_env
    User.first_admin.with_current do
      puts "================= setting up test attachment ================"
      test_project.with_active_project do |project|
        attachment = project.attachments.create(:file => UnitTestDataLoader.sample_attachment('sample.txt'))

        special_chars_filename = "süpèrü§ér.txt"
        hijack_attachment_with_a_special_characters_file(attachment, special_chars_filename)
      end
    end
  end

  setup_test_env
  exit
end

# cannot match against \w or \W since Rails sets $KCODE to unicode mode
SPECIAL_CHAR_PATTERN = pattern = /[^A-Za-z0-9_\-\.]+/

def attachment_name_has_special_characters?(attachment)
  filename = File.basename(attachment.file)
  !SPECIAL_CHAR_PATTERN.match(filename).nil?
end

# support ticket 12020
User.first_admin.with_current do
  Attachment.all.each do |attachment|
    next unless attachment_name_has_special_characters?(attachment)

    new_file_name = FileColumn::sanitize_filename(File.basename(attachment.file))
    new_file_full_path = File.join(File.dirname(attachment.file), new_file_name)

    glob_pattern = File.basename(attachment.file).gsub(SPECIAL_CHAR_PATTERN, '*')
    files_that_match = Dir.glob(File.join(File.dirname(attachment.file), glob_pattern))

    if files_that_match.size != 1
      "#{glob_pattern} matches #{files_that_match.size} files. Cannot rename to fix attachment problem unless exactly 1 file is matched.".tap do |message|
        Rails.logger.error message
        puts message
      end
      next
    end

    original_file_full_path = files_that_match.first

    "attachment #{attachment.id}: moved #{original_file_full_path} to #{new_file_full_path}".tap do |message|
      Rails.logger.info(message)
      puts message
    end

    File.rename(original_file_full_path, new_file_full_path)

    attachment.file = File.new(new_file_full_path)
    attachment.save!
  end
end
