require 'rspec/core/formatters/base_formatter'
require 'active_support'
require 'active_support/core_ext/numeric'
require 'active_support/inflector'
require 'fileutils'
require 'rouge'
require 'erb'
require 'rbconfig'

#require 'pp' # pretty print

I18n.enforce_available_locales = false


#
# Colorize CLI
#
# TODO: needs changing to https://misc.flogisoft.com/bash/tip_colors_and_formatting
class String
  def black;          "\e[30m#{self}\e[0m" end
  def red;            "\e[31m#{self}\e[0m" end
  def green;          "\e[32m#{self}\e[0m" end
  def brown;          "\e[33m#{self}\e[0m" end  # yellow
  def blue;           "\e[34m#{self}\e[0m" end
  def magenta;        "\e[35m#{self}\e[0m" end
  def cyan;           "\e[36m#{self}\e[0m" end
  def gray;           "\e[37m#{self}\e[0m" end
  
  def bg_black;       "\e[40m#{self}\e[0m" end
  def bg_red;         "\e[41m#{self}\e[0m" end
  def bg_green;       "\e[42m#{self}\e[0m" end
  def bg_brown;       "\e[43m#{self}\e[0m" end
  def bg_blue;        "\e[44m#{self}\e[0m" end
  def bg_magenta;     "\e[45m#{self}\e[0m" end
  def bg_cyan;        "\e[46m#{self}\e[0m" end
  def bg_gray;        "\e[47m#{self}\e[0m" end
  
  def bold;           "\e[1m#{self}\e[22m" end
  def italic;         "\e[3m#{self}\e[23m" end
  def underline;      "\e[4m#{self}\e[24m" end
  def blink;          "\e[5m#{self}\e[25m" end
  def reverse_color;  "\e[7m#{self}\e[27m" end

  def no_colors;  self.gsub /\e\[\d+m/, "" end
  def clear; "#{self}\e[0m" end
end

#
# Monkey Patch
#
module RSpec
  module Core
    module ExampleGroups
      extend Support::RecursiveConstMethods

      def self.assign_const(group)
        base_name   = base_name_for(group)
        const_scope = constant_scope_for(group)
        name        = disambiguate(base_name, const_scope)
        const_scope.const_set(name, group)
      end
  
      def self.constant_scope_for(group)
        const_scope = group.superclass
        const_scope = self if const_scope == ::RSpec::Core::ExampleGroup
        const_scope
      end
  
      def self.remove_all_constants
        constants.each do |constant|
          __send__(:remove_const, constant)
        end
      end
  
      def self.base_name_for(group) 
        #NOTE: CrossN
        #
        # MonkeyPatched to get nicer names in the display
        #
        return "Anonymous".dup if group.description.empty?

        # Convert to CamelCase.
        name = ' ' + group.description
        # name.gsub!(/[^0-9a-zA-Z]+([0-9a-zA-Z])/) do
        #   match = ::Regexp.last_match[1]
        #   match.upcase!
        #   match
        # end
  
        # My Not_So_Camel_Case
        #name = name.split(' ').map{|w| w.sub(/^./, &:upcase)}.join('_')
        name = name.split(' ').join('_')
  
        name.lstrip!                # Remove leading whitespace
        #name.gsub!(/\W/, ''.freeze) # JRuby, RBX and others don't like non-ascii in const names
        name.gsub!(/\W/, '_'.freeze) # My non-ascii replacement

        # Ruby requires first const letter to be A-Z. Use `Nested`
        # as necessary to enforce that.
        name.gsub!(/\A([^A-Z]|\z)/, 'Nested\1'.freeze)
  
        name
      end
  
      if RUBY_VERSION == '1.9.2'
        # :nocov:
        class << self
          alias _base_name_for base_name_for
          def base_name_for(group)
            _base_name_for(group) + '_'
          end
        end
        private_class_method :_base_name_for
        # :nocov:
      end
  
      def self.disambiguate(name, const_scope)
        return name unless const_defined_on?(const_scope, name)
  
        # Add a trailing number if needed to disambiguate from an existing
        # constant.
        name << "_2"
        name.next! while const_defined_on?(const_scope, name)
        name
      end
    end
  end
end
## End MonkeyPatch

class Oopsy
  attr_reader :klass, :message, :backtrace, :highlighted_source, :explanation, :backtrace_message

  def initialize(example, file_path)
    @example = example
    @exception = @example.exception
    @file_path = file_path
    unless @exception.nil?
      @klass = @exception.class
      @message = @exception.message.force_encoding("utf-8") #.encode('utf-8') # CrossN
      @backtrace = @exception.backtrace
      @backtrace_message = formatted_backtrace(@example, @exception)
      @highlighted_source = process_source
      @explanation = process_message
    end
  end

  private

  def os
    @os ||= (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        :windows
      when /darwin|mac os/
        :macosx
      when /linux/
        :linux
      when /solaris|bsd/
        :unix
      else
        raise Exception, "unknown os: #{host_os.inspect}"
      end
    )
  end

  def formatted_backtrace(example, exception)
    # To avoid an error in format_backtrace. RSpec's version below v3.5 will throw exception.
    return [] unless example
    formatter = RSpec.configuration.backtrace_formatter
    formatter.format_backtrace(exception.backtrace, example.metadata)
  end

  def process_source
    return '' if @backtrace_message.empty?
    data = @backtrace_message.first.split(':')
    unless data.empty?
    if os == :windows
      file_path = data[0] + ':' + data[1]
      line_number = data[2].to_i
    else
       file_path = data.first
       line_number = data[1].to_i
    end
    lines = File.readlines(file_path)
    start_line = line_number-2
    end_line = line_number+3
    source = lines[start_line..end_line].join("").sub(lines[line_number-1].chomp, "--->#{lines[line_number-1].chomp}")

    formatter = Rouge::Formatters::HTML.new(css_class: 'highlight', line_numbers: true, start_line: start_line+1)
    lexer = Rouge::Lexers::Ruby.new
    formatter.format(lexer.lex(source.encode('utf-8')))
    end
  end

  def process_message
    formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
    lexer = Rouge::Lexers::Ruby.new
    formatter.format(lexer.lex(@message))
  end

end

class Example

  def self.load_spec_comments!(examples)
    examples.group_by(&:file_path).each do |file_path, file_examples|
      lines = File.readlines(file_path)

      file_examples.zip(file_examples.rotate).each do |ex, next_ex|
        lexically_next = next_ex &&
          next_ex.file_path == ex.file_path &&
          next_ex.metadata[:line_number] > ex.metadata[:line_number]
        start_line_idx = ex.metadata[:line_number] - 1
        next_start_idx = (lexically_next ? next_ex.metadata[:line_number] : lines.size) - 1
        spec_lines = lines[start_line_idx...next_start_idx].select { |l| l.match(/#->/) }
        ex.set_spec(spec_lines.join) unless spec_lines.empty?
      end
    end
  end

  attr_reader :example_group, :description, :full_description, :run_time, :duration, :status, :exception, :file_path, :metadata, :spec, :screenshots, :screenrecord, :failed_screenshot

  def initialize(example)
    @example_group = example.example_group.to_s
    @description = example.description
    @full_description = example.full_description
    @execution_result = example.execution_result
    @run_time = (@execution_result.run_time).round(5)
    @duration = @execution_result.run_time.to_s(:rounded, precision: 5)
    @status = @execution_result.status.to_s
    @metadata = example.metadata
    @file_path = @metadata[:file_path]
    @exception = Oopsy.new(example, @file_path)
    @spec = nil
    @screenshots = @metadata[:screenshots]
    @screenrecord = @metadata[:screenrecord]
    @failed_screenshot = @metadata[:failed_screenshot]
    #CrossN
    @skip = example.skip
    @pending_message = @execution_result.pending_message # ? @execution_result.pending_message : ''
  end

  #CrossN
  def has_skip?
    !@skip.nil?
  end

  def skipped_message
    @pending_message
  end

  def example_title
    # title_arr = @example_group.to_s.split('::') - ['RSpec', 'ExampleGroups']

    # # Remove 'Nested' from the description
    # title_arr.reject!{|e| e== 'Nested'}
    # title_arr.map!{|s| s.gsub(/Nested/, '')}
    # title_arr.map!{|s| s.gsub(/_/, ' ')}

    # title_arr.push @full_description
    # title_arr.join(' → ')

    @full_description
  end

  def has_exception?
    !@exception.klass.nil?
  end

  def has_spec?
    !@spec.nil?
  end

  def has_screenshots?
    !@screenshots.nil? && !@screenshots.empty?
  end

  def has_screenrecord?
    !@screenrecord.nil?
  end

  def has_failed_screenshot?
    !@failed_screenshot.nil?
  end

  def set_spec(spec_text)
    formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
    lexer = Rouge::Lexers::Gherkin.new
    @spec = formatter.format(lexer.lex(spec_text.gsub('#->', '')))
  end

  def klass(prefix='label-')
    class_map = {passed: "#{prefix}success", failed: "#{prefix}danger", pending: "#{prefix}warning"}
    class_map[@status.to_sym]
  end

end

class RspecHtmlReporter < RSpec::Core::Formatters::BaseFormatter

  DEFAULT_REPORT_PATH = File.join(Bundler.root, 'reports', Time.now.strftime('%Y%m%d-%H%M%S'))
  REPORT_PATH = ENV['REPORT_PATH'] || DEFAULT_REPORT_PATH

  SCREENRECORD_DIR = File.join(REPORT_PATH, 'screenrecords')
  SCREENSHOT_DIR   = File.join(REPORT_PATH, 'screenshots')
  RESOURCE_DIR     = File.join(REPORT_PATH, 'resources')

  RSpec::Core::Formatters.register self, :example_started, :example_passed, :example_failed, :example_pending, :example_group_finished

  def initialize(io_standard_out)
    create_reports_dir
    create_screenshots_dir
    create_screenrecords_dir
    copy_resources
    @all_groups = {}

    @group_level = 0
  end

  def example_group_started(notification) # NOTE: this is not registered/called
    if @group_level == 0
      @example_group = {}
      @examples = []
      @group_example_count = 0
      @group_example_success_count = 0
      @group_example_failure_count = 0
      @group_example_pending_count = 0
      #@example_description = []
    end

    @group_level += 1

  end

  def example_started(notification)
    @group_example_count += 1
  end

  def example_passed(notification)
    print "*".green
    @group_example_success_count += 1
    @examples << Example.new(notification.example)
  end

  def example_failed(notification)
    print "F".bg_red
    @group_example_failure_count += 1
    @examples << Example.new(notification.example)
  end

  def example_pending(notification)
    print ".".cyan
    @group_example_pending_count += 1
    @examples << Example.new(notification.example)
  end

  def example_group_finished(notification)
    @group_level -= 1

    if @group_level == 0
      File.open("#{REPORT_PATH}/#{notification.group.description.parameterize}.html", 'w') do |f|

        @passed = @group_example_success_count
        @failed = @group_example_failure_count
        @pending = @group_example_pending_count

        duration_values = @examples.map { |e| e.run_time }

        duration_keys = duration_values.size.times.to_a
        if duration_values.size < 2 and duration_values.size > 0
          duration_values.unshift(duration_values.first)
          duration_keys = duration_keys << 1
        end

        @title = notification.group.description # used in html template
        @durations = duration_keys.zip(duration_values)

        @summary_duration = duration_values.inject(0) { |sum, i| sum + i }.to_s(:rounded, precision: 5)
        Example.load_spec_comments!(@examples)

        class_map = {passed: 'success', failed: 'danger', pending: 'warning'}
        statuses = @examples.map { |e| e.status }
        status = statuses.include?('failed') ? 'failed' : (statuses.include?('passed') ? 'passed' : 'pending')
        @all_groups[notification.group.description.parameterize] = {
            group: notification.group.description,
            examples: @examples.size,
            status: status,
            klass: class_map[status.to_sym],
            passed: statuses.select { |s| s == 'passed' },
            failed: statuses.select { |s| s == 'failed' },
            pending: statuses.select { |s| s == 'pending' },
            duration: @summary_duration
        }

        template_file = File.read(File.dirname(__FILE__) + '/../templates/report.erb')

        f.puts ERB.new(template_file).result(binding)
      end
    end
  end

  def close(notification)
    File.open("#{REPORT_PATH}/overview.html", 'w') do |f|
      @overview = @all_groups

      @passed = @overview.values.map { |g| g[:passed].size }.inject(0) { |sum, i| sum + i }
      @failed = @overview.values.map { |g| g[:failed].size }.inject(0) { |sum, i| sum + i }
      @pending = @overview.values.map { |g| g[:pending].size }.inject(0) { |sum, i| sum + i }

      duration_values = @overview.values.map { |e| e[:duration] }

      duration_keys = duration_values.size.times.to_a
      if duration_values.size < 2
        duration_values.unshift(duration_values.first)
        duration_keys = duration_keys << 1
      end

      @durations = duration_keys.zip(duration_values.map{|d| d.to_f.round(5)})
      @summary_duration = duration_values.map{|d| d.to_f.round(5)}.inject(0) { |sum, i| sum + i }.to_s(:rounded, precision: 5)
      @total_examples = @passed + @failed + @pending
      template_file = File.read(File.dirname(__FILE__) + '/../templates/overview.erb')
      f.puts ERB.new(template_file).result(binding)
    end

    puts "\ndone".clear
  end

  private
  def create_reports_dir
    FileUtils.rm_rf(REPORT_PATH) if File.exists?(REPORT_PATH)
    FileUtils.mkpath(REPORT_PATH)
  end

  def create_screenshots_dir
    FileUtils.mkdir_p SCREENSHOT_DIR unless File.exists?(SCREENSHOT_DIR)
  end

  def create_screenrecords_dir
    FileUtils.mkdir_p SCREENRECORD_DIR unless File.exists?(SCREENRECORD_DIR)
  end

  def copy_resources
    FileUtils.cp_r(File.dirname(__FILE__) + '/../resources', REPORT_PATH)
  end
end
