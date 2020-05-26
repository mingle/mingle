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

class RepositoryConfiguration
  include SqlHelper
  
  attr_reader :plugin
  
  delegate :source_browsing_ready?, :to => :plugin
  
  def initialize(plugin)
    @plugin = plugin
    @repository = nil
    @repository_looked_up = false
  end
  
  def display_name
    @plugin.class.display_name
  end
  
  def vocabulary
    @plugin.vocabulary
  end

  def repository
    if @repository == nil && !@repository_looked_up
      @repository_looked_up = true # todo -- let's do this better ..
      begin
        @repository = @plugin.repository
      rescue Exception => e
        log_error(e, "Unable to connect to repository for project #{project.identifier}")
      end
    end
    @repository
  end
  
  def can_connect?
    begin
      repository != nil
    rescue Exception => e
      log_error(e, "Unable to connect to repository for project #{project.identifier}")
    end
  end
  
  def source_browsable?
    plugin.respond_to?(:source_browsable?) ? plugin.source_browsable? : true
  end
    
  def invalidate_card_links
    update_sql = %{
      UPDATE #{@plugin.class.table_name} 
      SET card_revision_links_invalid = ? 
      WHERE id = #{@plugin.id}
    }
    update_sql = sanitize_sql(update_sql, true)
    execute(update_sql)
    reload
  end
  
  def mark_valid
    update_sql = %{
      UPDATE #{@plugin.class.table_name} 
      SET initialized = ?, card_revision_links_invalid = ? 
      WHERE id = #{@plugin.id}
    }
    update_sql = sanitize_sql(update_sql, true, false)
    execute(update_sql)
    reload
  end

  def reload_plugin
    @plugin.reload
  end

  def mark_for_deletion
    update_sql = %{
      UPDATE #{@plugin.class.table_name} 
      SET marked_for_deletion = ? 
      WHERE id = #{@plugin.id}
    }
    update_sql = sanitize_sql(update_sql, true)
    execute(update_sql)
    reload
  end  
  
  def marked_for_deletion?
    @plugin.marked_for_deletion
  end
    
  def initialized?
    @plugin.initialized
  end
  
  def card_revision_links_invalid
    @plugin.card_revision_links_invalid
  end
  
  def password
    if @plugin.class.included_modules.include?(PasswordEncryption)
      @plugin.decrypted_password
    end
  end
  
  def password=(value)
    if @plugin.class.included_modules.include?(PasswordEncryption)
      @plugin.password = value
    end
  end
  
  # not sure we want to depend upon the plugin providing
  # this one...  is there a more abstract concept to ask of the plugin?
  def repository_path
    @plugin.repository_path
  end
  
  def repository_empty?
    repository.empty?
  end
  
  def save!
    @plugin.save!
  end
  
  def project
    @plugin.project
  end
  
  def project_id
    @plugin.project_id
  end
  
  def plugin_db_id
    @plugin.id
  end
  
  def plugin_class
    @plugin.class
  end
  
  def reload
    @plugin.reload
    self
  end
  
  def view_partials
    @plugin.view_partials
  end
  
  def re_initialize!
    new_config = @plugin.clone
    if @plugin.class.included_modules.include?(PasswordEncryption)
       new_config.password = @plugin.decrypted_password
    end
    mark_for_deletion
    new_config.initialized = false
    new_config.save!
    @plugin = new_config
  end
  
end
