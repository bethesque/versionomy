# -----------------------------------------------------------------------------
# 
# Versionomy value
# 
# -----------------------------------------------------------------------------
# Copyright 2008-2009 Daniel Azuma
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------
;


module Versionomy
  
  
  # === Version number value
  # 
  # A version number value is an ordered list of values, corresponding to an
  # ordered list of fields defined by a schema. For example, if the schema
  # is a simple one of the form "major.minor.tiny", then the the version
  # number "1.4.2" would have the values <tt>[1, 4, 2]</tt> in that order,
  # corresponding to the fields <tt>[:major, :minor, :tiny]</tt>.
  # 
  # Version number values are comparable with other values that have an
  # equivalent schema.
  
  class Value
    
    
    # Create a value, given a hash or array of values, and a format. Both
    # these parameters are required.
    # 
    # The values should either be a hash of field names and values, or an
    # array of values that will be interpreted in field order.
    # 
    # You can also optionally provide default unparsing parameters for the
    # value.
    
    def initialize(values_, format_, unparse_params_=nil)
      unless values_.kind_of?(::Hash) || values_.kind_of?(::Array)
        raise ::ArgumentError, "Expected hash or array but got #{values_.class}"
      end
      @format = format_
      @unparse_params = unparse_params_
      @field_path = []
      @values = {}
      field_ = @format.schema.root_field
      while field_
        value_ = values_.kind_of?(Hash) ? values_[field_.name] : values_.shift
        value_ = value_ ? field_.canonicalize_value(value_) : field_.initial_value
        @field_path << field_
        @values[field_.name] = value_
        field_ = field_.child(value_)
      end
    end
    
    
    def inspect  # :nodoc:
      begin
        str_ = unparse
        "#<#{self.class}:0x#{object_id.to_s(16)} #{str_.inspect}>"
      rescue Errors::UnparseError
        _inspect
      end
    end
    
    def _inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        @field_path.map{ |field_| "#{field_.name}=#{@values[field_.name].inspect}" }.join(' ')
    end
    
    
    # Returns a string representation generated by unparsing.
    # If unparsing fails, does not raise Versionomy::Errors::UnparseError,
    # but instead returns the string generated by +inspect+.
    
    def to_s
      begin
        unparse
      rescue Errors::UnparseError
        _inspect
      end
    end
    
    
    # Unparse this version number.
    # 
    # Raises Versionomy::Errors::UnparseError if unparsing failed.
    
    def unparse(params_=nil)
      @format.unparse(self, params_)
    end
    
    
    # Return the schema defining the form of this version number
    
    def schema
      @format.schema
    end
    
    
    # Return the format defining the form of this version number
    
    def format
      @format
    end
    
    
    # Return the unparsing parameters for this value.
    # Returns nil if this value was not created using a parser.
    
    def unparse_params
      @unparse_params ? @unparse_params.dup : nil
    end
    
    
    # Iterates over each field, in field order, yielding the field name and value.
    
    def each_field
      @field_path.each do |field_|
        yield(field_, @values[field_.name])
      end
    end
    
    
    # Iterates over each field, in field order, yielding the
    # Versionomy::Schema::Field object and value.
    
    def each_field_object  # :nodoc:
      @field_path.each do |field_|
        yield(field_, @values[field_.name])
      end
    end
    
    
    # Returns an array of recognized field names for this value, in field order.
    
    def field_names
      @field_path.map{ |field_| field_.name }
    end
    
    
    # Returns true if this value contains the given field, which may be specified
    # as a field object or name.
    
    def has_field?(field_)
      case field_
      when Schema::Field
        @field_path.include?(field_)
      when ::String, ::Symbol
        @values.has_key?(field_.to_sym)
      else
        raise ::ArgumentError
      end
    end
    
    
    # Returns the value of the given field, or nil if the field is not recognized.
    # The field may be specified as a field object or field name.
    
    def [](field_)
      field_ = field_.name if field_.kind_of?(Schema::Field)
      @values[field_.to_sym]
    end
    
    
    # Returns the value as an array of field values, in field order.
    
    def values_array
      @field_path.map{ |field_| @values[field_.name] }
    end
    
    
    # Returns the value as a hash of values keyed by field name.
    
    def values_hash
      @values.dup
    end
    
    
    # Returns a new version number created by bumping the given field.
    
    def bump(name_)
      name_ = name_.name if name_.kind_of?(Schema::Field)
      name_ = name_.to_sym
      values_ = []
      @field_path.each do |field_|
        oldval_ = @values[field_.name]
        if field_.name == name_
          newval_ = field_.bump_value(oldval_)
          return self if newval_ == oldval_
          values_ << newval_
          return Value.new(values_, @format, @unparse_params)
        else
          values_ << oldval_
        end
      end
      self
    end
    
    
    # Returns a new version number created by changing the given field values.
    
    def change(values_={}, unparse_params_={})
      unparse_params_ = @unparse_params.merge(unparse_params_) if @unparse_params
      Value.new(@values.merge(values_), @format, unparse_params_)
    end
    
    
    def hash  # :nodoc:
      @hash ||= @values.hash
    end
    
    
    # Returns true if this version number is equal to the given verison number.
    # Equality means the schemas and values are the same.
    
    def eql?(obj_)
      if obj_.kind_of?(::String)
        obj_ = @format.parse(obj_) rescue nil
      end
      return false unless obj_.kind_of?(Value)
      index_ = 0
      obj_.each_field_object do |field_, value_|
        return false if field_ != @field_path[index_] || value_ != @values[field_.name]
        index_ += 1
      end
      true
    end
    
    
    # Returns true if this version number is equal to the given verison number.
    # Equality means the schemas and values are the same.
    
    def ==(obj_)
      eql?(obj_)
    end
    
    
    # Compare this version number with the given version number.
    
    def <=>(obj_)
      if obj_.kind_of?(::String)
        obj_ = @format.parse(obj_)
      end
      return nil unless obj_.kind_of?(Value)
      index_ = 0
      obj_.each_field_object do |field_, value_|
        return nil unless field_ == @field_path[index_]
        val_ = field_.compare_values(@values[field_.name], value_)
        return val_ if val_ != 0
        index_ += 1
      end
      0
    end
    
    
    # Compare this version number with the given version number.
    
    def <(obj_)
      val_ = (self <=> obj_)
      unless val_
        raise Errors::SchemaMismatchError
      end
      val_ < 0
    end
    
    
    # Compare this version number with the given version number.
    
    def >(obj_)
      val_ = (self <=> obj_)
      unless val_
        raise Errors::SchemaMismatchError
      end
      val_ > 0
    end
    
    
    # Field values may be retrieved by calling them as methods.
    
    def method_missing(symbol_)
      self[symbol_] || super
    end
    
    
  end
  
  
end
