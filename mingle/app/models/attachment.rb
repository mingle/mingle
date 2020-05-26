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

class Attachment < ActiveRecord::Base

  NON_EXISTENT = 'nonexistent'

  belongs_to :project
  has_many :attachings
  before_destroy {|am| am.attachings.each(&:destroy) && am.attachings.reload}

  file_column :file, :root_path => DataDir::Public.directory.pathname, :store_dir => :dyna_path, :temp_base_dir => DataDir::Attachments.tmp_dir.pathname, :fix_file_extensions => false
  validates_presence_of :file

  serializes_as :url, :file_name

  def self.find_by_attachable_types(attachable_types)
    scope = scope(:find)
    find_by_sql(sanitize_sql([<<-SQL, attachable_types.collect(&:name)]))
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
             INNER JOIN #{Attaching.quoted_table_name} ON #{Attaching.quoted_table_name}.attachment_id = #{quoted_table_name}.id
       WHERE #{Attaching.quoted_table_name}.attachable_type IN (?)
       #{ ('AND ' + scope[:conditions]) if scope}
    SQL
  end

  def assign_random_path
    self.path = DataDir::Attachments.random_directory.pathname
  end

  def dyna_path
    assign_random_path if self.path.blank?
    self.path
  end

  def full_directory_path
    DataDir::Attachments.path(self.path)
  end

  def url(force_download=false)
    if MingleConfiguration.use_s3_attachments_storage?
      options = {:expires_in => MingleConfiguration.attachment_url_expiry_time}
      options.merge!(:response_content_disposition => "attachment; filename=\"#{file_name}\"") if force_download
      file_download_url(nil, nil, options)
    else
      ["#{CONTEXT_PATH}/#{path}/#{file_relative_path}", force_download ? "?download=yes" : nil].compact.join("")
    end
  end

  def file_name
    File.basename(file_relative_path)
  end

  def file_missing?
    !file_exists?
  end

  def dependency_attachment?
    dependency_attachable ? true : false
  end

  def dependency_attachable
    attachings.reverse.each do |attaching|
      if attaching.attachable_type == Dependency.name || attaching.attachable_type == Dependency::Version.name
        return attaching.attachable
      end
    end
    nil
  end

end
