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

class DepotsTest < ActiveSupport::TestCase

  def test_depots_path
    assert_equal '//studios...', PerforceRepository.create_depots('//studios...').path
    assert_equal '//studios...', PerforceRepository.create_depots('//studios.').path
    assert_equal '//studios...', PerforceRepository.create_depots('//studios..').path
    assert_equal '//studios', PerforceRepository.create_depots('studios').path
    assert_equal '//studios/', PerforceRepository.create_depots('studios/').path
    assert_equal '//studios //depot', PerforceRepository.create_depots('studios depot').path
    assert_equal '//studios //depot', PerforceRepository.create_depots('//studios depot').path
    assert_equal '//studios //depot', PerforceRepository.create_depots('//studios //depot').path
    assert_equal '//studios... //depot', PerforceRepository.create_depots('//studios... //depot').path
    assert_equal '//studios... //depot/...', PerforceRepository.create_depots('/studios... /depot/...').path
    assert_equal '//studios/sandbox... //depot/...', PerforceRepository.create_depots('/studios/sandbox... /depot/...').path

    assert_equal '//studios... //studios/xx/...', PerforceRepository.create_depots('//studios... //studios/xx/...').path
  end
  
  def test_root_path
    assert_equal '//studios', PerforceRepository.create_depots('//studios...').root_path
    assert_equal '//studios', PerforceRepository.create_depots('//studios').root_path
    assert_equal '//studios', PerforceRepository.create_depots('//studios/').root_path
    assert_equal '//studios', PerforceRepository.create_depots('//studios/...').root_path
    assert_equal '//studios', PerforceRepository.create_depots('//studios/*').root_path

    assert_equal '//', PerforceRepository.create_depots('//studios... //depot').root_path
    assert_equal '//', PerforceRepository.create_depots('//studios... //depot/xx/...').root_path
  end
  
  def test_root_path_with_path_specified
    assert_equal '//depot', PerforceRepository.create_depots('//depot/').root_path('//depot')
    assert_equal '//depot', PerforceRepository.create_depots('//depot/').root_path('depot')
    
    assert_equal '//depot/file.txt', PerforceRepository.create_depots('//depot/file.txt').root_path('//depot/file.txt')
    assert_equal '//depot/xx', PerforceRepository.create_depots('//depot/xx/...').root_path('//depot/xx/dir/file.txt')
    assert_nil PerforceRepository.create_depots('//depot/xx/...').root_path('//depot/not_exist/dir/file.txt')
    assert_equal '//depot/xx/dir1', PerforceRepository.create_depots('//depot/xx/dir1...').root_path
    assert_nil PerforceRepository.create_depots('//depot/xx/dir1...').root_path('//depot/xx/')
    
    assert_equal '//depot', PerforceRepository.create_depots('//studios... //depot/xx/...').root_path('//depot/xx/dir/file.txt')

    assert_nil PerforceRepository.create_depots('//depot/xx/dir1... //depot/xx/dir2...').root_path('//depot/xx/')
    assert_equal '//', PerforceRepository.create_depots('//depot/xx/dir1... //depot/xx/dir2...').root_path('//')
    assert_equal '//', PerforceRepository.create_depots('//depot/xx/dir1... //depot/xx/dir2...').root_path('/')

    # assert_equal '//studios/', PerforceRepository.create_depots('//studios... //studios/xx/...').root_path('studios/xx/file.txt')
    # assert_equal '//studios/xx', PerforceRepository.create_depots('//studios... //studios/xx/...').root_path('xx/file.txt')
  end
  
  def test_correct_path
    assert_equal '//studios/', PerforceRepository.create_depots('//studios...').send(:correct_path, '')
    assert_equal '//studios/file.txt', PerforceRepository.create_depots('//studios...').send(:correct_path, 'file.txt')
    assert_equal '//studios/file.txt', PerforceRepository.create_depots('//studios...').send(:correct_path, 'studios/file.txt')
    assert_equal '//studios/file.txt', PerforceRepository.create_depots('//studios...').send(:correct_path, '//studios/file.txt')
    assert_equal '//studios/file.txt', PerforceRepository.create_depots('studios').send(:correct_path, '//studios/file.txt')
  end
end
