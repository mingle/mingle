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

class SmtpConfiguration

  ERROR_MSG_INVALID_SMTP_SETTINGS = "Cannot connect to SMTP server. Check that the SMTP settings are entered."
  ERROR_MESSAGE_SEND_FAILURE = "Sending test message failed. Check your settings and try again."

  class << self
    def create(params, file_name=SMTP_CONFIG_YML, store_blank_fields=false)
      if params['smtp_settings'].present?
        if params['smtp_settings']['user'].present?
          params['smtp_settings'].merge!('authentication' => 'plain')
        end
        if params['smtp_settings']['tls'].present?
          params['smtp_settings']['tls'] = Boolean(params['smtp_settings']['tls'])
        end
      end
      FileUtils.mkpath(File.dirname(file_name))
      File.open(file_name, "w+") do |io|
        SECTIONS.each do |section|
          section.merge_params(params, store_blank_fields).write_as_yaml_on(io) #can't emit comments - hence using regular file writing.
        end
      end
      load(file_name)
    end

    def configured?(file_name=SMTP_CONFIG_YML)
      load(file_name) && valid?(file_name) &&  MingleConfiguration.site_url_as_url_options[:protocol] && MingleConfiguration.site_url_as_url_options[:host]
    end

    def load(file_name=SMTP_CONFIG_YML)
      initialized = false
      begin
        if File.exists?(file_name)
          @settings = YAML.render_file_and_load(file_name, binding) rescue nil
          if @settings
            ActionMailer::Base.smtp_settings = (@settings["smtp_settings"] || {}).symbolize_keys
            if ActionMailer::Base.smtp_settings[:authentication].blank? && !ActionMailer::Base.smtp_settings[:user_name].blank?
              ActionMailer::Base.smtp_settings[:authentication] = "plain"
            end

            ActionMailer::Base.default_sender = (@settings["sender"] || {}).symbolize_keys

            initialized = true
          end
        end
      rescue Exception => e
        Project.logger.error("Unable to load SMTP config: #{e}:\n#{e.backtrace.join("\n")}")
      end
      initialized
    end

    def valid?(file_name)
      (@settings || load(file_name)) &&
          @settings['smtp_settings'].present? &&
          @settings['smtp_settings']['address'].present? &&
          @settings['smtp_settings']['port'].present?&&
          @settings['smtp_settings']['domain'].present? &&
          @settings['sender'].present? &&
          @settings['sender']['address'].present?
    end

    def test(settings)
      errors = []
      site_uri = nil
      begin
        site_uri = URI.parse(MingleConfiguration.site_url)
      rescue => e
        errors << e.message
      end
      sender = settings['sender']
      smtp_settings = settings['smtp_settings']
      verify_delivery = settings['__verify_delivery']

      blank_fields = []
      blank_fields << "SMTP server address" << "SMTP server port" unless smtp_settings
      blank_fields << "SMTP server address" if smtp_settings && smtp_settings['address'].blank?
      blank_fields << "SMTP server port" if smtp_settings && smtp_settings['port'].blank?

      errors << "#{blank_fields.bold.to_sentence} must be provided to test SMTP settings." if blank_fields.any?
      errors << "Unable to test email settings. Please go to your profile page to specify an email address and try again." if User.current.email.blank?

      if (smtp_settings && errors.empty?)
        begin
          send_test_mail(sender, site_uri, smtp_settings, verify_delivery)
        rescue Exception => e
          Project.logger.error("Unable to send test mail: #{e}:\n#{e.backtrace.join("\n")}")
          errors << e.message
        end
      end
      errors.uniq
    end

    def to_hash(open_struct)
      return {} unless open_struct
      open_struct.marshal_dump.delete_if { |key, value| value.blank? }
    end
  end

  def initialize(file_name=SMTP_CONFIG_YML)
    @file_name = file_name
  end

  def smtp_settings
    read_section_from_file(Configuration::Default::SmtpSettings)
  end

  def sender
    read_section_from_file(Configuration::Default::Sender)
  end

  class Configuration::Default
    SmtpSettings = self.new_section('smtp_settings', 'address', 'domain', 'port', 'authentication', 'user_name', 'password')
    Sender = self.new_section('sender', 'name', 'address')
  end

  SECTIONS = [Configuration::Default::SmtpSettings, Configuration::Default::Sender]

  private
  class << self
    # fork off a separate runtime/process so as not to interfere with global mail settings which may be in use by normal mail operations
    def send_test_mail(sender, site_uri, smtp_settings, verify_delivery)
      test_mail_script = File.join(Rails.root, 'script', 'send_test_mail')

      string_settings = [
        Rails.env.to_s,
        Rails.root.to_s,
        MINGLE_DATA_DIR,
        CONTEXT_PATH,
        User.current.email,
        sender['name'],
        sender['address'],
        smtp_settings['address'],
        smtp_settings['port'],
        smtp_settings['domain'],
        smtp_settings['tls'],
        smtp_settings['user_name'],
        smtp_settings['password'],
        site_uri.scheme,
        site_uri.host,
        site_uri.port,
        verify_delivery
      ]

      if RUBY_PLATFORM =~ /java/
        script = <<-RUBY
          RAILS_ENV = #{Rails.env.inspect} unless defined?(RAILS_ENV)
          RAILS_ROOT = #{Rails.root.to_s.inspect} unless defined?(RAILS_ROOT)
          MINGLE_DATA_DIR = #{MINGLE_DATA_DIR.inspect} unless defined?(MINGLE_DATA_DIR)
          CONTEXT_PATH = #{CONTEXT_PATH.inspect} unless defined?(CONTEXT_PATH)
          require File.join(RAILS_ROOT, 'config', 'environment')

          email_to    = #{User.current.email.inspect}
          sender_name = #{sender['name'].inspect}
          email_from  = #{sender['address'].inspect}

          smtp_address        = #{smtp_settings['address'].inspect}
          smtp_port           = #{smtp_settings['port'].inspect}
          smtp_domain         = #{smtp_settings['domain'].inspect}
          smtp_tls            = #{smtp_settings['tls'].inspect}
          smtp_user_name      = #{smtp_settings['user_name'].inspect}
          smtp_password       = #{smtp_settings['password'].inspect}

          site_url_protocol = #{site_uri.scheme.inspect}
          site_url_host     = #{site_uri.host.inspect}
          site_url_port     =  #{site_uri.port.inspect}
          #{File.read(test_mail_script)}
        RUBY
        mingle_scripting_container do |c|
          result = c.runScriptlet(script)
          raise ERROR_MESSAGE_SEND_FAILURE if result != 0
        end
      else
        system("ruby #{test_mail_script} #{to_java_command_line_string(string_settings)}")
        raise ERROR_MESSAGE_SEND_FAILURE if $? != 0
      end
    end

    def to_java_command_line_string(array)
      array.inject([]) do |result, element|
        result << (element.present? ? element.to_s : '\'\'')
      end.join(' ')
    end

    def mingle_scripting_container(&block)
      container = com.thoughtworks.mingle.MingleScriptingContainer.new(Rails.root.to_s)
      begin
        container.setEnvironment(ENV)
        container.setLoadPaths($:)
        yield(container)
      ensure
        container.terminate
      end
    end
  end

  def read_section_from_file(section)
    return unless config_file_hash
    section.read_from_yml(config_file_hash)
  end

  def config_file_hash
    @yml_hash ||= YAML::load(IO.read(@file_name)) rescue nil
  end
end
