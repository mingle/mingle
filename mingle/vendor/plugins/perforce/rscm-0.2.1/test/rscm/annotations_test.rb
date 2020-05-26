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

require 'test/unit'
require 'rscm/annotations'

module RSCM
  class Whatever
    attr_accessor :no_annotation
    ann :boo => "huba luba", :pip => "pip pip"
    attr_accessor :foo
  
    ann :desc => "bang bang"
    ann :tip => "a top tip"
    attr_accessor :bar, :zap
  end

  class Other
    attr_accessor :no_annotation
    ann :boo => "boo"
    ann :pip => "pip"
    attr_accessor :foo
  
    ann :desc => "desc", :tip => "tip"
    attr_accessor :bar, :zap
  end
  
  class Subclass < Other
  end

  class AnnotationsTest < Test::Unit::TestCase
    def test_should_handle_annotations_really_well
      assert_equal("huba luba", Whatever.foo[:boo])
      assert_equal("pip pip", Whatever.foo[:pip])

      assert_nil(Whatever.bar[:pip])
      assert_equal("bang bang", Whatever.bar[:desc])
      assert_equal("a top tip", Whatever.bar[:tip])

      assert_equal("bang bang", Whatever.zap[:desc])
      assert_equal("a top tip", Whatever.zap[:tip])

      assert_equal("boo", Other.foo[:boo])
      assert_equal("pip", Other.foo[:pip])

      assert_nil(Whatever.bar[:pip])
      assert_equal("desc", Other.bar[:desc])
      assert_equal("tip", Other.bar[:tip])

      assert_equal("desc", Other.zap[:desc])
      assert_equal("tip", Other.zap[:tip])
    end

    def test_should_inherit_attribute_annotations
      assert_equal("boo", Subclass.foo[:boo])
      assert_equal({:boo => "boo", :pip => "pip"}, Subclass.send("foo"))
      assert_nil(Whatever.send("no_annotation"))
    end
  end
end
