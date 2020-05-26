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

module PlannerForecastHelper
   def not_likely_forecast(objective, project)
     Plan::Forecast.new(objective).for(project)[:not_likely]
   end

   def not_likely_forecast_date(objective, project)
     not_likely_forecast(objective, project).date.strftime("%m-%d-%Y")
   end

   def assign_card(card_number, objective)
     @plan.assign_cards(@project, [card_number], objective)
   end

   def close_card(card_number)
     @project.with_active_project do |project|
       card = project.cards.find_by_number(card_number)
       card.update_properties(:status => "closed")
       card.save!
     end
   end

   def fake_now(year, month, day, hour = 0)
     Clock.fake_now(:year => year, :month => month, :day => day, :hour => hour)
   end
end
