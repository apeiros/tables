# encoding: utf-8

require 'tabledata/table'
require 'tabledata/coerced_row'

module Tabledata

  class CustomTable < Table
    class << self
      attr_reader :definition
    end

    def self.table_name
      @definition.table_name
    end

    def self.identifier
      @definition.identifier
    end

    def self.from_file(path, options=nil)
      options        ||= {}
      options[:name] ||= @definition.table_name

      super(path, options)
    end

    attr_reader :table_errors, :original_data, :original_rows

    def initialize(options)
      definition = self.class.definition
      columns    = definition.columns
      options    = options.merge(accessors: columns.map(&:accessor), name: definition.table_name) { |key,v1,v2|
        if key == :accessors
          raise "Can't handle reordering of accessors - don't redefine accessors in CustomTables for now"
        elsif key == :name
          v1 || v2
        end
      }

      super(options)

      @table_errors  = []
      @original_data = @data
      @original_rows = @rows

      @rows = @rows.map.with_index { |row, row_index|
        column_errors = {}
        coerced_values = *row.map.with_index { |value, column_index|
          column = columns[column_index]
          value, errors = column.coerce(value)
          column_errors[column.accessor] = errors unless errors.empty?
        }
        row_errors = []
        CoercedRow.new(self, row_index, coerced_values, column_errors, row_errors)
      }
      @data = @rows.map(&:to_a)
    end

    def <<(row)
      columns       = self.class.definition.columns
      index         = @data.size
      column_errors = {}

      begin
        row = row.to_ary
      rescue NoMethodError
        raise ArgumentError, "Row must be provided as Array or respond to `to_ary`, but got #{row.class} in row #{index}" unless row.respond_to?(:to_ary)
        raise
      end
      raise InvalidColumnCount.new(index, row.size, column_count) if @data.first && row.size != @data.first.size

      if index > 0 || !@has_headers
        coerced_values = *row.map.with_index { |value, column_index|
          column                         = columns[column_index]
          value, errors                  = column.coerce(value)
          column_errors[column.accessor] = errors unless errors.empty?

          value
        }
        row_errors = []
      else
        coerced_values = row.dup
        row_errors     = []
      end

      @original_data << row
      @original_rows << Row.new(self, index, row)
      @data << coerced_values
      @rows << CoercedRow.new(self, index, coerced_values, column_errors, row_errors)

      self
    end

    def valid?
      @table_errors.empty? && @rows.all?(&:valid?)
    end
  end
end
