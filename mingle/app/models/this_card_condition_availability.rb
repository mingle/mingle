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

module ThisCardConditionAvailability
  class Now < Struct.new(:content_provider)
    def validate(usage, alert_receiver)
    end
  end
  
  class Later < Struct.new(:content_provider)
    def validate(usage, alert_receiver)
      alert_receiver.alert(self.content_provider.this_card_condition_error_message(usage))
    end
  end
  
  class Never < Struct.new(:content_provider)
    def validate(usage, alert_receiver)
      raise CardQuery::DomainException.new(self.content_provider.this_card_condition_error_message(usage)) 
    end
  end 
end
