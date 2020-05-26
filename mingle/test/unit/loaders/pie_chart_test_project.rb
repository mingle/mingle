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

module Loaders
  class PieChartTestProject

    def execute
      UnitTestDataLoader.delete_project('pie_chart_test_project')
      Project.create!(:name => 'pie_chart_test_project', :identifier => 'pie_chart_test_project', :corruption_checked => true).with_active_project do |project|
        project.update_attributes(:precision => 3)
        project.add_member(user('member'))
        project.add_member(user('bob'))
        project.card_types.create(name: 'Story')
        UnitTestDataLoader.setup_property_definitions(:old_type => ['Story'],
          :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'])
        UnitTestDataLoader.setup_text_property_definition('text_feature')
        UnitTestDataLoader.setup_date_property_definition('date_created')
        UnitTestDataLoader.setup_numeric_property_definition('size', ['1', '2', '3'])
        UnitTestDataLoader.setup_numeric_property_definition('accurate_estimate', ['1.00', '1.1234', '2.2345', '3.6666', '4.6779'])
        UnitTestDataLoader.setup_numeric_text_property_definition('inaccurate_estimate')
        UnitTestDataLoader.setup_user_definition("owner")
        project.update_attributes(:date_format => "%Y-%m-%d")
        UnitTestDataLoader.setup_formula_property_definition('size_times_two', 'size * 2')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '1'}, :size => '3', :accurate_estimate => '1.1234', :inaccurate_estimate => '1.0',:date_created => '2007-01-01', :feature => 'Dashboard', :text_feature => 'Dashboard', :owner => user('member').id )
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '2'}, :size => '2', :accurate_estimate => '2.2345', :inaccurate_estimate => '1.000', :date_created => '2007-01-02', :feature => 'Applications', :text_feature => 'Applications', :owner => user('member').id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '3'}, :size => '3', :accurate_estimate => '3.6666', :inaccurate_estimate => '2.03', :date_created => '2007-01-02', :feature => 'Rate calculator', :text_feature => 'Rate calculator', :owner => user('bob').id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '4'}, :size => '2', :accurate_estimate => '4.6779', :inaccurate_estimate => '2', :date_created => '2007-01-03', :feature => 'Dashboard', :text_feature => 'Dashboard', :owner => user('bob').id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '5'}, :size => '3', :accurate_estimate => '1.1234', :inaccurate_estimate => '0.5', :date_created => '2007-01-03', :feature => 'Profile builder', :text_feature => 'Profile builder', :owner => user('bob').id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '6'}, :size => '1', :accurate_estimate => '2.2345', :inaccurate_estimate => '0.500', :date_created => '2007-01-03', :feature => 'Dashboard', :text_feature => 'Dashboard', :owner => user('bob').id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => '7'}, :size => '3', :accurate_estimate => '1.00', :inaccurate_estimate => '0.5', :date_created => '2007-01-04', :feature => 'Dashboard', :text_feature => 'Dashboard')
      end
    end

    def user(login)
      User.find_by_login(login)
    end

  end
end
