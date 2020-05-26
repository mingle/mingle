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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'cards_controller'

class CardShowTest < Test::Unit::TestCase
  
  LOGIN = 'djrice'
  
  def setup
    @controller = create_controler CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new      
    login(User.find_by_login(LOGIN).email)
  end
  
  def teardown
    Project.current.deactivate rescue nil
  end  
  
  def test_card_show
    runs = 3
    
    get :show, :project_id => 'mingle', :number => '2701'
    start = Time.new
    runs.times do 
      get :show, :project_id => 'mingle', :number => '2701'
    end
    puts "#{runs} times >>>> #{Time.now - start}"
  end
  

  
end
