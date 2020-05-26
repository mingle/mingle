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

class UrlUtilsTest < ActiveSupport::TestCase
  include UrlUtils

  def test_prepend_domain_in_url
    assert_equal "https://foo.example.com:8443/somewhere", prepend_domain_in_url("https://example.com:8443/somewhere", "foo")
  end

  def test_validate_weird_url_that_mri_does_not
    requires_jruby do
      assert_valid_url 'http://1coolboymachine:1234/foo'
      assert_valid_url 'http://123'
    end
  end

  def test_validating_format
    requires_jruby do
      assert_invalid_url 'sss'
      assert_invalid_url 'zxx\:123.com'
    end

    assert_valid_url 'http://mingle.phoenixchu.com:8060/projects/cards'
    assert_valid_url 'https://mingle.phoenixchu.com/projects/cards'
  end

  def test_validating_protocols
    requires_jruby do
      assert_invalid_url 'notexist://123.com/1.exe'
    end
    assert_valid_url 'ftp://123.com/1.exe', :allowed_protocols => ['http', 'ftp']
    assert_invalid_url 'ftp://123.com/1.exe', :allowed_protocols => ['http']
    assert_invalid_url 'https://123.com/1.exe', :allowed_protocols => ['http']
    assert_valid_url 'https://123.com/1.exe', :allowed_protocols => ['http', 'https']
    assert_invalid_url 'http://secure.example.com:8443', :allowed_protocols => ['https']
  end

  def test_validating_localhost
    assert_valid_url 'http://localhost:3000'
    assert_invalid_url 'http://localhost:3000', :disallow_localhost => true

    assert_valid_url 'http://127.0.0.1:3000'
    assert_invalid_url 'http://127.0.0.1:3000', :disallow_localhost => true
  end

  private

  def assert_valid_url(url, validation_options={})
    assert_equal [], validate_url(url, validation_options), "url should be valid but it is not"
  end

  def assert_invalid_url(url, validation_options={})
    assert !validate_url(url, validation_options).empty?, "url should be invalid but it is not"
  end

end
