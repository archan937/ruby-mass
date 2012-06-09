module Objects
  extend self

  def [](object_id)
    ObjectSpace._id2ref object_id
  end

  def references(object, mod = nil)
    instances_within(mod).inject({}) do |hash, instance|
      unless (refs = extract_references(instance, object)).empty?
        hash["#{instance.class.name}##{instance.object_id}"] = refs.sort{|a, b| a.to_s <=> b.to_s}
      end
      hash
    end
  end

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

  def print(mod = nil)
    count(mod).tap do |stats|
      puts "\n\n"
      puts "=" * 50
      puts " Objects within #{mod ? "#{mod.name} namespace" : "environment"}"
      puts "=" * 50
      puts "\n"
      stats.keys.sort{|a, b| [stats[b], a] <=> [stats[a], b]}.each do |key|
        puts "  #{key}: #{stats[key]}"
      end
      puts "  (no objects instantiated)" if stats.empty?
      puts "\n"
      puts "=" * 50
      puts "\n\n"
    end
    nil
  end

  def count(mod = nil)
    group(mod).inject({}) do |hash, (key, value)|
      hash[key] = value.size
      hash
    end
  end

  def group(mod = nil)
    instances_within(mod).inject({}) do |hash, object|
      (hash[object.class.name] ||= []) << object.object_id
      hash
    end
  end

private

  def extract_references(instance, object)
    instance.instance_variables.select do |name|
      matches? instance.instance_variable_get(name), object
    end
  end

  def matches?(variable, object)
    if variable.object_id == object.object_id
      true
    elsif variable.is_a?(Array) || variable.is_a?(Hash)
      variable.any?{|x| matches? x, object}
    else
      false
    end
  end

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