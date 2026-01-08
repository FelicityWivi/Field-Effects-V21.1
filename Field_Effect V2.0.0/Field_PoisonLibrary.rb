class Battle::Field_Poisonlibrary < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :Poisonlibrary
    @name                = _INTL("Poison library")
    @nature_power_change = :ACID
    @mimicry_type        = :POISON
    @camouflage_type     = :POISON
    @terrain_pulse_type  = :POISON
    @secret_power_effect = 15 # Poison
    @shelter_type        = :PSYCHIC
    @field_announcement  = { :start => _INTL("The library is seeping knowledge."),
                             :end   => _INTL("The knowledge is gone!") }

     @multipliers = {
      [:power_multiplier, 1.4, _INTL("The Poison permeates through the field!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[POISON].include?(type) && user.grounded?
      },
      [:power_multiplier, 1.2, _INTL("The library is overgrown!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[GRASS].include?(type)
      },
      [:power_multiplier, 1.2, _INTL("Alexandria!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[FIRE].include?(type)
    },
      [:power_multiplier, 1.2, _INTL("The power of knowledge!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[FAIRY].include?(type)
    },
    }


    @effects[:EOR_field_battler] = proc { |battler|
    if battler.grounded? && battler.pbHasType?(:PSYCHIC)
      battler.pbReduceHP(battler.totalhp / 8)
      @battle.pbDisplay(_INTL("{1} was damaged by the toxic knowledge.", battler.pbThis))
    end
  }

  @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
  next :POISON if %i[GRASS].include?(type)
  next :FAIRY if %i[PSYCHIC].include?(type)
}

  end
end

Battle::Field.register(:Poisonlibrary, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})
