#!/usr/bin/env ruby
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

require File.dirname(__FILE__) + '/../../config/environment'
require File.join(Rails.root, '/script/definitions')

class LargeDataSet
  include Definitions

  today_is '14 Jan 2007'

  raise 'project name required' unless ARGV[0]
  define_project ARGV[0]
  
  define_card_types 'story', 'bug', 'enhancement', 'task', 'issue', 'risk'

  define_property 'release', 1, 2
  define_property 'iteration', 1..25
  define_property 'priority', 'urgent', 'high', 'medium', 'low'
  define_property 'status', 'new', 'open', 'in progress', 'done', 'accepted', 'fixed'
  define_property 'points', 1, 2, 4, 8, 16
  
  define_saved_view 'Iteration 1', {:filter_properties => {:cp_type => 'story', :cp_iteration => 1, :cp_release => 1}, :columns => 'cp_points,cp_status'}
  define_saved_view 'Iteration 2', {:filter_properties => {:cp_type => 'story', :cp_iteration => 2, :cp_release => 1}, :columns => 'cp_points,cp_status'}
  define_saved_view 'Iteration 3', {:filter_properties => {:cp_type => 'story', :cp_iteration => 3, :cp_release => 1}, :columns => 'cp_points,cp_status'}
  define_saved_view 'Iteration 4', {:filter_properties => {:cp_type => 'story', :cp_iteration => 4, :cp_release => 1}, :columns => 'cp_points,cp_status'}
  define_saved_view 'Release 1', {:filter_properties => {:cp_release => 1}, :columns => 'cp_type,cp_points,cp_status'}
  define_saved_view 'Release 2', {:filter_properties => {:cp_release => 2}, :columns => 'cp_type,cp_points,cp_status'}

  define_transition 'Play', :has_tags => ['type-story', 'status-new'], :add_tags => ['status-open']
  define_transition 'Sign-up', :has_tags => ['type-story', 'status-open'], :add_tags => ['status-in progress']
  define_transition 'Complete', :has_tags => ['type-story', 'status-in progress'], :add_tags => ['status-complete']
  define_transition 'Accept', :has_tags => ['type-story', 'status-complete'], :add_tags => ['status-accepted']
  
  define_transition 'Escalate', :has_tags => ['type-bug', 'status-new'], :add_tags => ['status-open']
  define_transition 'Fix', :has_tags => ['type-bug', 'status-open'], :add_tags => ['status-fixed']
  define_transition 'Done', :has_tags => ['type-bug', 'status-fixed'], :add_tags => ['status-done']
  define_transition 'Close', :has_tags => ['type-bug', 'status-done'], :add_tags => ['status-closed']

  define_standard_dashboard

  (1..200).each { |page_number| generate_page(page_number) }
  
  on '15 Dec 2006' do
    200.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-1'}
  end
    
  on '1 Jan 2007' do
    200.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-1'}
  end
  
  on '10 Jan 2007' do
    300.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-1'}
  end
  
  on '25 Jan 2007' do
    300.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-1'}
  end
    
  on '30 Jan 2007' do
    200.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-1'}
    200.times {generate_story "As a #{random_user}, I want to #{do_random_action}, so that #{gain_random_benefit}", 'release-2'}
  end  
  
  play_iteration 1, :for_cards => 1..40, :between => ['1 Jan 2007', '7 Jan 2007'], :generate_bugs => 30
  play_iteration 2, :for_cards => 41..80, :between => ['8 Jan 2007', '14 Jan 2007'], :generate_bugs => 50 
  play_iteration 3, :for_cards => 81..120, :between => ['15 Jan 2007', '21 Jan 2007'], :generate_bugs => 50
  play_iteration 4, :for_cards => 121..160, :between => ['22 Jan 2007', '28 Jan 2007'], :generate_bugs => 30
  play_iteration 5, :for_cards => 161..200, :between => ['29 Jan 2007', '4 Feb 2007'], :generate_bugs => 20
  play_iteration 6, :for_cards => 201..240, :between => ['5 Feb 2007', '11 Feb 2007'], :generate_bugs => 30
  play_iteration 7, :for_cards => 241..280, :between => ['12 Feb 2007', '18 Feb 2007'], :generate_bugs => 40
  play_iteration 8, :for_cards => 281..320, :between => ['19 Feb 2007', '25 Feb 2007'], :generate_bugs => 50
  play_iteration 9, :for_cards => 321..360, :between => ['26 Feb 2007', '4 Mar 2007'], :generate_bugs => 50
  play_iteration 10, :for_cards => 361..400, :between => ['5 Mar 2007', '11 Mar 2007'], :generate_bugs => 40
  play_iteration 11, :for_cards => 401..440, :between => ['12 Mar 2007', '18 Mar 2007'], :generate_bugs => 40
  play_iteration 12, :for_cards => 441..480, :between => ['19 Mar 2007', '25 Mar 2007'], :generate_bugs => 50
  play_iteration 13, :for_cards => 481..520, :between => ['26 Mar 2007', '1 Apr 2007'], :generate_bugs => 50
  play_iteration 14, :for_cards => 521..560, :between => ['2 Apr 2007', '8 Apr 2007'], :generate_bugs => 50
  play_iteration 15, :for_cards => 561..600, :between => ['9 Apr 2007', '15 Apr 2007'], :generate_bugs => 40
  play_iteration 16, :for_cards => 601..640, :between => ['16 Apr 2007', '22 Apr 2007'], :generate_bugs => 40
  play_iteration 17, :for_cards => 641..680, :between => ['23 Apr 2007', '29 Apr 2007'], :generate_bugs => 40
  play_iteration 18, :for_cards => 681..720, :between => ['30 Apr 2007', '6 May 2007'], :generate_bugs => 50
  play_iteration 19, :for_cards => 721..760, :between => ['7 May 2007', '13 May 2007'], :generate_bugs => 70
  play_iteration 20, :for_cards => 761..800, :between => ['14 May 2007', '20 May 2007'], :generate_bugs => 90
  play_iteration 21, :for_cards => 801..840, :between => ['21 May 2007', '27 May 2007'], :generate_bugs => 90
  play_iteration 22, :for_cards => 841..880, :between => ['28 May 2007', '3 Jun 2007'], :generate_bugs => 60
  play_iteration 23, :for_cards => 881..920, :between => ['4 Jun 2007', '10 Jun 2007'], :generate_bugs => 20
end

