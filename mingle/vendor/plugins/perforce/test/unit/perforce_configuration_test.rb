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

class PerforceConfigurationTest < ActiveSupport::TestCase
  
  def setup
    @project = create_project
    @p4_opts = {:username => "ice_user", :host=> "localhost", :port=> "1666", :repository_path =>"//depot/..."}

    init_p4_driver_and_repos
    
    login_as_admin
  end

  def teardown
    @project.deactivate rescue nil
    @driver.teardown if @driver
  end
  
  def test_should_figure_out_right_repository_depot_name_when_it_starts_with_some_slashs
    config = PerforceConfiguration.new({:project => @project}.merge(@p4_opts.merge(:repository_path => "\\\\depot")))
    assert_equal '//depot', config.repository_path
    config = PerforceConfiguration.new({:project => @project}.merge(@p4_opts.merge(:repository_path => "//depot")))
    assert_equal '//depot', config.repository_path
  end

  def test_repository_access
    config = new_one
    assert_not_nil config.repository
  end

  def test_validity
    config = PerforceConfiguration.new({:project => @project})
    assert !config.valid?
  end
  
  def test_repository_location_changed
    config = new_one
    assert !config.repository_location_changed?(@p4_opts)
    assert config.repository_location_changed?(@p4_opts.merge(:port => 'new'))
    assert config.repository_location_changed?(@p4_opts.merge(:repository_path => 'new'))
    assert config.repository_location_changed?(@p4_opts.merge(:host => 'new'))
  end
  
  def test_should_throw_exception_when_changelist_number_does_not_exist
    config = PerforceConfiguration.new(@p4_opts.merge({:project => @project}))
    assert_raise(Repository::NoSuchRevisionError) do
      config.repository.revision(999)
    end
  end
  
  def test_clone_repository_options
    assert_equal @p4_opts.merge(:password => nil), new_one.clone_repository_options
  end

  def test_should_save_successfully_even_config_is_invalid
    config = new_one
    assert config.save
    config.port = "2000"
    assert config.save
  end
  
  def test_file_length
    config = new_one
    assert_equal 13, config.repository.node('dir1/b.txt').file_length
  end
  
  def test_depot_path_cannot_contain_asterisk
    config = new_one
    config.repository_path = '//de*ot'
    assert !config.valid?
    assert_equal "Repository path cannot contain *", config.errors.full_messages.join
  end
  
  def test_depot_path_cannot_contain_percent
    config = new_one
    config.repository_path = '//de%ot'
    assert !config.valid?
    assert_equal "Repository path cannot contain %", config.errors.full_messages.join
  end
  
  def test_depot_path_cannot_contain_at_sign
    config = new_one
    config.repository_path = '//de@ot'
    assert !config.valid?
    assert_equal "Repository path cannot contain @", config.errors.full_messages.join
  end
  
  def test_depot_path_gives_one_error_message_for_multiple_invalid_characters
    config = new_one
    config.repository_path = "//d@p%t"
    assert !config.valid?
    assert_equal "Repository path cannot contain % or @", config.errors.full_messages.join
  end
  
  def test_should_only_allow_ending_with_forward_slash_alpha_numeric_and_ellipses
    config = new_one
    assert_valid_repository_path(config, 'studio/')
    assert_valid_repository_path(config, 'studio')
    assert_valid_repository_path(config, 'studio1')
    assert_valid_repository_path(config, 'studio...')
    assert_valid_repository_path(config, 'depot1/ depot depot3 depot4...')
    assert_repository_path_has_depot_path_with_bad_ending(config, 'studio$')
    assert_repository_path_has_depot_path_with_bad_ending(config, 'studio.')
    assert_repository_path_has_depot_path_with_bad_ending(config, 'studio..')
    assert_repository_path_has_depot_path_with_bad_ending(config, 'good bad.. good2')
  end
  
  def test_should_only_allow_ellipses_at_end_of_depot_paths
    config = new_one
    assert_repository_path_cannot_contain_embedded_ellipses(config, '//depot/....rb')
    assert_repository_path_cannot_contain_embedded_ellipses(config, '//depot/...h')
    assert_valid_repository_path(config, '//studios... //depot...')
  end
  
  def test_should_only_allow_double_slash_at_beginning
    config = new_one
    assert_repository_path_cannot_contain_embedded_double_slashes(config, 'timmy //dep//ot tammy')
    assert_repository_path_cannot_contain_embedded_double_slashes(config, 'jimmy //depot//')
    assert_valid_repository_path(config, "//studios //depot")
  end
  
  def test_should_not_allow_only_double_slash
    config = new_one
    assert_repository_path_cannot_be_double_slash(config, '//')
    assert_repository_path_cannot_be_double_slash(config, 'depot //')
  end

  def test_source_browsing_ready_returns_true_for_perforce_configuration
    assert_equal true, new_one.source_browsing_ready?
  end
  
  def test_to_xml    
    config = PerforceConfiguration.new({:project => @project}.merge(@p4_opts.merge(:repository_path => "\\\\depot")))
    config.save!
    xml = config.to_xml(:version => "v2", :view_helper => OpenStruct.new(:rest_project_show_url => "url_for_project"))
    
    document = REXML::Document.new(xml)    
    assert_equal config.id.to_s, document.element_text_at("/perforce_configuration/id")
    assert_equal 'url_for_project', document.attribute_value_at("/perforce_configuration/project/@url")
    assert_equal ['identifier', 'name'], document.get_elements("/perforce_configuration/project/*").map(&:name).sort
    assert_equal "//depot", document.element_text_at("/perforce_configuration/repository_path")
    assert_equal 'ice_user', document.element_text_at("/perforce_configuration/username")
    assert_equal 'false', document.element_text_at("/perforce_configuration/marked_for_deletion")
    assert_equal 'localhost', document.element_text_at("/perforce_configuration/host")
    assert_equal '1666', document.element_text_at("/perforce_configuration/port")
  end
  
  private

  def new_one
    PerforceConfiguration.new({:project => @project}.merge(@p4_opts))
  end
  
  def assert_valid_repository_path(config, path)
    config.repository_path = path
    assert config.valid?
  end
  
  def assert_repository_path_has_depot_path_with_bad_ending(config, path)
    config.repository_path = path
    assert !config.valid?
    assert_equal "Repository path depot paths must each end in a letter, number, slash, or '...'", config.errors.full_messages.join
  end
  
  def assert_repository_path_cannot_contain_embedded_ellipses(config, path)
    config.repository_path = path
    assert !config.valid?
    assert_equal "Repository path '...' can only appear at the end of depot paths", config.errors.full_messages.join
  end
  
  def assert_repository_path_cannot_be_double_slash(config, path)
    config.repository_path = path
    assert !config.valid?
    assert_equal "Repository path depot paths cannot be only '//'", config.errors.full_messages.join
  end
  
  def assert_repository_path_cannot_contain_embedded_double_slashes(config, path)
    config.repository_path = path
    assert !config.valid?
    assert_equal "Repository path '//' can only appear at the beginning of depot paths", config.errors.full_messages.join
  end
    
end


