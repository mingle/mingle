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

class PopulateRenderedProjects < ActiveRecord::Migration
  
  class M123MacroHelper
    
    def initialize(content)
      @content = content
    end
    
    def has_macros?
      @content =~ pattern
    end
        
    def rendered_projects
      begin
        projects = []
        @content.gsub!(pattern) do |match|
          begin
            parameters = $~.captures[1].gsub(/#([0-9a-f]{6})/i, '\'\0\'')  # fix web colors
            parameters = YAML::load(M123MacroHelper.escape_single_quote(parameters))
            projects << parameters['project'] if parameters && parameters['project']
          rescue Exception => e
            # ignore ... bad macro content ...
          end
        end
        projects.compact.uniq
      rescue Exception => e
        []  # do not want this migration to ever fail ...
      end
    end
    
    private
    
    def pattern
      /\{\{\s*(\S*):?([^}]*)\}\}/
    end
    
    def self.escape_single_quote(str)
      str.gsub!(/(:\s+)('.*\w.*'.*\w.*)$/) do |match|
        indicator = $1
        value = $2.gsub(/'/, %{''})
        %{#{indicator}'#{value}'}
      end
      str.gsub!(/(:\s+)(".*\w.*".*\w.*)$/) do |match|
        indicator = $1
        value = $2.gsub(/"/, %{\\"})
        %{#{indicator}"#{value}"}
      end
      str
    end
    
  end
  
  def self.up    
    ActiveRecord::Base.connection.execute("DELETE FROM #{safe_table_name 'renderable_version_rendered_projects'}")
    
    projects = ActiveRecord::Base.connection.select_all("SELECT id, identifier FROM #{safe_table_name "projects"}")
    projects_by_id = {}
    projects_by_identifier = {}
    projects.each do |project|
      projects_by_id[project['id']] = project
      projects_by_identifier[project['identifier']] = project
    end
        
    # insert row for each non-host project for all page versions with macros
    puts "Updating macro info for all page versions (this could take a bit of time)..."
    
    page_versions_with_macros_sql = %{
      SELECT id, content, project_id
      FROM #{safe_table_name 'page_versions'}
      WHERE has_macros = ? 
    }
    page_versions = ActiveRecord::Base.connection.select_all(
      SqlHelper.sanitize_sql(page_versions_with_macros_sql, true)
    )
    page_versions.each do |page_version|
      if page_version.is_a?(Array)
        page_version = {'id' => page_version[0], 'content' => page_version[1], 'project_id' => page_version[2]}
      end
      macro_helper = M123MacroHelper.new(page_version['content'])
      if macro_helper.has_macros?
        rendered_projects = macro_helper.rendered_projects
        rendered_projects.each do |rendered_project|
          existing_renderd_project = projects_by_identifier[rendered_project]
          if existing_renderd_project && existing_renderd_project['id'] != page_version['project_id']
            ActiveRecord::Base.connection.execute(%{
              INSERT into #{safe_table_name 'renderable_version_rendered_projects'} 
              (renderable_version_id, renderable_version_type, rendered_project_id)
              VALUES (#{page_version['id']}, 'Page::Version', #{existing_renderd_project['id']})
            })
          end
        end
      else
        has_no_macros_sql = %{
          UPDATE #{safe_table_name('page_versions')}
          SET has_macros = ?
          WHERE id = #{page_version['id']}
        }
        ActiveRecord::Base.connection.execute(
          SqlHelper.sanitize_sql(has_no_macros_sql, false)
        )
      end
    end
    
    # insert row for each non-host project for all card versions with macros
    projects_by_identifier.keys.each do |identifier|  
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{identifier}_cards")
       
      puts "Updating macro info for project #{identifier} card versions (this could take a bit of time)..."
      cards_versions_with_macro_sql = %{
        SELECT id, description, project_id
        FROM #{safe_table_name("#{identifier}_card_versions")}
        WHERE has_macros = ? 
      }
      card_version_rows = ActiveRecord::Base.connection.select_all(
        SqlHelper.sanitize_sql(cards_versions_with_macro_sql, true)
      )

      card_version_rows.each do |card_version|
        if card_version.is_a?(Array)
          card_version = {'id' => card_version[0], 'description' => card_version[1], 'project_id' => card_version[2]}
        end
        macro_helper = M123MacroHelper.new(card_version['description'])
        if macro_helper.has_macros?
          rendered_projects = macro_helper.rendered_projects
          rendered_projects.each do |rendered_project|
            existing_rendered_project = projects_by_identifier[rendered_project]
            if existing_rendered_project && existing_rendered_project['id'] != card_version['project_id']
              ActiveRecord::Base.connection.execute(%{
                INSERT into #{safe_table_name 'renderable_version_rendered_projects'} 
                (renderable_version_id, renderable_version_type, rendered_project_id)
                VALUES (#{card_version['id']}, 'Card::Version', #{existing_rendered_project['id']})
              })
            end
          end
        else
          has_no_macros_sql = %{
            UPDATE #{safe_table_name("#{identifier}_card_versions")}
            SET has_macros = ?
            WHERE id = #{card_version['id']}
          }
          ActiveRecord::Base.connection.execute(
            SqlHelper.sanitize_sql(has_no_macros_sql, false)
          )
        end
      end
    end   
    
  end

  def self.down
    ActiveRecord::Base.connection.execute("DELETE FROM #{safe_table_name 'renderable_version_rendered_projects'}")
  end
end
