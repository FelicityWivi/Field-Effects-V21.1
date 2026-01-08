class Battle::Field_desert < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :desert
    @name                = _INTL("Desert")
    @nature_power_change = :SANDTOMB
    @mimicry_type        = :GROUND
    @camouflage_type     = :GROUND
    @terrain_pulse_type  = :GROUND
    @ability_activation  = %i[SANDFORCE SANDRUSH SANDVEIL]
    @secret_power_effect = 8 # lower accuracy
    @shelter_type        = :GROUND # halves damage taken from ground type moves after using shelter
    @field_announcement  = { :start    => _INTL("The field is rife with sand."),
                             :end      => _INTL("The shore recedes from the battlefield!") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("The desert strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[BURNUP DIG NEEDLEARM HEATWAVE PINMISSILE SANDTOMB SANDSEARSTORM SCALD SCORCHINGSANDS SOLARBEAM SOLARBLADE STEAMERUPTION THOUSANDWAVES].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("The lifeless desert strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[BONEMERANG BONECLUB BONERUSH SHADOWBONE].include?(move.id)
      },
      [:power_multiplier, 0.5, _INTL("The desert softened the attack...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[WATER].include?(type) && user.grounded?
      },
      [:power_multiplier, 0.5, _INTL("The desert softened the attack...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ELECTRIC].include?(type) && target.grounded?
      },
    }
  end
end

Battle::Field.register(:desert, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# Scald & Steam eruption normal amount of power
#    Sun and Sandstorm weather last for 8 turns.
#    Sandstorm deals 1/8 max HP damage each turn.
#     When the weather is Sunny:
#        Grass and Water-type Pokémon take 1/8 max HP damage at the end of each turn unless they have one of the abilities Solar Power or Chlorophyll.
#           [Pokémon] was hurt by the sunlight!
#        Grass and Water-type Pokémon are healed by Water-type moves.
#            [Move] instead restored [Target]'s HP!
#     Dry Skin makes the bearer lose 1/8 max HP each turn..
#    Sand Spit additionally lowers Accuracy of all foes upon activation by 1 stage.
#    Wandering Spirit lowers the bearer's Speed by 1 stage at the end of each turn.
#     Arenite Wall lasts 8 turns and can be set without Sandstorm.
#    Aqua Ring, Life Dew, and Soak fail on use.
#        The desert is too dry...
#    Dig only lasts 1 turn.
#    Sand Attack lowers the target's Accuracy by 2 stages.
#    Sand Tomb deals 1/6 max HP per turn.
#    Shore Up restores 66% max HP.