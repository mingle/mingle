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

module Java
  java_import java.security.spec.X509EncodedKeySpec
  java_import java.security.KeyFactory
  java_import javax.crypto.Cipher
  java_import java.lang.String
end

class LicenseDecryptException < StandardError; end

class String
  def from_base64
    Base64.decode64(self)
  end
end

class LicenseDecrypt
  def do_decrypt(license_key)
    begin
      if license_key.strip == 'Open source'
        {
            'max_active_users' => 100000,
            'max_light_users' => 100000,
            'allow_anonymous' => 'true',
            'expiration_date' => '2110-1-1',
            'product_edition' => Registration::ENTERPRISE,
            'licensee' => 'Open source'
        }
      else
        license_key.gsub!(" ", "")
        cipher = Java::Cipher.getInstance(algrithom)
        cipher.init(Java::Cipher::DECRYPT_MODE, public_key(public_key_code))
        decode_str = String.from_java_bytes(cipher.doFinal(license_key.from_base64.to_java_bytes))
        ActionController::Request.parse_query_parameters(decode_str)
      end
    rescue Exception => e
      License.logger.error(e)
      raise LicenseDecryptException.new("The license key is invalid")
    end
  end

  private
  def algrithom
    "RSA"
  end

  def public_key_code
    # Product: mingle
    # Algrithom: RSA
    # Encoding Format: X.509
    <<-KEY
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkia/phnKSbAIz6de
3FmiyOaQEvfP5umJqQUW0UoQ6cLvQHhreBpQMHpYNvv2aSSspefwpRvWkcmY
UozqoVhc6Zrq5xhZyA7vritblma3uT48B4jWomGln/vHbNlRAP5SeojhzO+/
3mX6dstveF/ASc0aw8sVvOkIcukmOJ0kSdTwMiwIka2atNxUuxdlJXKPwGF3
chvwmAsh+YSUxGhPC0jl5N4HAiW8iyjkNLkXH92jXLIQi/YUD8KkHgeC870h
Czlct18I8HwBYgMwRDvgrayofv2/SdDswnyIjPmLsYssZ7EQB5VU4sYFRIGK
hcsNAUN18zc0xJvzEG0jQaPSyQIDAQAB
    KEY
  end

  def public_key(public_key_code)
    unless @public_key
      public_key_spec = Java::X509EncodedKeySpec.new(public_key_code.from_base64.to_java_bytes)
      @public_key = Java::KeyFactory.getInstance(algrithom).generatePublic(public_key_spec)
    end
    @public_key
  end
end
