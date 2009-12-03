# acts_as_setting
#
# Copyright (c) 2009 Trond Arve Nordheim
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# -----------------------------------------------------------------------------

module ActsAsSetting

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    # Include the acts_as_setting methods in the class instance
    # -------------------------------------------------------------------------
    def acts_as_setting(options = {})

      @@settings = YAML::load(File.open("#{RAILS_ROOT}/config/settings.yml"))
      self.extend(InstanceMethods)

      # Add validation
      validates_uniqueness_of :key
      validates_presence_of :value, :if => Proc.new { |s| @@settings[s.key]["required"] }

      validates_numericality_of :value, :only_integer => true, :if => Proc.new { |s|
        @@settings[s.key]["format"] == "number"
      }

      validates_format_of :value, :with => self.email_pattern, :if => Proc.new { |s|
        @@settings[s.key]["format"] == "email"
      }

      # Add methods to be able to look up and assign settings based on the
      # setting key directly without having to use the map lookup/assignment
      @@settings.keys.each do |key|
        methods = <<-END_KEY_METHODS

          def self.#{key}
            self[:#{key}]
          end

          def self.#{key}=(value)
            self[:#{key}] = value
          end

        END_KEY_METHODS
        class_eval methods, __FILE__, __LINE__
      end

    end

    # Map style lookup for the class
    # -------------------------------------------------------------------------
    def [](key)
      find_setting(key.to_s).value
    end

    # Map style assignment for the class
    # -------------------------------------------------------------------------
    def []=(key, value)

      setting = find_setting(key.to_s)
      setting.value = value
      setting.save

      setting.value

    end

    protected

      # Find the setting with the specified key, or use the default data from
      # the YAML file unless it exists in the database
      # -----------------------------------------------------------------------
      def find_setting(key)

        raise "Unknown setting key: #{key}" unless @@settings.has_key?(key)
        setting = find_by_key(key)
        setting ||= new(:key => key, :value => find_default_value(key))

      end

      # Find the default value for the specified setting key using the YAML
      # file
      # -----------------------------------------------------------------------
      def find_default_value(key)

        default_setting = @@settings.has_key?(key) ? @@settings[key] : nil
        default_value = nil

        unless default_setting.nil?

          default_value = convert_format(@@settings[key]["default"], @@settings[key]["format"])

        end

        default_value

      end

      # Convert the value into the specified format
      # -----------------------------------------------------------------------
      def convert_format(value, format)

        unless value.blank?
          value = value.to_i if format == "number"
        end

        value

      end

      # E-mail regular expression pattern. Copied from Authlogic.
      # -----------------------------------------------------------------------
      def email_pattern

        return @email_pattern if @email_pattern

        email_name_regex = '[A-Z0-9_\.%\+\-]+'
        domain_head_regex = '(?:[A-Z0-9\-]+\.)+'
        domain_tld_regex = '(?:[A-Z]{2,4}|museum|travel)'
        @email_pattern = /^#{email_name_regex}@#{domain_head_regex}#{domain_tld_regex}$/i

      end

  end

  module InstanceMethods

    # Get the value of the current setting
    # -------------------------------------------------------------------------
    def value
      self.convert_format(read_attribute(:value), @@settings[key]["format"])
    end

    # Set the value of the current setting
    # -------------------------------------------------------------------------
    def value=(value)
      write_attribute(:value, value.to_s)
    end

  end

end

