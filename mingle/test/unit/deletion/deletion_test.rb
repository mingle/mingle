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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class DeletionTest < ActiveSupport::TestCase
  class ModelMock
    
    def initialize(blocking_reasons, deletion = nil)
      @blocking_reasons = blocking_reasons
      @deletion = deletion
    end
    
    def deletion_blockings
      @blocking_reasons
    end
    
    def deletion
      @deletion
    end
  end
  
  def test_can_delete_should_be_false_when_model_has_blocking_reasons
    deletion = Deletion.new(ModelMock.new(["something is bad there"]))
    assert !deletion.can_delete?
  end
  
  def test_can_have_components
    components = []
    component1 = ModelMock.new(['component1 blocking reason'],
                                Deletion.new( ModelMock.new(['node reason']) ))
    components << component1
    
    deletion = Deletion.new(ModelMock.new(["parent deletion reason"]), components)
    assert_equal [component1.deletion], deletion.deletions
    assert deletion.blocked?
    assert !deletion.node?
  end
  
  def test_deletions_should_not_include_non_blocked_sub_deletions
    components = []
    component1 = ModelMock.new(['component1 blocking reason'],
                                Deletion.new( ModelMock.new(['node reason'])) )
    non_blocked_deletion = Deletion.new( ModelMock.new([]))
    component2 = ModelMock.new([], non_blocked_deletion)
    
    components << component1 << component2
    
    deletion = Deletion.new(ModelMock.new(["parent deletion reason"]), components)
    assert_equal [component1.deletion], deletion.deletions
  end
  
end
