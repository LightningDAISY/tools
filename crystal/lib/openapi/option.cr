#
# Command line Option Parser
#
module OpenAPI
  class Option
    # for debug
    protected getter raw = [] of String
    getter options = {} of String => String
    getter args = [] of String

    def initialize(args : Array(String))
      @raw = args
      nextIsOption : Bool = false
      nextName : String = ""
      args.each do |arg|
        if nextIsOption
          @options[nextName] = arg
          nextIsOption = false
        elsif arg.size > 2 && arg.at(0) == '-' && arg.at(1) == '-'
          nextIsOption = true
          nextName = arg.lchop.lchop.to_s
        elsif arg.size > 1 && arg.at(0) == '-'
          nextIsOption = true
          nextName = arg.lchop.to_s
        else
          @args << arg
        end
      end
    end

    #
    # puts ins["x"]
    #
    def [](subscript : String | Int)
      if subscript.is_a?(Int)
        if args[subscript]?
          args[subscript]
        else
          nil
        end
      else
        if options[subscript]?
          options[subscript]
        else
          nil
        end
      end
    end

    #
    # ins["x"] = "XXXX"
    #
    def []=(subscript : String | Int, value : String | Int | Nil)
      if subscript.is_a?(Int)
        args[subscript] = value
      else
        if value.is_a?(Nil)
          options.delete(subscript)
        else
          options[subscript] = value
        end
      end
    end
  end
end

#
# example:
#
#   main.cr
#
#     require "openapi/option"
#     ins = OpenAPI::Option.new(ARGV)
#     puts ins["x"]
#     puts ins[0]
#
#  command line
#
#    $ ./main -x 1 abc -y 2 def -z 3 ghi
#
#  result
#
#    1
#    abc
#

