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

module UpgradeTestHelper

  ORACLE = 'oracle'
  POSTGRES = 'postgres'
  MYSQL = 'mysql'
  
  #CONFIG_FILE = "test/upgrade_test_automation/config/target_db.yml"
  CONFIG_FILE = "config/target_db.yml"
  TEMPLATE1 = 'Agile hybrid template(2.3)'
  TEMPLATE2 = 'Story tracker template(2.3)'
  TEMPLATE3 = 'Scrum template(2.3)'
  TEMPLATE4 = 'Xp template(2.3)'
  
  #this css_locator is different
  def my_css_locator(css, index=0)
    %{dom=this.browserbot.getCurrentWindow().$$('#{css}')[#{index}]}
  end
  
  def log_in_upgraded_instance_as_admin
    log_in_upgraded_instance('admin', 'a')
  end
  
  def log_in_upgraded_instance(name, password)
    @browser.type "user_login", name
    @browser.type "user_password", password
    @browser.click_and_wait "name=commit"
  end
  
  def preview_the_excel_import(excel_copy_string)  
    click_import_from_excel
    @browser.type 'tab_separated_import', excel_copy_string    
    @browser.click 'link=Next to preview'
    @browser.wait_for_all_ajax_finished
  end
  
  def import_excel_data_from_preview
    @browser.click 'link=Next to complete import'
    @browser.wait_for_all_ajax_finished
  end 
  
  def data_config
    @data_config ||= YAML.load(File.open(CONFIG_FILE))    
  end

  def database
    data_config["test"]["database"]
  end
  
  # def get_version_to_number
  #   # raise ">>>>>>VERSION_FROM required!<<<<<<" if ARGV[1].nil?
  #   # raise ">>>>>>VERSION_TO required!<<<<<<" if ARGV[2].nil?
  #   # # @version_from = ARGV[1].tr("VERSION_FROM=", '')
  #   # vf = ARGV[1].tr("VERSION_FROM=", '')
  #   # vt = ARGV[2].tr("VERSION_TO=", '')
  #   vf = data_config["test"]["version_from"]
  #   vt = data_config["test"]["version_to"]
  #   case vf
  #   when "2.1"
  #     @version_from="2_1"
  #   when "2.2"
  #     @version_from="2_2"
  #   when "2.3"
  #     @version_from='2_3'
  #   when "2.3.1"
  #     @version_from="2_3_1"
  #   else
  #     p "no I cannot support upgrde from #{vf}"
  #   end
  #   
  #   case vt
  #   when "2.1"
  #     @version_to="2_1"
  #   when "2.2"
  #     @version_to="2_2"
  #   when "2.3"
  #     @version_to="2_3"
  #   when "2.3.1"
  #     @version_to="2_3_1"
  #   else
  #     p "no I cannot support upgrde to #{vt}"
  #   end
  # end
  
  def version_to_number
    vt = data_config["test"]["version_to"]
    case vt
    when "2.1" 
      return "2_1"
    when "2.2" 
      return "2_2"
    when "2.3" 
      return "2_3"
    when "2.3.1" 
      return "2_3_1"
    else 
      p "cannot find version_to number: #{vt}"
    end
  end
  
  def version_from_number
    vf = data_config["test"]["version_from"]
    case vf
    when "2.1" 
      return "2_1"
    when "2.2" 
      return "2_2"
    when "2.3" 
      return "2_3"
    when "2.3.1" 
      return "2_3_1"
    else 
      p "cannot find version_from number: #{vf}"
    end
  end
  
  
  def get_project_name
    vf = version_from_number

    case database
    when ORACLE
      return "project_#{vf}_oracle_project"
    when POSTGRES
      return "postgres_#{vf}"
    when MYSQL
      return "mysql_#{vf}"
    else
      p "cannot find the project name!!"      
   end
  end
  
  def get_test_data_dir
    return "#{data_config["test_dataDir"]}"
  end 
  
end
