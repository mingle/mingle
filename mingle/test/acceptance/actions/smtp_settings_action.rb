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

module SmtpSettingsAction
  
  def configure_smtp_as(options)
    
    FileUtils.rm_rf('tmp/mails') if File.exists?('tmp/mails')
    
    login_as_admin_user
    
    @browser.open("/smtp/edit")
    options.each do |key, value|
      @browser.type key, value
    end
    
    with_revert_smtp_config do      
      @browser.click_and_wait SmtpSettingsPageId::SAVE_LINK
    end
  end
    
  def there_should_be_a_email_send(expetations)
    mail = last_email
    raise "a mail expected, but haven't been send" unless mail
    
    expetations.each do |key, value|
      if value.is_a?(Array)
        assert_equal value.sort, mail.send(key).sort
      elsif value.respond_to?(:assert_match)
        value.assert_match(mail.send(key))
      else
        assert_equal value, mail.send(key), "expect #{key} of the mail is #{value}"
      end
    end
  end
  
  private
  
  def with_revert_smtp_config(&block)
    FileUtils.cp(File.join(Rails.root, SmtpSettingsPageId::CONFIG_ID, SmtpSettingsPageId::SMTP_CONFIG_YML), File.join(Rails.root, SmtpSettingsPageId::CONFIG_ID, SmtpSettingsPageId::SMTP_CONFIG_YML_BACK))
    on_after do
      FileUtils.mv(File.join(Rails.root, SmtpSettingsPageId::CONFIG_ID, SmtpSettingsPageId::SMTP_CONFIG_YML_BACK), File.join(Rails.root, SmtpSettingsPageId::CONFIG_ID, SmtpSettingsPageId::SMTP_CONFIG_YML))
    end
    yield
  end
  
end
