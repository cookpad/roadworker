class Struct
  def pretty_print(q)
    self.to_h.pretty_print(q)
  end

  def pretty_print_cycle(q)
    self.to_h.pretty_print_cycle(q)
  end
end
