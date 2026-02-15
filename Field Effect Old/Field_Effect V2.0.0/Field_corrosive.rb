class Battle::Field_corrosive < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :corrosive
    @name                = _INTL("Corrosive")
    @nature_power_change = :ACID
    @mimicry_type        = :NORMAL
    @camouflage_type     = :POISON
    @terrain_pulse_type  = :POISON
    @secret_power_effect = 2 # need to change to poison
    @shelter_type        = :POISON
    @field_announcement  = { :start => _INTL("The field is corrupted"),
                             :end   => _INTL("The field is clear!") }


  end
end

Battle::Field.register(:corrosive, {
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