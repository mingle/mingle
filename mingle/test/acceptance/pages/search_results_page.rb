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

module SearchResultsPage
  
  def card_link_on_result(card)
    card_model?(card) ? "#{card.card_type_name} ##{card.number} #{card.name}" : "#{card[:card_type_name]} ##{card[:number]} #{card[:name]}" 
  end
  
  def assert_card_present_in_search_results(card)
    @browser.assert_text_present(card.respond_to?(:name) ? card.name : card[:name])

  end
  def assert_card_not_present(card)
    @browser.assert_text_not_present(card.respond_to?(:name) ? card.name : card[:name])
  end

  
  def assert_count_of_search_results_found(resultcount)
    @browser.assert_element_matches(result_count_id, /#{resultcount} .*/)
  end
  
  def assert_search_message_states_no_results_returned(search_text)
      @browser.assert_element_matches(result_count_id, /No .* #{search_text}./)
  end
  
  def assert_murmurs_search_result(message)
    @browser.assert_element_matches(murmur_result_id, /#{message}/ )
  end
  
  
  def should_see_murmurs_link(linked_text)
     @browser.assert_element_present(murmurs_link(linked_text))  
  end
  
  
  def should_not_see_murmurs(*messages)
    messages.each do |message|
      @browser.assert_text_not_present(message)
    end
  end
  
  def assert_no_search_results_found
    @browser.assert_text_present('No results found')
  end
end
