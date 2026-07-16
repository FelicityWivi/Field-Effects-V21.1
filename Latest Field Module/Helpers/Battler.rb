class Battle::Battler
  alias grounded? affectedByTerrain?

  def unique_id
    @pokemon.unique_id
  end

  def mono_type?
    pbTypes(true).length < 2 
  end

  def owner_side_all_fainted?
    @battle.pbParty(@index).all?(&:fainted?)
  end
end