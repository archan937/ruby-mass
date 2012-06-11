class Object

  # A convenience method for detaching all class instances with detach
  #
  def self.detach_all
    Mass.index(self.class)[self.class.name].each{|object_id| Mass[object_id].detach}
  end

  # A convenience method for detaching all class instances with detach!
  #
  def self.detach_all!
    Mass.index(self.class)[self.class.name].each{|object_id| Mass[object_id].detach!}
  end

  # Mass uses this method to derive object references. Override this method for increasing performance.
  # In order to override this method, you would probably want to use <tt>Mass.references</tt> of a sample instance.
  #
  def _reference_instances(*mods)
    Mass.send(:instances_within, *mods)
  end

  # A convenience method for Mass.references
  #
  def _references(*mods)
    Mass.references(self, *mods)
  end

  # A convenience method for Mass.detach
  #
  def detach(*mods, &block)
    Mass.detach(self, *mods, &block)
  end

  # A convenience method for Mass.detach!
  #
  def detach!(*mods, &block)
    Mass.detach!(self, *mods, &block)
  end

end