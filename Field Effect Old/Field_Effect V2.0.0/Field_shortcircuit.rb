class Battle::Field_shortcircuit < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :shortcircuit
    @name                = _INTL("Short Circuit")
    @nature_power_change = :BEATUP
    @mimicry_type        = :ELECTRIC
    @camouflage_type     = :ELECTRIC
    @ability_activation  = %i[SURGESURFER PLUS MINUS]
    @terrain_pulse_type  = :ELECTRIC
    @secret_power_effect = 2 # need to change to paralyze
    @shelter_type        = :ELECTRIC
    @field_announcement  = { :start => _INTL("Bzzt!"),
                             :end   => _INTL("Bzzt!") }

    @multipliers = { # it accepts 2-3 arguments, first is which the multiplier is, second is the number, third is the text, the third is optional
      [:power_multiplier, 1.5, _INTL("The attack picked up electricity!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[GEARGRIND GYROBALL HYDROVORTEX MAGNETBOMB MUDDYWATER SURF].include?(move.id)
      },
      [:power_multiplier, 1.2] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ELECTRIC].include?(type)
      },
      [:power_multiplier, 1.5, _INTL("Blinding!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DAZZLINGGLEAM FLASHCANNON].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("Bzzzzt!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[AURAWHEEL CHARGEBEAM DISCHARGE OVERDRIVE PARABOLICCHARGE WILDCHARGE DISCHARGE].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The darkness strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DARKPULSE NIGHTDAZE NIGHTSLASH PHANTOMFORCE SHADOWBALL SHADOWBONE SHADOWCLAW SHADOWFORCE SHADOWPUNCH SHADOWSNEAK].include?(move.id)
      },
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[AURAWHEEL CHARGEBEAM DISCHARGE IONDELUGE OVERDRIVE PARABOLICCHARGE WILDCHARGE DISCHARGE].include?(move.id)
    @battle.create_new_field(:factory, Battle::Field::INFINITE_FIELD_DURATION) # this line starts a new field
  end
}

    @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
      next :ELECTRIC if %i[GEARGRIND GYROBALL HYDROVORTEX MAGNETBOMB MUDDYWATER SURF FLASHCANNON].include?(move.id)
   }


@effects[:calc_speed] = proc { |battler, speed, mult|
 mult *= 1.3 if user.pbHasType?(:GHOST)
  next mult
}

  end
end

Battle::Field.register(:shortcircuit, {
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