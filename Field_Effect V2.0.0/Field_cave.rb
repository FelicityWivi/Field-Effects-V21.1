class Battle::Field_cave < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :cave
    @name                = _INTL("Cave")
    @nature_power_change = :ROCKTOMB
    @mimicry_type        = :ROCK
    @camouflage_type     = :ROCK
    @secret_power_effect = 7 # Flinch
    @terrain_pulse_type  = :ROCK
    @shelter_type        = :ROCK # halves damage taken from rock type moves after using shelter
    @field_announcement  = { :start => _INTL("The cave echoes dully..."),
                             :end   => _INTL("The cave echoes dully...") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("The cavern strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ROCK].include?(type)
      },
      [:power_multiplier, 1.5, _INTL("...Piled on!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ROCKTOMB].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("ECHO-Echo-echo!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if move.soundMove?
      },
      [:power_multiplier, 1.3, _INTL("The cavern froze over!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[BLIZZARD].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The cave was littered with crystals!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[DIAMONDSTORM POWERGEM].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The cave was corrupted!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[SLUDGEWAVE].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The flame ignited the cave!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[ERUPTION FUSIONFLARE HEATWAVE LAVAPLUME OVERHEAT].include?(move.id)
      },
      [:power_multiplier, 0.5, _INTL("The cave choked out the air!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[FLYING].include?(type)
      next if move.contactMove?
  },
}

    @effects[:no_charging] = proc { |user, move|
    next true if %i[BOUNCE FLY].include?(move.id)
 }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if move.id == :BLIZZARD  
    @battle.create_new_field(:icy, Battle::Field::INFINITE_FIELD_DURATION) # this line starts a new field
  end
}

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[DIAMONDSTORM POWERGEM].include?(move.id)
    @battle.create_new_field(:icy, Battle::Field::INFINITE_FIELD_DURATION) # Needs to be changed to Crystal Cavern when I add that field
  end
}

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[SLUDGEWAVE].include?(move.id)
    @battle.create_new_field(:icy, Battle::Field::INFINITE_FIELD_DURATION) # Needs to be changed to corrupted when I add that field
   end
}

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[ERUPTION FUSIONFLARE HEATWAVE LAVAPLUME OVERHEAT].include?(move.id)
    @battle.create_new_field(:volcanic, Battle::Field::INFINITE_FIELD_DURATION) 
  end
}

  end
end

Battle::Field.register(:cave, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# Ground-type moves can now hit airborne Pokémon. #

# MOVES #
# Sky Drop → Fails on use. #
# Stealth Rock damaged is doubled. #

# This field will transform into Dragon's Den if Dragon Pulse is used 2 times, or either Devastating Drake or Draco Meteor is used 1 time. #
#    Draconic energy seeps in... #
#    The draconic energy mutated the field! #