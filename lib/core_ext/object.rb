class Object

  def self.detach_all
    Mass.index(self.class)[self.class.name].each{|object_id| Mass[object_id].detach}
  end

  def self.detach_all!
    Mass.index(self.class)[self.class.name].each{|object_id| Mass[object_id].detach!}
  end

  def _reference_instances(*mods)
    Mass.send(:instances_within, *mods)
  end

  def references(*mods)
    Mass.references(self, *mods)
  end

  def detach(*mods, &block)
    Mass.detach(self, *mods, &block)
  end

  def detach!(*mods, &block)
    Mass.detach!(self, *mods, &block)
  end

end