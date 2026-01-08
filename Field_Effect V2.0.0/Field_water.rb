class Battle::Field_water < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :water
    @name                = _INTL("Water")
    @nature_power_change = :WHIRLPOOL
    @mimicry_type        = :WATER
    @camouflage_type     = :WATER
    @ability_activation  = %i[SCHOOLING SURGESURFER SWIFTSWIM TORRENT]
    @terrain_pulse_type  = :WATER
    @secret_power_effect = 6 # burn
    @shelter_type        = :WATER # halves damage taken from fire type moves after using shelter
    @field_announcement  = { :start => _INTL("The water's surface is calm."),
                             :end   => _INTL("The water drew away!") }

    @multipliers = {
    [:power_multiplier, 1.5, _INTL("The water strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[WATER].include?(type)
    },
    [:power_multiplier, 1.2, _INTL("The attack rode the current!")] => proc { |user, target, numTargets, move, type, power, mults|
    next true if %i[DIVE HYDROVORTEX MUDDYWATER OCTAZOOKA ORIGINPULSE SURF WHIRLPOOL].include?(move.id)
    },
    [:power_multiplier, 1.2, _INTL("Poison spread through the water!")] => proc { |user, target, numTargets, move, type, power, mults|
    next true if %i[SLUDGEWAVE].include?(move.id)
    },
    [:power_multiplier, 1.5, _INTL("The water conducted the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ELECTRIC].include?(type)
    },
    [:power_multiplier, 0.5, _INTL("The water deluged the attack...")] => proc { |user, target, numTargets, move, type, power, mults|
    next true if %i[FIRE].include?(type)
    },
    [:power_multiplier, 0, _INTL("...But there was no solid ground to attack from!")] => proc { |user, target, numTargets, move, type, power, mults|
    next true if %i[GROUND].include?(type)
    },
  }

@effects[:no_charging] = proc { |user, move|
next true if %i[DIVE].include?(move.id) && user.grounded?
}

  end
end

Battle::Field.register(:water, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# Left to code #
#Take Heart boosts the user's Special Attack and Special Defense by 2 stages.
