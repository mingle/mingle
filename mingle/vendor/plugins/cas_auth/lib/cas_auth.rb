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

require 'net/https'

if RUBY_PLATFORM =~ /java/
  require 'java'
  java_import "javax.net.ssl.HttpsURLConnection"
  java_import "java.net.URL"
  java_import "java.io.InputStreamReader"
  java_import "java.io.BufferedReader"
  java_import "com.thoughtworks.mingle.security.MingleSSLSocketFactory"
end

class CASAuthentication

  attr_accessor :cas_host, :cas_port, :cas_uri, :cas_ca_file, :ticket_checker, :cas_root_cert_path, :cas_trust_all_certs

  def initialize
    load_ticket_checker
  end

  def configure(settings)
    settings.each { |property, value| send(:"#{property}=", value) }
  end

  def supports_password_recovery?
    false
  end

  def supports_password_change?
    false
  end

  def supports_login_update?
    false
  end

  def supports_basic_authentication?
    false
  end

  def has_valid_external_authentication_token?(params)
    !params[:ticket].nil?
  end

  def label
    "cas"
  end

  def authenticate?(params,request_url)
      unless params[:ticket].nil?
        begin
          login = ticket_checker.get_login(params[:ticket],request_url)
          if (login)
            return User.find_by_login(login.downcase) || User.new(:name => login.downcase, :login => login.downcase, :email => nil, :version_control_user_name => login.downcase)
          else
            User.logger.debug "CAS ticket is invalid."
          end
        rescue Exception => e
          log_error(e, "CASAuthentication unable to connect to CAS server. Please check that you have supplied correct values for the following parameters in #{MINGLE_DATA_DIR}/config/auth_config.yml: cas_port, cas_host, cas_uri. In the meantime, all user attempts to login to Mingle are likely to be unsuccessful.")
        end
      end
      return nil
  end

  def sign_out_url(service=nil)
    if (cas_port)
      if (cas_port == 443)
        sign_out_url = "https://#{cas_host}#{cas_uri}/logout"
      elsif (cas_port != 80)
        sign_out_url = "http://#{cas_host}:#{cas_port}#{cas_uri}/logout"
      else
        sign_out_url = "http://#{cas_host}#{cas_uri}/logout"
      end
    else
      sign_out_url = "https://#{cas_host}#{cas_uri}/logout"
    end
    return sign_out_url
  end

  def sign_in_url(request_url)
      if (cas_port)
        if (cas_port == 443)
          sign_in_url = "https://#{cas_host}#{cas_uri}/login?service=#{request_url}"
        elsif (cas_port != 80)
          sign_in_url = "http://#{cas_host}:#{cas_port}#{cas_uri}/login?service=#{request_url}"
        else
          sign_in_url = "http://#{cas_host}#{cas_uri}/login?service=#{request_url}"
        end
      else
        sign_in_url = "https://#{cas_host}#{cas_uri}/login?service=#{request_url}"
      end
    return sign_in_url
  end

  def is_external_authenticator?
    true
  end

  def can_connect?
    true
  end

  private

  def load_ticket_checker
    if RUBY_PLATFORM =~ /java/
      self.ticket_checker = JRubyTicketChecker.new(self)
    else
      self.ticket_checker = MRITicketChecker.new(self)
    end
  end

end

if RUBY_PLATFORM =~ /java/

  class JRubyTicketChecker

    def initialize(cas_auth)
      @cas_auth = cas_auth
    end

    def get_login(ticket,request_url)
      if (@cas_auth.cas_port == 443)
        url = URL.new("https://#{@cas_auth.cas_host}#{@cas_auth.cas_uri}/validate?ticket=#{ticket}&service=#{request_url}")
      elsif (@cas_auth.cas_port != 80)
        url = URL.new("http://#{@cas_auth.cas_host}:#{@cas_auth.cas_port}#{@cas_auth.cas_uri}/validate?ticket=#{ticket}&service=#{request_url}")
      else
        url = URL.new("http://#{@cas_auth.cas_host}#{@cas_auth.cas_uri}/validate?ticket=#{ticket}&service=#{request_url}")
      end
      untrustedsslsocket = nil
      if @cas_auth.cas_root_cert_path != nil || @cas_auth.cas_trust_all_certs != nil
        minglesslsocketfactory = MingleSSLSocketFactory.new
        untrustedsslsocket = minglesslsocketfactory.getSSLSocketFactory(@cas_auth.cas_root_cert_path,@cas_auth.cas_host,@cas_auth.cas_trust_all_certs ||= false)
        HttpsURLConnection.setFollowRedirects(true)
      end
      httpconn = url.openConnection
      if (untrustedsslsocket != nil)
        httpconn.setSSLSocketFactory(untrustedsslsocket)
      end
      httpconn.setRequestMethod("GET")
      httpconn.connect
#      code = httpconn.getResponseCode()
      insr = InputStreamReader.new(httpconn.getInputStream)
      inbuf = BufferedReader.new(insr)
      answer = inbuf.readLine
      name = inbuf.readLine
      httpconn.disconnect
      inbuf.close
      if answer == "yes"
        return name
      else
        return nil
      end
    end
  end

else

  class MRITicketChecker

    def initialize(cas_auth)
      @cas_auth = cas_auth
    end

    def get_login(ticket,request_url)
      http = Net::HTTP.new("#{@cas_auth.cas_host}","#{@cas_auth.cas_port}")
      http.use_ssl = true
      if (@cas_auth.cas_ca_file)
        http.ca_file = "#{@cas_auth.cas_ca_file}"
      end
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.start do
        response = http.get("#{@cas_auth.cas_uri}/validate?ticket=#{ticket}&service=#{request_url}")
        answer, name = response.body.chomp.split("\n")
        if answer == "yes"
          return name
        else
          return nil
        end
      end
    end
  end

end
