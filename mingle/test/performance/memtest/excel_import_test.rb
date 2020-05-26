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

RAILS_ENV='test'
require File.dirname(__FILE__) + '/../../config/environment'

User.first_admin.with_current do
  p = Project.create!(:name => "excel_import_#{Time.now.to_i}", :identifier => "excel_import_#{Time.now.to_i}")
  p.with_active_project do
    Benchmark.bm do |bm|
      bm.report('excel import') do
        p.transaction do
          p.import_tab_separated_cards(File.read(File.dirname(__FILE__) + '/excel_import.csv'))
        end
      end
    end
  end
end
