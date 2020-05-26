# -*- coding: utf-8 -*-

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

class UserIconsTest < ActiveSupport::TestCase
  def setup
    @user_icons = UserIcons.new(view_helper)
  end

  def test_should_generate_file_column_url_if_user_uploaded_an_icon
    user = create_user!(:icon => sample_attachment("user_icon.jpg"))
    assert_equal user.icon_path, @user_icons.url_for(user)
  end

  def test_default_user_icon_should_be_based_on_name_initial
    assert_equal 'avatars/j.png', @user_icons.url_for(create_user!(:name => 'jdoe', :email => nil))
    assert_equal 'avatars/v.png', @user_icons.url_for(create_user!(:name => 'Victor Frankenstein', :email => nil))
  end

  def test_default_icon_should_fallback_to_silhouette
    assert_equal UserIcons::FALLBACK_ICON, @user_icons.url_for(create_user!(:name => 'Ω', :email => nil))
  end

  def test_when_gravatar_enabled_user_icon_should_be_from_gravatar_if_user_email_set_but_icon_is_not
    default_uri = URI.parse("http://s3.example.com")
    view_helper.default_url_options = {:host => default_uri.host, :port => default_uri.port, :scheme => default_uri.scheme}

    MingleConfiguration.overridden_to(:multitenancy_mode => true, :asset_host => "http://cf.example.com") do
      url = @user_icons.url_for(create_user!(:email => 'foo@bar.com', :name => 'Victor'))
      fallback = CGI.escape view_helper.image_url("avatars/v.png")
      gravatar_url = "https://www.gravatar.com/avatar/#{ 'foo@bar.com'.md5 }?d=#{fallback}&s=48"
      assert_equal gravatar_url, url
    end
  end

  def test_should_return_default_user_icon_url_when_user_is_nil
    assert_equal UserIcons::FALLBACK_ICON, @user_icons.url_for(nil)
  end

  def test_for_user_has_icon_error_icon_is_his_old_icon
    user = create_user!(:icon => sample_attachment("user_icon.jpg"))
    assert @user_icons.url_for(user).ends_with?('user_icon.jpg')

    user.update_attributes(:icon => uploaded_file(icon_file_path("bigger_than_100K.jpg")))
    assert user.errors.any?
    assert @user_icons.url_for(user).ends_with?('user_icon.jpg')
  end

  def test_for_new_user_has_icon_error_icon_is_default
    user = User.create(:name => 'new user', :login => 'very_new', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :email => 'verynew@email.com', :icon => uploaded_file(icon_file_path("bigger_than_100K.jpg")))
    assert user.errors.any?
    assert_equal UserIcons::FALLBACK_ICON, @user_icons.url_for(user)
  end

end
