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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class Container
  include ::API::XMLSerializer

  serializes_as :content
  compact_at_level 1

  def content
    CustomSerializingContent.new
  end
end

class CustomSerializingContent
  include ::API::XMLSerializer
  uses_custom_serialization

  def to_xml(options={})
    b = options[:builder]
    b.tag!('customcontent', 'attr_name' => 'attr_value') do
      Book.new('The Call of the Wilderness', 'Mommy Dearest').to_xml(options)
    end
  end
end

class HashContainer
  include ::API::XMLSerializer

  serializes_as :hash

  def initialize(hash)
    @hash = hash
  end

  def hash; @hash; end
end

class Author
  include ::API::XMLSerializer

  v1_serializes_as :full_name
  v2_serializes_as :complete => [:name]

  def full_name; name; end
  def name; "Jack London"; end
end

class Comment
  include ::API::XMLSerializer

  serializes_as :message, :commentator
  conditionally_serialize :joke, :if => Proc.new { |comment| comment.message =~ /^joke/ }

  def initialize(message)
    @message = message
  end

  def message; @message; end
  def commentator; Author.new; end
  def joke; "Let me tell you a good joke!"; end
end

class ConditionallyModel
  include ::API::XMLSerializer

  conditionally_serialize :joke, :if => Proc.new { |comment| comment.message =~ /joke/ }
  conditionally_serialize :faint, :if => Proc.new { |comment| comment.message =~ /faint/ }

  def initialize(message)
    @message = message
  end

  def message; @message; end
  def joke; "Joke!"; end
  def faint; "Faint!"; end
end

class Post
  include ::API::XMLSerializer

  serializes_as :title, :id, :writer, :boo, :comments, :public?, :attr_need_xml_option

  def title; "blog post"; end
  def id; 10; end
  def boo; false; end
  def writer; Author.new; end
  def public?; false; end
  def comments; [Comment.new("foo"), Comment.new("bar")]; end
  def attr_need_xml_option(options); options[:body]; end
end

class Book
  include ::API::XMLSerializer

  serializes_as :complete => [:name, :author, :bibliography],
                :compact => [:name, :author]

  self.resource_link_route_options = proc { |book| {:isbn => book.isbn} }

  def initialize(name, author)
    @name = name
    @author = author
  end

  def name; @name; end
  def author; @author; end

  def bibliography
    [Book.new("Alaskan Wilderness", "J. London"), Book.new("Wolves and Men", "Jack L.")]
  end

  def isbn
    'ISBN675855FR553-5673'
  end
end

class Shelf
  include ::API::XMLSerializer

  serializes_as :complete => [:book]

  def initialize(book)
    @book = book
  end

  def book; @book; end
end

class CompactLevelParent
  include ::API::XMLSerializer
  serializes_as :child
  compact_at_level 2

  def child; CompactLevelChild.new; end
end

class CompactLevelParentInheritor < CompactLevelParent
end

class CompactLevelChild
  include ::API::XMLSerializer
  serializes_as :complete => [:complete_version, :child],
                :compact => [:compact_version]

  def complete_version; 'Complete version'; end
  def compact_version; 'Compact version'; end
  def child; CompactLevelChild.new; end
end

class CompactAtLevelZeroParent
  include ::API::XMLSerializer
  serializes_as :child
  compact_at_level 2

  def child; CompactAtLevelZero.new; end
end

class CompactAtLevelZero
  include ::API::XMLSerializer
  serializes_as :complete => [:complete_version],
                :compact => [:compact_version]
  compact_at_level 0
  def complete_version; 'Complete version'; end
  def compact_version; 'Compact version'; end
end

class SecondCompactAtLevelZero
  include ::API::XMLSerializer

  serializes_as :complete => [:child],
                :compact => [:child],
                :slack => [:slack_version, :child]
  compact_at_level 0

  def child; CompactAtLevelZero.new; end
  def slack_version; 'Second Slack version'; end
end

class SuperSerializable
  include ::API::XMLSerializer
  serializes_as :complete => [:attribute]

  def attribute; "super attribute"; end
end


class SubSerializable < SuperSerializable
  additionally_serialize :complete, [:additional]

  def attribute; "sub attribute"; end
  def additional; "additional"; end
end

class TimeSample
  include ::API::XMLSerializer
  serializes_as :sometime
  def sometime; Clock.now; end
end

class XMLSerializerTest < ActiveSupport::TestCase

  def setup
    def view_helper.rest_book_show_url(options={})
      "http://www.biblio.com/#{options[:isbn]}/#{options[:api_version]}"
    end
  end

  def teardown
    Clock.reset_fake
  end

  def test_should_have_xml_declaration_at_begining_of_xml
    assert_equal %{<?xml version="1.0" encoding="UTF-8"?>}, Author.new.to_xml.split("\n").first
  end

  def test_skip_instruct_for_default_xml_builder
    assert_equal_ignoring_spaces %{<author><name>Jack London</name></author>}, Author.new.to_xml(:skip_instruct => true)
  end

  def test_should_be_able_to_work_with_multi_conditionally_serializes_declarations
    assert_equal "Joke!", get_element_text_by_xpath(ConditionallyModel.new("joke and faint").to_xml, "//conditionally_model/joke")
    assert_equal "Faint!", get_element_text_by_xpath(ConditionallyModel.new("joke and faint").to_xml, "//conditionally_model/faint")
  end
  def test_should_serialize_simple_attributes_as_name_value_pairs
    assert_equal "Jack London", get_element_text_by_xpath(Author.new.to_xml, "//author/name")
  end

  def test_should_be_able_to_serialize_an_object_in_multiple_formats
    assert_equal "Jack London", get_element_text_by_xpath(Author.new.to_xml(:version => 'v1'), "//author/full_name")
    assert_equal "Jack London", get_element_text_by_xpath(Author.new.to_xml(:version => 'v2'), "//author/name")
  end

  def test_should_serialize_a_hash_as_key_value_pairs
    assert_equal "1", get_element_text_by_xpath(HashContainer.new(:one => 1, :two => 2).to_xml, "/hash_container/one")
    assert_equal "2", get_element_text_by_xpath(HashContainer.new(:one => 1, :two => 2).to_xml, "/hash_container/two")
  end

  def test_should_serialize_tags_from_hash_as_all_lower_case
    assert_equal "1", get_element_text_by_xpath(HashContainer.new(:One => 1, :Two => 2).to_xml, "/hash_container/one")
  end

  def test_should_be_able_to_link_to_an_entity
    book = Book.new("The Call of the Wild", "Jack London")
    assert_equal "http://www.biblio.com/ISBN675855FR553-5673/v1", get_attribute_by_xpath(book.to_xml(:view_helper => view_helper, :version => "v1"), "/book/bibliography/book[1]/@url")
  end

  def test_should_serialise_with_link_at_first_level
    shelf = Shelf.new(Book.new("The Call of the Wild", "Jack London"))
    assert_equal "http://www.biblio.com/ISBN675855FR553-5673/v2", get_attribute_by_xpath(shelf.to_xml(:view_helper => view_helper, :version => "v2"), "/shelf/book[1]/@url")
  end

  def test_should_not_blow_up_serializing_simple_attributes_if_they_are_null
    assert_nil get_element_text_by_xpath(Comment.new(nil).to_xml, "//comment/message")
  end

  def test_should_conditionally_serialize_additional_elements
    assert_equal 1, get_number_of_elements(Comment.new("jokes are cool").to_xml, "//comment/joke")
    assert_equal "Let me tell you a good joke!", get_element_text_by_xpath(Comment.new("jokes are cool").to_xml, "//comment/joke")
    assert_equal 0, get_number_of_elements(Comment.new("comedians suck").to_xml, "//comment/joke")
  end

  def test_should_serialize_attributes_with_serializable_value
    assert_equal "blog post", get_element_text_by_xpath(Post.new.to_xml, "//post/title")
    assert_equal "Jack London", get_element_text_by_xpath(Post.new.to_xml, "//post/writer/name")
    assert_equal "foo", get_element_text_by_xpath(Post.new.to_xml, "//post/comments/comment[1]/message").to_s
    assert_equal "bar", get_element_text_by_xpath(Post.new.to_xml, "//post/comments/comment[2]/message").to_s
  end

  def test_should_include_type_information_for_integer_fields
    assert_equal "integer", get_attribute_by_xpath(Post.new.to_xml, "//post/id/@type")
  end

  def test_should_include_type_information_for_boolean_fields
    assert_equal "boolean", get_attribute_by_xpath(Post.new.to_xml, "//post/boo/@type")
  end

  def test_should_use_compact_xml_format_when_generating_xml_for_arrayed_children_of_the_top_level_object
    book = Book.new("Badri's Guide to the Wild", "Badri Janakiraman")
    assert_equal "Badri's Guide to the Wild", get_element_text_by_xpath(book.to_xml, "/book/name")
    assert_equal 2, get_number_of_elements(book.to_xml, "/book/bibliography/book")

    assert_equal "Alaskan Wilderness", get_element_text_by_xpath(book.to_xml(), "/book//book[1]//book[1]/name")
    assert_equal 2, get_number_of_elements(book.to_xml, "/book//book[1]//book[1]/*")
  end

  def test_should_accept_attribute_end_with_question_mark
    assert_equal 'false', get_element_text_by_xpath(Post.new.to_xml, "//post/public")
  end

  def test_should_passin_serialization_options_to_attribute_method_need_arguement
    assert_equal '111', get_element_text_by_xpath(Post.new.to_xml({:body => '111'}), "//post/attr_need_xml_option")
  end

  def test_should_generate_complete_version_when_compact_at_level_is_set
    xml = CompactLevelParent.new.to_xml
    assert_equal 'Complete version', get_element_text_by_xpath(xml, "/compact_level_parent/child/complete_version")
    assert_equal 'Complete version', get_element_text_by_xpath(xml, "/compact_level_parent/child/child/complete_version")
    assert_equal 'Compact version', get_element_text_by_xpath(xml, "/compact_level_parent/child/child/child/compact_version")
  end

  def test_should_inherit_compact_level_at_from_base_class
    xml = CompactLevelParentInheritor.new.to_xml
    assert_equal 'Compact version', get_element_text_by_xpath(xml, "/compact_level_parent_inheritor/child/child/child/compact_version")
  end

  def test_should_be_able_compact_at_level_zero
    assert_equal 'Compact version', get_element_text_by_xpath(CompactAtLevelZeroParent.new.to_xml, "/compact_at_level_zero_parent/child/compact_version")
    assert_equal 'Complete version', get_element_text_by_xpath(CompactAtLevelZero.new.to_xml, "/compact_at_level_zero/complete_version")
  end

  def test_should_fetch_slack_attributes
    assert_equal 'Second Slack version', get_element_text_by_xpath(SecondCompactAtLevelZero.new.to_xml(:slack => true), "/second_compact_at_level_zero/slack_version")
    assert_equal 'Compact version', get_element_text_by_xpath(SecondCompactAtLevelZero.new.to_xml, "/second_compact_at_level_zero/child/compact_version")
  end

  def test_should_ignore_slack_attributes_if_compact_level_exceeded
    assert_equal 'Compact version', get_element_text_by_xpath(SecondCompactAtLevelZero.new.to_xml(:slack => true), '/second_compact_at_level_zero/child/compact_version')
    assert_equal 'Second Slack version', get_element_text_by_xpath(SecondCompactAtLevelZero.new.to_xml(:slack => true), '/second_compact_at_level_zero/slack_version')
    assert_equal 'Compact version', get_element_text_by_xpath(SecondCompactAtLevelZero.new.to_xml(:slack => true), '/second_compact_at_level_zero/child/compact_version')
  end

  def test_should_inheret_serialization_options_to_subclass
    xml = SubSerializable.new.to_xml
    assert_equal "sub attribute", get_element_text_by_xpath(xml, "/sub_serializable/attribute")
  end

  def test_subclass_can_add_additional_attribute_to_complete
    xml = SubSerializable.new.to_xml
    assert_equal "additional", get_element_text_by_xpath(xml, "/sub_serializable/additional")
  end

  class ModelWithCustomRootElementName
    include ::API::XMLSerializer
    serializes_as :complete => [], :element_name => 'customized_element_name'
  end

  def test_should_be_able_to_specify_element_name
    assert_equal 'customized_element_name', get_root_element_name(ModelWithCustomRootElementName.new.to_xml)
  end

  def test_should_include_custom_attributes
    assert_equal "true", get_attribute_by_xpath(Post.new.to_xml(:attribute_options => {:hidden => true}), "//post/@hidden")
    assert_equal [], get_elements_by_xpath(Post.new.to_xml(:attribute_options => {:hidden => true}), "//post/comments/comment[message='foo']/@hidden")
  end

  class EnumerableSample; include Enumerable end

  def test_should_have_array_type_for_has_many_resources
    book = Book.new("The Call of the Wild", "Jack London")
    assert_equal "array", get_attribute_by_xpath(book.to_xml, "/book/bibliography/@type")
    def book.bibliography; EnumerableSample.new end
    assert_equal "array", get_attribute_by_xpath(book.to_xml, "/book/bibliography/@type")
  end

  class ModelWithCustomPropertyElementName
    include ::API::XMLSerializer
    serializes_as :complete => [[:property, {:element_name => 'customized_property_element_name'}]], :element_name => 'customized_element_name'
    def property; 'foo bar' end
  end

  def test_should_be_able_to_customize_element_name_for_properties
    xml = ModelWithCustomPropertyElementName.new.to_xml
    assert_equal 'foo bar', get_element_text_by_xpath(xml, "/customized_element_name/customized_property_element_name")
  end

  def test_should_serialize_time_in_correct_format
    Clock.fake_now :year => 2009, :month => 9, :day => 3, :hour => 19, :min => 52, :sec => 34
    xml = TimeSample.new.to_xml
    assert_equal '2009-09-03T19:52:34Z', get_element_text_by_xpath(xml, "/time_sample/sometime")
    assert_equal 'datetime', get_attribute_by_xpath(xml, "/time_sample/sometime/@type")
  end

  def test_to_xml_for_active_record_error_should_strip_tags_from_values
    errors = ActiveRecord::Errors.new('base')
    errors.add_to_base('error <b>this</b> is wrong<br/>')
    assert_equal "error this is wrong", get_element_text_by_xpath(errors.to_xml, "/errors/error")
  end

  def test_can_serialize_with_completely_custom_content
    assert_equal 1, get_number_of_elements(Container.new.to_xml, '/container/customcontent')
    assert_equal 'attr_value', get_attribute_by_xpath(Container.new.to_xml, '/container/customcontent/@attr_name')
  end

  def test_deeply_nested_elements_within_custom_serializing_children_still_understand_when_they_should_be_compacted
    xml = Container.new.to_xml(:view_helper => view_helper)
    assert_equal 'http://www.biblio.com/ISBN675855FR553-5673/', get_attribute_by_xpath(xml, '/container/customcontent/book/@url')
  end

  def test_should_not_have_nil_url_attribute
    xml = Author.new.to_xml(:view_helper => view_helper, :compact => true)
    assert_equal 0,  get_number_of_elements(xml, "/author/@url")
  end
end
