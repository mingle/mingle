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

class TableSequence < ActiveRecord::Base  
  def next
    seq = refind_with_lock
    seq.last_value ||= 0
    seq.last_value += 1
    seq.save!
    update_last_value_from_sequence(seq)
    seq.last_value
  end
  
  def reset_to(value)
    seq = refind_with_lock
    seq.update_attributes(:last_value => value) unless seq.last_value == value
    update_last_value_from_sequence(seq)
  end
  
  def reserve(count)
    seq = refind_with_lock
    seq.last_value ||= 0
    first_reserved = seq.last_value + 1
    seq.update_attributes(:last_value => seq.last_value + count)
    update_last_value_from_sequence(seq)
    first_reserved
  end
  
  def current
    last_value || 0
  end
  
  private
  
  def refind_with_lock
    self.class.find(:all, :conditions => {:name => name}, :lock => true).first
  end
  
  def update_last_value_from_sequence(sequence)
    self.last_value = sequence.last_value
  end
end
