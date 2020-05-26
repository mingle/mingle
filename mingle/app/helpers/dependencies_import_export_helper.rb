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

module DependenciesImportExportHelper

  def upload_form
    MingleConfiguration.import_files_bucket_name.present? ? 'upload_form' : 'upload_form'
  end

  def dependencies_export_file_name
    "#{Time.now.strftime("%Y-%m-%d")}.dependencies"
  end

  def dependency_prefixed_number(data)
    "#D#{data["number"]}"
  end

  def dependency_project(project_data)
    project_data["name"]
  end

  def dependency_raising_project(data)
    dependency_project(data["raising_project"])
  end

  def dependency_resolving_project(data)
    dependency_project(data["resolving_project"])
  end

  def dependency_raising_card(data)
    linked_card_summary data["raising_card"]
  end

  def linked_card_summary(card_data)
    truncate("##{card_data["number"]} #{card_data["name"]}", :length => 50)
  end

  def dependency_resolving_cards(data, &block)
    data["resolving_cards"].each do |drc|
      block.call(drc, linked_card_summary(drc)) if block_given?
    end
  end

  def card_selector_url(project_hash)
    url_for(
        :controller => 'card_explorer',
        :action => 'show_card_selector',
        :project_id => project_hash["identifier"],
        :card_selector => { :title => "Select Raising Card from #{project_hash['name']}"})
  end

end
