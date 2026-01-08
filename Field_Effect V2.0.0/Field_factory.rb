class Battle::Field_factory < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :factory
    @name                = _INTL("Factory")
    @nature_power_change = :GEARGRIND
    @mimicry_type        = :STEEL
    @camouflage_type     = :STEEL
    @terrain_pulse_type  = :STEEL
    @secret_power_effect = 2 # need to change to poison
    @shelter_type        = :STEEL
    @field_announcement  = { :start => _INTL("Machines whir in the background!"),
                             :end   => _INTL("Bzzt!") }
    @multipliers = { # it accepts 2-3 arguments, first is which the multiplier is, second is the number, third is the text, the third is optional
      [:power_multiplier, 2, _INTL("ATTACK SEQUENCE INITIATE.")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DOUBLEIRONBASH FLASHCANNON GEARGRIND GYROBALL MAGNETBOMB].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("ATTACK SEQUENCE UPDATE.")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[STEAMROLLER TECHNOBLAST].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("The attack took energy from the field!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ELECTRIC].include?(type)
      },
      [:power_multiplier, 1.3, _INTL("The field was broken!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[BULLDOZE FISSURE EARTHQUAKE EXPLOSION MAGNITUDE SELFDESTRUCT].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The field shorted out!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[AURAWHEEL DISCHARGE IONDELUGE OVERDRIVE].include?(move.id)
      },
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[BULLDOZE FISSURE EARTHQUAKE EXPLOSION MAGNITUDE SELFDESTRUCT].include?(move.id)
    @battle.create_new_field(:shortcircuit, Battle::Field::INFINITE_FIELD_DURATION) # this line starts a new field
  end
}

    @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
      next :ELECTRIC if %i[GEARGRIND GYROBALL HYDROVORTEX MAGNETBOMB MUDDYWATER SURF FLASHCANNON AURAWHEEL DISCHARGE IONDELUGE OVERDRIVE].include?(move.id)
   }


@effects[:calc_speed] = proc { |battler, speed, mult|
 mult *= 1.3 if user.pbHasType?(:GHOST)
  next mult
}

  end
end

Battle::Field.register(:factory, {
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