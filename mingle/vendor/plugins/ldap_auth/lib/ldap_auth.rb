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

if RUBY_PLATFORM =~ /java/
  require 'java'
  java_import "com.novell.ldap.LDAPConnection"
  java_import "com.novell.ldap.LDAPSearchResults"
  java_import "com.novell.ldap.LDAPEntry"
  java_import "java.security.Security"
  java_import "com.sun.net.ssl.internal.ssl.Provider"
  java_import "com.novell.ldap.LDAPJSSEStartTLSFactory"
  java_import "com.novell.ldap.LDAPJSSESecureSocketFactory"
  java_import "com.novell.ldap.LDAPSearchConstraints"
  java_import "java.lang.System"
  java_import "com.novell.ldap.LDAPReferralException"
  java_import "com.novell.ldap.LDAPException"
end

class LDAPAuthentication

  attr_accessor :ldapserver, :ldapport, :ldapbinduser, :ldapbindpasswd,
    :ldapbasedn, :ldapfilter, :ldapobjectclass, :ldap_map_fullname, :ldap_map_mail,
    :ldapgroupobjectclass, :ldapgroupdn, :ldapgroupattribute,
    :ldapusetls, :ldapusessl, :ldaptruststore, :auto_enroll

  def configure(settings)
    settings.each { |property, value| send(:"#{property}=", value) }
  end

  # bug 9940
  def auto_enroll_as_mingle_admin=(value)
    ActiveRecord::Base.logger.error("\nConfiguration error: property 'auto_enroll_as_mingle_admin' in LDAP section of #{AUTH_CONFIG_YML} is no longer supported and will have no effect.\n")
  end

  def authenticate?(params,request_url)
    login = params[:user][:login].strip
    password = params[:user][:password].strip
    return nil if password == ''
    useTLS = false
    useSSL = false
    jsearchresults = LDAPSearchResults
    userEntry = LDAPEntry
    groupEntry = LDAPEntry
    jdn = String.new

    begin
      if !ldapusetls.nil? and !ldapusessl.nil? and ldapusessl == true and ldapusetls == true
            log_error(nil, "LDAP configuration error. Please use either ldapusetls or ldapusessl. These options cannot be enable at the same time.")
            return nil
      else
        if !ldapusetls.nil?
          if ldapusetls == true
            useTLS = true
          end
        end
        if !ldapusessl.nil?
          if ldapusessl == true
            useSSL = true
          end
        end
      end
      begin
        if (useTLS or useSSL)
          Security.addProvider(Provider.new)
          if !ldaptruststore.nil?
            System.setProperty("javax.net.ssl.trustStore",ldaptruststore)
          end
          if (useTLS)
            jldap_con = LDAPConnection.new(LDAPJSSEStartTLSFactory.new)
          else
            jldap_con = LDAPConnection.setSocketFactory(LDAPJSSESecureSocketFactory.new)
            jldap_con = LDAPConnection.new
          end
        else
          jldap_con = LDAPConnection.new
        end
        jldap_con.connect(ldapserver,ldapport)
      rescue Exception => e
        log_error(e, "Mingle cannot connect to LDAP Server with any of the LDAP protocol. Please check your configuration specified in #{MINGLE_CONFIG_DIR}/auth_config.yml")
        raise e
      end
      if (useTLS)
        begin
          jldap_con.startTLS
        rescue Exception => e
            log_error(e, "Mingle cannot connect to LDAP Server with TLS. Please check with your keystore.")
            raise e
        end
      end
      if ldapbinduser != nil and ldapbindpasswd != nil and ldapbinduser != '' and ldapbindpasswd != ''
    #      utf8passwd = java.lang.String.new(ldapbindpasswd)
        begin
          jldap_con.bind(LDAPConnection::LDAP_V3,ldapbinduser,ldapbindpasswd)
        rescue Exception => e
          log_error(e, "Mingle is not able to connect to the LDAP server specified in #{MINGLE_CONFIG_DIR}/auth_config.yml. Please check that ldapserver and ldapport have correct values in that file. If those values are correct, please check that the LDAP service is running and that a network route exists between the Mingle host and the LDAP host. One possible cause of a network route not existing is a misconfigured firewall.")
          raise e
        end
      end
      jldapconstraints = nil
      jldapconstraints = LDAPSearchConstraints.new
      jldapconstraints.setBatchSize(0)
      jldapconstraints.setServerTimeLimit(15)
      begin
        jsearchresults = jldap_con.search(ldapbasedn,LDAPConnection::SCOPE_SUB,"(&(objectClass=#{ldapobjectclass})(#{ldapfilter}=#{login}))",["#{ldap_map_mail}","#{ldap_map_fullname}"].to_java(:string),false,jldapconstraints)
      rescue LDAPException => e
        log_error(e, "Mingle is not able to search for user : #{login}. Error code #{e.getResultCode}")
        raise e
      end

      no_of_results = 0
      while jsearchresults.hasMore() do
        begin
          userEntry = jsearchresults.next
          jdn = userEntry.getDN
          no_of_results = no_of_results + 1
        rescue LDAPReferralException => e
          # Referral Exception is not an error condition.  Ingore it and do not follow referral
          #log_error(e, "Mingle does not support referral in LDAP searching.")
        end
      end
      if (no_of_results != 1)
        log_error(e, "Mingle is able to connect to the LDAP server specified in #{MINGLE_CONFIG_DIR}/auth_config.yml but find multiple users with the same login ID - #{login}")
        raise e
      end

      unless jdn.empty?
        unless ldapgroupobjectclass == nil or ldapgroupdn == nil or ldapgroupattribute == nil
          jsearchresults = nil
          begin
            jdn.sub!('(','\\\\28')
            jdn.sub!(')','\\\\29')
            jsearchresults = jldap_con.search(ldapgroupdn,LDAPConnection::SCOPE_SUB,"(&(objectClass=#{ldapgroupobjectclass})(#{ldapgroupattribute}=#{jdn}))",["#{ldapgroupattribute}"].to_java(:string),false,jldapconstraints)
          rescue LDAPException => e
            log_error(e, "Mingle is not able to search for group : #{ldapgroupdn}. Error code #{e.getResultCode}")
            raise e
          end

          no_of_results = 0
          while jsearchresults.hasMore() do
            begin
              groupEntry = jsearchresults.next
              no_of_results = no_of_results + 1
            rescue LDAPReferralException => e
              # Referral Exception is not an error condition.  Ingore it and do not follow referral
              #log_error(e, "Mingle does not support referral in LDAP searching.")
            rescue LDAPException => e
              if e.message.include?('No Such Object')
                log_error(e, "User is not in the group specified in #{MINGLE_CONFIG_DIR}/auth_config.yml. User : #{login} is not authorized to use Mingle.")
                raise "Authorization Failed"
              else
                raise
              end
            end
          end
          if (no_of_results > 1)
            log_error(nil, "Mingle is able to connect to the LDAP server but found multiple groups with the same DN")
            raise "Authorization Failed"
          end
          if (no_of_results == 0)
            log_error(nil, "User is not in the group specified in #{MINGLE_CONFIG_DIR}/auth_config.yml. User : #{login} is not authorized to use Mingle.")
            raise "Authorization Failed"
          end
          jldapconstraints = nil
        end

        begin
          jldap_con.bind(LDAPConnection::LDAP_V3,jdn,password)
          mingle_login = login.downcase
          user = User.find_by_login(mingle_login)
          if !user
            begin
              new_user_fullname = userEntry.getAttribute(ldap_map_fullname).getStringValue
              new_user_email = userEntry.getAttribute(ldap_map_mail).getStringValue
            rescue Exception => e
              log_error(nil, "Mingle is unable to retrive user fullname and/or email from LDAP Server")
              raise e
            end
            # new a user for auto-enroll
            user = User.new(:name => new_user_fullname || mingle_login, :login => mingle_login, :email => new_user_email, :version_control_user_name => mingle_login)
          end
          if (useTLS)
            if jldap_con.isTLS
	      begin
                jldap_con.stopTLS
              rescue Exception => e
                log_error(nil, "Mingle LDAP Plugin cannot stop TLS request.  It is harmless to ignore it.")
              end
            end
          end
          if jldap_con.isConnected
            jldap_con.disconnect
          end
          return user

        rescue Exception => e
          log_error(e, "User authentication failed : #{login}")
          raise e
        end
        if (useTLS)
          if jldap_con.isTLS
	    begin
              jldap_con.stopTLS
            rescue Exception => e
              log_error(nil, "Mingle LDAP Plugin cannot stop TLS request.  It is harmless to ignore it.")
            end
          end
        end
        if jldap_con.isConnected
          jldap_con.disconnect
        end
        return nil
      end

    rescue Exception => e
      log_error(e, "User authentication failed : #{login}")
      if !jldap_con.nil?
        if (useTLS)
          if jldap_con.isTLS
            jldap_con.stopTLS
          end
        end
        if jldap_con.isConnected
          jldap_con.disconnect
        end
      end
      return nil
    end

  end

  def is_external_authenticator?
    true
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
    true
  end

  def label
    "ldap"
  end

end
