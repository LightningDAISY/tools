#
# require 'data/dumper'
# ins = Data::Dumper.new
# puts ins.prettyPrint({ "a" => "A"})
#
require "json"
require "yaml"

module Data
  class Dumper
    @struct : YAML::Any
    @layerNumber : Int32
    @layerType : String
    @indent : String = "  "
    @lf : String = "\n"
    @result : String

    def self.toYaml(hash)
      YAML.dump(hash)
    end

    def self.fromYaml(text : String)
      YAML.parse(text)
    end

    def self.fromJson(text : String)
      JSON.parse(text)
    end

    def initialize(data)
      @string = ""
      @layerNumber = 1
      @result = ""
      @layerType = "String"

      unless data.is_a?(YAML::Any)
        if data.is_a?(JSON::Any)
          data = data.to_yaml
        else
          yaml = Data::Dumper.toYaml(data)
          data = Data::Dumper.fromYaml(yaml)
        end
        raise "unknown type " + typeof(data).to_s unless data.is_a?(YAML::Any)
      end
      @struct = data
    end

    protected def indent(num : Int32 = @layerNumber) : String
      result : String = ""
      num.times do result += @indent end
      result
    end

    protected def recursive(data : YAML::Any) : String
      @layerNumber += 1
      block : String = ""

      if data.as_h?
        block += @lf + indent + "{" + @lf
        data.as_h.each do |key,value|
          block += indent(@layerNumber + 1) + 
                   key.to_s + " : " + recursive(value) + "," + @lf
        end
        block += indent + "}"
      elsif data.as_a?
        block += @lf + indent + "[" + @lf
        data.as_a.each do |value|
          block += indent(@layerNumber + 1) + 
                   recursive(value) + "," + @lf
        end
        block += indent + "]"
      elsif data.as_s?
        block = %q(") + data.to_s + %q(")
      else
        block = data.to_s
      end
      @layerNumber -= 1
      block
    end

    def prettyPrint(indent : String = "  ", lf : String = "\n")
      @indent = indent
      @lf = lf
      @result = recursive(@struct)
    end
  end
end

