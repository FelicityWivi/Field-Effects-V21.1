class Battle::Field_backalley < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :backalley
    @name                = _INTL("Back Alley")
    @nature_power_change = :BEATUP
    @mimicry_type        = :NORMAL
    @camouflage_type     = :STEEL
    @terrain_pulse_type  = :STEEL
    @secret_power_effect = 2 # need to change to poison
    @shelter_type        = :STEEL
    @field_announcement  = { :start => _INTL("Shifty eyes are all around..."),
                             :end   => _INTL("The street is cleared!") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("Street rules!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DARK].include?(type) && move.physicalMove?
      },
      [:power_multiplier, 1.5, _INTL("In the cracks and the walls!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[BUG].include?(type)
    },
      [:power_multiplier, 1.3, _INTL("All kinds of pollution strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[POISON].include?(type)
      },
      [:power_multiplier, 1.3, _INTL("The right tool for the job!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[STEEL].include?(type)
      },
      [:power_multiplier, 0.5, _INTL("This is no place for fairytales...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[FAIRY].include?(type)
      },
      [:power_multiplier, 1.5, _INTL("An overwhelming first impression!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[FIRSTIMPRESSION].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("A crowd is gathering!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[BEATUP].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("Working 9 to 5 for this!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[PAYDAY].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("The city smog is suffocating!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[SMOG].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("Careful on the street!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[STEAMROLLER SPECTRALTHIEF].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("The power of science is amazing!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[TECHNOBLAST].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("A knife glints in the dark!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[AERIALACE AIRCUTTER AIRSLASH AQUACUTTER BEHEMOTHBLADE CEASELESSEDGE CROSSPOISON CUT FURYCUTTER LEAFBLADE NIGHTSLASH PSYCHOCUT RAZORLEAF RAZORSHELL SACREDSWORD STONEAXE XSCISSOR].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("Better watch your back...!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[BRANCHPOKE DRILLPECK DRILLRUN FALSESURRENDER FELLSTINGER FURYATTACK GLACIALLANCE HORNATTACK HORNLEECH MEGAHORN NEEDLEARM PECK PINMISSILE PLUCK POISONJAB POISONSTING TWINEEDLE SMARTSTRIKE].include?(move.id)
      },
      [:power_multiplier, 0.5, _INTL("The city is no place for a family!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[POPULATIONBOMB].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("Cops! everyone scatter!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[BOOMBURST ECHOEDVOICE HYPERVOICE UPROAR].include?(move.id)
    },
    }


@effects[:switch_in] = proc { |battler|
if battler.hasActiveAbility?(:PICKUP)
  @battle.pbDisplay(_INTL("{1} is picking up Speed!!", battler.pbThis, @name))
  battler.pbRaiseStatStage(:SPEED, 1, nil)
end
}

@effects[:switch_in] = proc { |battler|
if battler.hasActiveAbility?(:RATTLED)
  @battle.pbDisplay(_INTL("The busy city is rattling!", battler.pbThis, @name))
  battler.pbRaiseStatStage(:SPEED, 1, nil)
end
}

@effects[:switch_in] = proc { |battler|
if battler.hasActiveAbility?(:MAGICIAN)
  @battle.pbDisplay(_INTL("The Street Magician's tricks raise {1}'s Special Attack!", battler.pbThis, @name))
  battler.pbRaiseStatStage(:SPECIALATTACK, 1, nil)
end
}

@effects[:switch_in] = proc { |battler|
if battler.hasActiveAbility?(:MERCILESS)
  @battle.pbDisplay(_INTL("Merciless cutpurses like {1} get ready to strike!", battler.pbThis, @name))
  battler.pbRaiseStatStage(:ATTACK, 1, nil)
end
}

@effects[:switch_in] = proc { |battler|
if battler.hasActiveAbility?(:PICKPOCKET)
  @battle.pbDisplay(_INTL("Merciless cutpurses like {1} get ready to strike!", battler.pbThis, @name))
  battler.pbRaiseStatStage(:ATTACK, 1, nil)
end
}

  Battle::AbilityEffects::OnStatLoss.add(:DEFIANT,
  proc { |ability, user, target, move, battle|
  if battle.is_backalley?
  user.pbRaiseStatStageByAbility(:ATTACK, 3, target, true, true)
  end
 }
)

    @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
      next :DARK if %i[FIRSTIMPRESSION].include?(move.id)
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| 
    if %i[BOOMBURST ECHOEDVOICE HYPERVOICE UPROAR].include?(move.id)
    @battle.create_new_field(:city, Battle::Field::INFINITE_FIELD_DURATION) 
   end
}

@effects[:accuracy_modify] = proc { |user, target, move, modifiers, type|
modifiers[:base_accuracy] = 0 if %i[POISONGAS SMOG].include?(move.id)
}

@effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
  if move.id == :CORROSIVEGAS && target.pbCanLowerStatStage?(:ATTACK, user, move) # raise stat stage after using Spark
     @battle.pbDisplay(_INTL("{1} lost power from the {2}!", user.pbThis, @name))
     target.pbLowerStatStage(:ATTACK, 1, target)
  end
}

  end
end

Battle::Field.register(:backalley, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})
