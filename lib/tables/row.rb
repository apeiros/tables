# encoding: utf-8

module Tables
  class Row
    attr_reader :table
    attr_reader :index
    attr_reader :data

    def initialize(table, index, data)
      @table  = table
      @index  = index
      @data   = data
    end

    # @see #slice for a faster way to use ranges or offset+length
    # @see #at_accessor for a faster way to access by name
    # @see #at_index for a faster way to access by index
    def [](a,b=nil)
      if b || a.is_a?(Range) then
        slice(a,b)
      else
        at(a)
      end
    end

    def slice(*args)
      @data[*args]
    end

    def at(column)
      case column
        when Symbol then at_accessor(column)
        when String then at_header(column)
        when Integer then at_index(column)
        else raise ArgumentError, "Invalid index type, expected Symbol, String or Integer, but got #{column.class}"
      end
    end

    def at_header(name)
      index = @table.index_for_header(a)
      raise NameError, "No column named #{a}" unless index

      @data[index]
    end

    def at_accessor(name)
      index = @table.index_for_accessor(a)
      raise NameError, "No column named #{a}" unless index

      @data[index]
    end

    def at_index(index)
      @data.at(index)
    end

    def values_at(*columns)
      columns.map { |column| at(column) }
    end

    def size
      @data.size
    end

    alias to_a data

    def respond_to_missing?(name, include_private)
      @table.index_for_accessor(name) ? true : false
    end

    def method_missing(name, *args, &block)
      return super unless @table.accessors?

      name          =~ /^(\w+)(=)?$/
      name, assign  = $1, $2
      index         = @table.index_for_accessor(name)
      arg_count     = assign ? 1 : 0

      return super unless index

      raise ArgumentError, "Wrong number of arguments (#{args.size} for #{arg_count})" if args.size > arg_count

      if assign then
        @data[index] = args.first
      else
        @data.at(index)
      end
    end
  end
end
