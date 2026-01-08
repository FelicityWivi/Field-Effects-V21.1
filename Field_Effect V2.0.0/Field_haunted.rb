class Battle::Field_haunted < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :haunted
    @name                = _INTL("Haunted")
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

Battle::Field.register(:haunted, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# All HP-restoring effects from moves and held items are reduced by 33%. Bag items are unaffected.
# Hustle now boosts damage by 75%, but lowers accuracy by 33%.
#     Corrosive Gas additionally lowers all of the target's stats by 1 stage.
# Pursuit additionally boosts the user's Speed by 1 stage if the move KO's the target.
# Z-Conversion boosts all of the user's stats by 2 stages.