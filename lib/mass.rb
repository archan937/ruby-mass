# == Mass
#
# This module offers the following either within the whole Ruby Heap or narrowed by namespace:
#
# - indexing objects grouped by class
# - counting objects grouped by class
# - printing objects grouped by class
# - locating references to a specified object
# - detaching references to a specified object (in order to be able to release the object memory using the GC)
#
module Mass
  extend self

  # Returns the object corresponding to the passed object_id.
  #
  # ==== Example
  #
  #   log_line = LogLine.new
  #   object = Mass[log_line.object_id]
  #   log_line.object_id == object.object_id #=> true
  #
  def [](object_id)
    ObjectSpace._id2ref object_id
  end

  # A helper method after having called <tt>Mass.detach</tt>. It instructs the garbage collector to start when the optional passed variable is nil.
  #
  def gc!(variable = nil)
    GC.start if variable.nil?
  end

  # Returns a hash containing classes with the object_ids of its instances currently in the Ruby Heap. You can narrow the result by namespace.
  #
  def index(*mods)
    instances_within(*mods).inject({}) do |hash, object|
      ((hash[object.class.name] ||= []) << object.object_id).sort! if object.methods.collect(&:to_s).include?("class")
      hash
    end
  end

  # Returns a hash containing classes with the amount of its instances currently in the Ruby Heap. You can narrow the result by namespace.
  #
  def count(*mods)
    index(*mods).inject({}) do |hash, (key, value)|
      hash[key] = value.size
      hash
    end
  end

  # Prints all object instances within either the whole environment or narrowed by namespace group by class.
  #
  def print(*mods)
    stats = count(*mods)
    puts "\n"
    puts "=" * 50
    puts " Objects within #{mods ? "#{mods.collect(&:name).sort} namespace" : "environment"}"
    puts "=" * 50
    stats.keys.sort{|a, b| [stats[b], a] <=> [stats[a], b]}.each do |key|
      puts "  #{key}: #{stats[key]}"
    end
    puts " - no objects instantiated -" if stats.empty?
    puts "=" * 50
    puts "\n"
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
  #   Mass.references(a1) #=> {}
  #
  #   a2 = A.new
  #   a2.object_id #=> 2152675940
  #   a2.a = a1
  #
  #   b = B.new
  #   b.object_id #=> 2152681800
  #   b.a = a1
  #
  #   Mass.references(a1) #=> {"A#2152675940" => ["@a"], "B#2152681800" => ["@a"]}
  #   Mass.references(a1, A) #=> {"A#2152675940" => ["@a"]}
  #   Mass.references(a1, B) #=> {"B#2152681800" => ["@a"]}
  #   Mass.references(a1, Hash) #=> {}
  #
  def references(object, *mods)
    return {} if object.nil?
    object._reference_instances(*mods).inject({}) do |hash, instance|
      unless (refs = extract_references(instance, object)).empty?
        hash["#{instance.class.name}##{instance.object_id}"] = refs.collect(&:to_s).sort{|a, b| a <=> b}
      end
      hash
    end
  end

  # Removes all references to the passed object and yielding block when given and references within entire environment removed successfully. Use at own risk.
  #
  def detach(object, *mods, &block)
    _detach(object, object._reference_instances(*mods), true, &block)
  end

  # Removes all references to the passed object and yielding block when given and references within passed namespaces removed successfully. Use at own risk.
  #
  def detach!(object, *mods, &block)
    _detach(object, object._reference_instances(*mods), false, &block)
  end

private

  # Removes all references to the passed object, yielding block when given and removed references successfully.
  def _detach(object, instances, check_environment, &block)
    return false if object.nil?
    instances = instances.inject([]) do |array, instance|
      references = extract_references(instance, object)
      unless references.empty? || array.any?{|x| x[0].object_id == instance.object_id}
        array << [instance, references]
      end
      array
    end
    removed = instances.all? do |(instance, references)|
      references.all? do |name|
        remove_references(instance, object, name)
      end
    end
    (removed && (!check_environment || references(object).empty?)).tap do |detached|
      yield if detached && block_given?
    end
  end

  # Returns all classes within a certain namespace.
  #
  def classes_within(mods, initial_array = nil)
    (initial_array || mods.select{|mod| mod.is_a? Class}).tap do |array|
      mods.each do |mod|
        mod.constants.each do |c|
          const = mod.const_get c
          if !array.include?(const) && (const.is_a?(Class) || const.is_a?(Module)) && const.name.match(/^#{mod.name}/)
            if const.is_a?(Class)
              array << const
            end
            if const.is_a?(Class) || const.is_a?(Module)
              classes_within([const], array)
            end
          end
        end
      end
    end
  end

  # Return all instances. You can narrow the results by passing a namespace.
  #
  def instances_within(*mods)
    GC.start
    [].tap do |array|
      if mods.empty?
        ObjectSpace.each_object do |object|
          array << object
        end
      else
        classes_within(mods).each do |klass|
          ObjectSpace.each_object(klass) do |object|
            array << object
          end
        end
      end
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

  # Extracts and returns all references between the passed object and instance.
  #
  def extract_references(instance, object)
    instance.instance_variables.select do |name|
      matches? instance.instance_variable_get(name), object
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

end