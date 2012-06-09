# == Objects
#
# This module offers the following either within the whole Ruby Heap or narrowed by namespace:
#
# - listing objects grouped by class
# - counting objects grouped by class
# - printing objects grouped by class
# - locating references to a specified object
# - detaching references to a specified object (in order to be able to release the object memory using the GC)
#
module Objects
  extend self

  # Returns the object corresponding to the passed object_id.
  #
  # ==== Example
  #
  #   log_line = LogLine.new
  #   object = Objects[log_line.object_id]
  #   log_line.object_id == object.object_id #=> true
  #
  def [](object_id)
    ObjectSpace._id2ref object_id
  end

  # Returns all references to the passed object. You can narrow the namespace of the objects referencing to the object.
  #
  # ==== Example
  #
  #   class A
  #     attr_accessor :a
  #   end
  #
  #   class B
  #     attr_accessor :a
  #   end
  #
  #   a1 = A.new
  #   Objects.references(a1) #=> {}
  #
  #   a2 = A.new
  #   a2.object_id #=> 2152675940
  #   a2.a = a1
  #
  #   b = B.new
  #   b.object_id #=> 2152681800
  #   b.a = a1
  #
  #   Objects.references(a1) #=> {"A#2152675940" => [:@a], "B#2152681800" => [:@a]}
  #   Objects.references(a1, A) #=> {"A#2152675940" => [:@a]}
  #   Objects.references(a1, B) #=> {"B#2152681800" => [:@a]}
  #   Objects.references(a1, Hash) #=> {}
  #
  def references(object, mod = nil)
    instances_within(mod).inject({}) do |hash, instance|
      unless (refs = extract_references(instance, object)).empty?
        hash["#{instance.class.name}##{instance.object_id}"] = refs.sort{|a, b| a.to_s <=> b.to_s}
      end
      hash
    end
  end

  # Removes all references to the passed object. Doing this ensures the GarbageCollect to free memory used by the object. Use at own risk.
  #
  def detach(object)
    detached = true
    instances_within(nil).each do |instance|
      extract_references(instance, object).each do |name|
        unless remove_references(instance, object, name)
          detached = false
        end
      end
    end
    GC.start
    detached
  end

  # Prints all object instances within either the whole environment or narrowed by namespace group by class.
  #
  def print(mod = nil)
    count(mod).tap do |stats|
      puts "\n"
      puts "=" * 50
      puts " Objects within #{mod ? "#{mod.name} namespace" : "environment"}"
      puts "=" * 50
      stats.keys.sort{|a, b| [stats[b], a] <=> [stats[a], b]}.each do |key|
        puts "  #{key}: #{stats[key]}"
      end
      puts " - no objects instantiated -" if stats.empty?
      puts "=" * 50
      puts "\n"
    end
    nil
  end

  # Returns a hash containing classes with the amount of its instances currently in the Ruby Heap. You can narrow the result by namespace.
  #
  def count(mod = nil)
    group(mod).inject({}) do |hash, (key, value)|
      hash[key] = value.size
      hash
    end
  end

  # Returns a hash containing classes with the object_ids of its instances currently in the Ruby Heap. You can narrow the result by namespace.
  #
  def group(mod = nil)
    instances_within(mod).inject({}) do |hash, object|
      (hash[object.class.name] ||= []) << object.object_id
      hash
    end
  end

private

  # Extracts and returns all references between the passed object and instance.
  #
  def extract_references(instance, object)
    instance.instance_variables.select do |name|
      matches? instance.instance_variable_get(name), object
    end
  end

  # Returns whether the variable equals with or references to (either nested or not) the passed object.
  #
  def matches?(variable, object)
    if variable.object_id == object.object_id
      true
    elsif variable.is_a?(Array) || variable.is_a?(Hash)
      variable.any?{|x| matches? x, object}
    else
      false
    end
  end

  # Removes the references between the passed object and instance.
  #
  def remove_references(instance_or_variable, object, name = nil)
    detached = true
    variable = name ? instance_or_variable.instance_variable_get(name) : instance_or_variable

    if name && variable.object_id == object.object_id
      instance_or_variable.send :remove_instance_variable, name
    elsif variable.is_a?(Array)
      detached = false
      variable.each do |value|
        if value.object_id == object.object_id
          detached = true
          variable.delete value
        elsif value.is_a?(Array) || value.is_a?(Hash)
          detached ||= remove_references(value, object)
        end
      end
    elsif variable.is_a?(Hash)
      detached = false
      variable.each do |key, value|
        if value.object_id == object.object_id
          detached = true
          variable.delete key
        elsif value.is_a?(Array) || value.is_a?(Hash)
          detached ||= remove_references(value, object)
        end
      end
    else
      detached = false
    end

    detached
  end

  # Return all instances. You can narrow the results by passing a namespace.
  #
  def instances_within(mod)
    GC.start
    [].tap do |array|
      if mod.nil?
        ObjectSpace.each_object do |object|
          array << object
        end
      else
        classes_within(mod).each do |klass|
          ObjectSpace.each_object(klass) do |object|
            array << object
          end
        end
      end
    end
  end

  # Returns all classes within a certain namespace.
  #
  def classes_within(mod, initial_array = nil)
    mod.constants.inject(initial_array || [(mod if mod.is_a? Class)].compact) do |array, c|
      const = mod.const_get c

      if !array.include?(const) && (const.is_a?(Class) || const.is_a?(Module)) && const.name.match(/^#{mod.name}/)
        if const.is_a?(Class)
          array << const
        end
        if const.is_a?(Class) || const.is_a?(Module)
          classes_within(const, array)
        end
      end

      array
    end
  end

end