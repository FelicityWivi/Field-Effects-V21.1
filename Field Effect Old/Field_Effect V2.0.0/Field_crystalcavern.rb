class Battle::Field_crystalcavern < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :crystalcavern
    @name                = _INTL("Crystal Cavern")
    @nature_power_change = :BEATUP
    @mimicry_type        = :NORMAL
    @camouflage_type     = :STEEL
    @terrain_pulse_type  = :STEEL
    @secret_power_effect = 2 # need to change to poison
    @shelter_type        = :STEEL
    @field_announcement  = { :start => _INTL("Shifty eyes are all around..."),
                             :end   => _INTL("The street is cleared!") }

  end
end

Battle::Field.register(:crystalcavern, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})
