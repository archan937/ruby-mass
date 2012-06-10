class Object

  def _reference_instances(*mods)
    Mass.send(:instances_within, *mods)
  end

  def detach(*mods, &block)
    Mass.detach(self, *mods, &block)
  end

  def detach!(*mods, &block)
    Mass.detach!(self, *mods, &block)
  end

end