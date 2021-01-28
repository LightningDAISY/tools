#! /usr/bin/env ruby
module YamlDiff
  require 'optparse'
  require 'yaml'

  Version = '1.0.0'

  @options = {}
  @target_files = []
  @target_classes = []
  @mode_exists = false
  @mode_pretty = false
  @error_exists = {}

  class MyException < StandardError
  end

  def self.usage
    puts "\nUsage: #{$0} filename1 filename2 [-c NAME] [-c NAME]"
  end

  def self.fread(path)
    fbody = ''
    File.open(path) do |fh|
      fh.each_line do |line|
        fbody += line
      end
    end
    fbody
  end

  def self.fwrite(path, fbody)
    File.open(path, 'w', 0644) do |fh|
      fh.write(fbody)
    end
  end

  def self.get_options
    @Option.on('-c', '--class ClassName', 'target classname') do |v|
      @target_classes << v
    end
    @Option.on('-e', '--exists', 'key exists') do |v|
      @mode_exists = true
    end
    @Option.on('-p', '--pretty', 'pretty print') do |v|
      @mode_pretty = true
    end
  end

  def self.wildcard2classname(yaml)
    yaml.keys[0]
  end

  def self.pp(body, value_a=nil, value_b=nil)
    return body if !value_a && !value_b

    if @mode_pretty
      <<~PRETTY_PRINT
      #{body}
        #{value_a}
        #{value_b}
      PRETTY_PRINT
    else
      "#{body} #{value_a} #{value_b}"
    end
  end

  def self.struct_diff_main(s1, s2, current_class, label_a, label_b)
    return if @error_exists.key? "#{current_class}"
    if s1.class != s2.class
      @errors << pp("the type is not matched", "#{label_a}:#{current_class}",  "#{label_b}:#{current_class}")
      return
    end
    if s1.class == Hash
      s1.keys.each do |name|
        next if @error_exists.key? "#{current_class}:#{name}"
        unless s2.key?(name)
          @error_exists["#{current_class}:#{name}"] = true
          @errors << pp("#{label_b} has no #{current_class}:#{name}")
          next
        end

        if s1[name].class == Hash || s1[name].class == Array
          if s1[name].class == s2[name].class
            struct_diff(s1[name], s2[name], "#{current_class}:#{name}")
          else
            @error_exists["#{current_class}:#{name}"] = true
            @errors << pp("#{current_class}:#{name} type is not matched", "#{label_a}:#{s1[name].class}", "#{label_b}:#{s2[name].class}")
          end
        else
          unless @mode_exists
            if s1[name] != s2[name]
              @error_exists["#{current_class}:#{name}"] = true
              @errors << pp("#{current_class}:#{name} is not matched.", "#{label_a}:#{s1[name]}", "#{label_b}:#{s2[name]}")
            end
          end
        end
      end
    elsif s1.class == Array
      if s1.size == s2.size
        s1.size.times do |i|
          next if @error_exists.key? "#{current_class}:#{i}"
          if s1[i].class == Hash || s1[i].class == Array
            if s1[i].class == s2[i].class
              struct_diff(s1[i], s2[i], "#{current_class}:#{i}")
            else
              @error_exists["#{current_class}:#{i}"] = true
              @errors << pp("#{current_class}:#{i} type is not matched", "#{label_a}:#{s1[i].class}", "#{label_b}:#{s2[i].class}")
            end
          else
            unless @mode_exists
              if s1[i] != s2[i]
                @error_exists["#{current_class}:#{i}"] = true
                @errors << pp("#{current_class}:#{i} is not matched.", "#{label_a}:#{s1[i]}", "#{label_b}:#{s2[i]}")
              end
            end
          end
        end
      else
        @errors << pp("size missmatch", "#{label1}:#{s1.size}", "#{label2}:#{s2.size}")
      end
    end
  end

  def self.struct_diff(s1, s2, current_class)
    struct_diff_main(s1, s2, current_class, "A", "B")
    struct_diff_main(s2, s1, current_class, "B", "A")
  end

  def self.main
    @Option = OptionParser.new
    get_options()
    @args = @Option.parse(ARGV)
    filename1 = @args[0] || raise("invalid filename 1 #{@args[0]}")
    filename2 = @args[1] || raise("invalid filename 2 #{@args[1]}")
    yaml1 = YAML.load(fread(filename1))
    yaml2 = YAML.load(fread(filename2))
    raise("cannot parse #{filename1}") if yaml1.class != Hash
    raise("cannot parse #{filename2}") if yaml2.class != Hash

    @target_classes.each do |classname|
      classname1 = classname
      classname1 = wildcard2classname(yaml1) if classname.size < 1
      raise("#{filename1} has no #{classname1}") unless yaml1.key? classname1
      yaml1 = yaml1[classname1]

      classname2 = classname
      classname2 = wildcard2classname(yaml2) if classname.size < 1
      raise("#{filename2} has no #{classname2}") unless yaml2.key? classname2
      yaml2 = yaml2[classname2]
    end

    @errors = []
    struct_diff(yaml1, yaml2, @target_classes.join(':'))
    puts @errors.join("\n")

  rescue => e
    puts "Error: #{e}"
    usage()
    exit
  end

end

YamlDiff::main()


