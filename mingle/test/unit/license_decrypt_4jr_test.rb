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

class LicenseDecrypt4jrTest < ActiveSupport::TestCase
  does_not_work_without_jruby

  def setup
    LicenseDecrypt.enable_license_decrypt
    @license_decrypt = LicenseDecrypt.new
    Clock.fake_now("2012-01-01")
  end

  def teardown
    Clock.reset_fake
    LicenseDecrypt.disable_license_decrypt
  end

  def test_decrypt
    # Licensee: ThoughtWorks Inc.
    # Allow Max Active Users: 1000
    # Expiration Date: 2012-07-23
    license_key = <<-DATA
NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
    DATA
    assert_license_key(license_key)
  end

  def test_decrypt_data_should_strip
    license_key_from_email= <<-DATA
  NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
    DATA
    assert_license_key(license_key_from_email)
  end

  # bug 2159
  def test_decrypt_data_should_strip_whitespace_at_end_of_each_line
    license_key_from_email= <<-DATA
  NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
    DATA
    begin
      assert_license_key(license_key_from_email)
    rescue
      assert_fail("License key was invalid.")
    end
  end

  def test_should_throw_exception_when_the_license_key_is_invalid
    invalid_license_key = <<-DATA
AAACbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
    DATA

    error = assert_raise(LicenseDecryptException)do
      license_struct = @license_decrypt.do_decrypt(invalid_license_key)
    end
    assert_equal 'The license key is invalid', error.message
  end

  def test_decrypt_enterprise_from_license_data
    license_key = <<-DATA
cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2
a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANl
I6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4
avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0k
P5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//x
mzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA==
    DATA

    clear_license
    assert !CurrentLicense.status.enterprise?
    CurrentLicense.register!(license_key.strip, 'ThoughtWorks Inc.')
    assert CurrentLicense.status.enterprise?
  end

  def test_license_without_product_edition_attribute_should_not_be_enterprise
    license_key = <<-DATA
NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
DATA
    clear_license
    CurrentLicense.register!(license_key.strip, 'ThoughtWorks Inc.')
    assert !CurrentLicense.status.enterprise?
  end

  def test_strange_license_that_has_blank_product_edition_comes_out_as_non_enterprise
    license_key = <<-DATA
TrU18JIUzzyoJtXu8x7yQh/EoFJWceeY3viT4gTF8GRa7CqE4T7naPJmTUpH
78oZDK6StlV0AII7fYAxD8zq4BjR6RcobXT3syW091I8xZLI03UcjGaiv0ti
o4fXjITWP1H6fqzMIA7YlH/OAaNoIirD+PDZEbsnUDqN/ysXk+zdNlMnw1sg
qh3ds6HT3FCFIu6AyjZzBmhU9DQGLR1ULCdiO/y7yorSlcPpcjfKuXwoRlbY
7y25MyBA7Pg7QUfJYiErsxzsuDskxhcTUIZJszOg4fY9w2nwcK/I2dg8rMwz
5aqM6erFM2KgSfJsvkkPWq82QwWb0PKNcO5Lx+ZYig==
    DATA
    clear_license
    CurrentLicense.register!(license_key.strip, '2000 Users License')
    assert_false CurrentLicense.registration.enterprise?
  end

  def assert_license_key(license_key)
    license_struct = @license_decrypt.do_decrypt(license_key)
    assert_equal "ThoughtWorks Inc.", license_struct['licensee']
    assert_equal "123", license_struct['customer_number']
    assert_equal "1000", license_struct['max_active_users']
    assert_equal "2012-07-23", license_struct['expiration_date']
    assert_equal "standard", license_struct['type']
  end
end
