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
  class DependenciesImportPreviewAsynchRequest < AsynchRequest

    def progress_msg
      if completed? && success?
        "Dependency import preview created."
      else
        progress_message
      end
    end

    def callback_url(params, project)
      { :controller => 'asynch_requests', :action => 'progress', :id => id }
    end

    def success_url(controller, params)
      { :controller => 'dependencies_import_export', :action => 'preview_errors', :id => id }
    end

    def failed_url(controller, params)
      { :controller => 'dependencies_import_export', :action => 'index', :id => id }
    end

    def view_header
      "asynch_requests/dependencies_import_preview_view_header"
    end

    def add_error_view(name)
      add_message("error_views", name)
    end

    def add_dependency(dependency_hash)
      dependencies << dependency_hash unless dependency_hash.blank?
    end

    def add_dependencies_error(dependency_hash)
      dependencies_errors << dependency_hash unless dependency_hash.blank?
    end

    def dependencies
      fetch_from_message("dependencies")
    end

    def dependencies_errors
      fetch_from_message("dependencies_errors")
    end

    def dependencies_to_import
      dependencies + dependencies_errors.reject {|dep_hash| dep_hash["raising_card"].blank? }
    end

    def exported_package
      message_get("upgraded_archive").nil? ? localize_tmp_file : message_get("upgraded_archive")
    end

    def set_exploded_directory(path)
      message_put("upgraded_archive", path)
      save!
    end

    def error_views
      fetch_from_message("error_views")
    end

    private

    def message_get(key)
      self.message ||= {}
      self.message[key]
    end

    def message_put(key, value)
      self.message ||= {}
      self.message[key] = value
    end

    def fetch_from_message(key)
      self.message ||= {}
      self.message[key] ||= []
    end
  end
end
