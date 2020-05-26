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

module AttachmentsAction

  def remove_attachment(card_or_page, attachment_name)
    @browser.with_ajax_wait do
      @browser.click("css=.dz-preview:contains(#{attachment_name}) .dz-remove")
      @browser.get_confirmation
    end
  end

  def attach_file(file_name, attachment_param={})
    attachment_number = attachment_param.delete(:attachment_number) || '0'
    attachment_input = attachment_input_field_id(attachment_number)
    if using_ie?
      file_name = file_name.gsub(/\//, "\\\\")
      @browser.get_eval <<-JAVASCRIPT
        try {
          selenium.doWindowFocus();
          selenium.doFocus(#{attachment_input.to_json});
          var objShell = new ActiveXObject("wscript.shell");
          objShell.SendKeys(#{file_name.to_json});
          objShell = null;
        } catch(w) {
          objShell = null;
          throw new Error( 'sendkey did something:' + w.name + ' :  ' + w.message );
        }
      JAVASCRIPT
    else
      @browser.type(attachment_input, file_name)
    end
  end


  def attach_file_on_page(page, file_name)
    page.attach_files(sample_attachment(file_name))
    page.save!
  end

  def click_on_attach_another_file_link
    @browser.click(attach_another_file_link)
  end
end
