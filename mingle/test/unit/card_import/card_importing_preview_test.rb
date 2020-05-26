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

class CardImportingPreviewTest < ActiveSupport::TestCase

  def setup
    @project = create_project
    login_as_member
    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @raw_excel_content_file_path = @excel_content_file.pathname
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_should_mark_queued_after_created_card_importing_preview
    import_text = %{name
      card name
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    assert_equal "queued", preview.status
  end

  def test_process_preview
    import_text = %{Number\tShouldBeDescription
      1\tNew Description for Card One
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    assert_nil preview.mapping
    assert_equal 'queued', preview.status

    preview.process!

    assert_equal({'Number' => 'number', 'ShouldBeDescription' => 'description'}, preview.progress.reload.mapping)
    assert_equal ["Importing excel content...", "Analysing header #{'Number'.italic} (Completed 0 of 2)", "Analysing header #{'ShouldBeDescription'.italic} (Completed 1 of 2)", "Validating..."], preview.progress_messages
    assert_equal 1, preview.progress_percent
    assert preview.completed?
    assert !preview.failed?
    assert_equal 'completed successfully', preview.status
  end
  
  def test_should_catch_validation_errors_while_processing_preview
    import_text = %{Number
      xx
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)

    preview.process!

    assert_nil preview.mapping
    assert_equal ["Importing excel content...", 
      "Analysing header #{'Number'.italic} (Completed 0 of 1)", 
      "Validating...", 
      "Cards were not imported. #{'xx'.bold} is not a valid card number."], preview.progress_messages
    assert_equal 1, preview.progress_percent
    assert preview.completed?
    assert preview.failed?
    assert_equal ["Cards were not imported. #{'xx'.bold} is not a valid card number."], preview.error_details
    assert_equal 'completed failed', preview.status
  end
  
  # bug4006
  def test_should_not_show_error_when_card_type_not_set
    import_text = %{Number\tType
      1\tCard
      2\t
    }
    write_content(import_text)
    
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    preview.process!
    assert_equal [], preview.error_details
    assert !preview.failed?
  end
  
  # bug 8251
  def test_should_show_error_when_user_tries_to_create_property_with_same_name_as_predefined_property
    ["project", "Project_Card_Rank", "project card rank", "created_on", "created on", "modified_on", "Modified on"].each do |reserved_word|
      import_text = %{Number\tType\t#{reserved_word}
        1\tCard\tsomevalue
      }
      write_content(import_text)
      preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
      preview.process!
      assert_equal ["Unable to create property #{reserved_word.bold}. Property Name #{reserved_word.bold} is a reserved property name."], preview.error_details
    end
  end
  
  # bug 8619
  def test_should_show_error_when_user_tries_to_create_property_with_a_newline_character
    import_text = %{Number\tType\t"this has\na newline"
      1\tCard\tsomevalue
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    preview.process!
    assert_equal ["Unable to create property #{'this has\\na newline'.bold}. It contains a newline or carriage return character."], preview.error_details
  end
  
  # bug 8619
  def test_should_show_error_when_user_tries_to_create_property_with_a_carriage_return_character
    import_text = %{Number\tType\t"this has\ra carriage return"
      1\tCard\tsomevalue
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    preview.process!
    assert_equal ["Unable to create property #{'this has\\ra carriage return'.bold}. It contains a newline or carriage return character."], preview.error_details
  end
  
  # bug 8619 -- this case is different than just newline or cr alone, because prop def strips out two whitespace chars in a row and that changes the logic
  def test_should_show_error_when_user_tries_to_create_a_property_with_a_carriage_return_followed_by_a_newline
    import_text = %{Number\tType\t"this has\r\na newline"
      1\tCard\tsomevalue
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    preview.process!
    assert_equal ["Unable to create property #{'this has\\r\\na newline'.bold}. It contains a newline or carriage return character."], preview.error_details
  end
  
  
  def test_process_should_update_progress_message_when_error_happens
    import_text = %{name
      card name
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    progress = preview.progress
    def progress.update_mapping_with(foo)
      raise 'Ops'
    end
    assert_nothing_raised { preview.process! }
    assert_equal 1, preview.progress.error_count
    assert_equal ["Importing excel content...",
     "Analysing header #{'name'.italic} (Completed 0 of 1)",
     "Validating...",
     "Ops"], preview.progress.progress_messages
  end
  
  private
  
  def write_content(content)
    @excel_content_file.write(content)
  end
  
end
