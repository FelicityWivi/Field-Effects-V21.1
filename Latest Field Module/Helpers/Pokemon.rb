class Pokemon
  def unique_id
    @unique_id ||= generate_unique_id
  end

  def regenerate_unique_id(digits = 8)
    @unique_id = generate_unique_id(digits)
  end

  def mono_type?
    types.length < 2 
  end
end