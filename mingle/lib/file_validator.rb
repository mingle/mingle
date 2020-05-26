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

module FileValidator
  def self.attachment_size_limit
    limit = MingleConfiguration.attachment_size_limit
    limit ? limit.to_f : limit
  end

  def attachment_size_limit
    FileValidator.attachment_size_limit
  end

  def validate_attachment_size(files)
    return [] if attachment_size_limit.nil?
    limit_bytes = attachment_size_limit * 1024 * 1024
    files.select do |f|
      f.size > limit_bytes
    end.map do |f|
      "File #{f.original_filename} is too large to upload. Files cannot be larger than #{attachment_size_limit} MB."
    end
  end
end
