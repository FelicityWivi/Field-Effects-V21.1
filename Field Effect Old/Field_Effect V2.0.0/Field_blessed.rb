class Battle::Field_blessed < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :blessed
    @name                = _INTL("Blessed")
    @nature_power_change = :JUDGEMENT
    @mimicry_type        = :NORMAL
    @camouflage_type     = :NORMAL
    @terrain_pulse_type  = :NORMAL
#    @secret_power_effect = 2 # LOWER SPECIAL ATTACK
    @shelter_type        = :NORMAL
    @field_announcement  = { :start => _INTL("The field is blessed"),
                             :end   => _INTL("The field is unholy!") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("The holy energy resonated with the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[FAIRY NORMAL].include?(type)
      next if move.specialMove?
  },
      [:power_multiplier, 1.5, _INTL("Godspeed!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[EXTREMESPEED].include?(move.id)
  },
      [:power_multiplier, 1.5, _INTL("Legendary power accelerated the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[JUDGEMENT SACREDFIRE].include?(move.id)
  },
      [:power_multiplier, 1.5, _INTL("The holy energy resonated with the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[MYSTICALFIRE MAGICALLEAF ANCIENTPOWER SACREDSWORD RETURN].include?(move.id)
  },
      [:power_multiplier, 1.3, _INTL("Legendary power accelerated the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[AEROBLAST BEHEMOTHBASH BEHEMOTHBLADE CRUSHGRIP DIAMONDSTORM DRAGONASCENT DOOMDESIRE DYNAMAXCANNON ETERNABEAM FLEURCANNON HYPERSPACEHOLE LANDSWRATH LUSTERPURGE MISTBALL MOONGEISTBEAM MULTIPULSE ORIGINPULSE PRECIPICEBLADES PRISMATICLASER PSYCHOBOOST PSYSTRIKE RELICSONG ROAROFTIME SECRETSWORD SPACIALREND SUNSTEELSTRIKE].include?(move.id)
  },
      [:power_multiplier, 1.3, _INTL("Evil spirits gathered!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[OMINOUSWIND PHANTOMFORCE SHADOWFORCE].include?(move.id)
  },
      [:power_multiplier, 1.2, _INTL("The legendary energy resonated with the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[PSYCHIC DRAGON].include?(type)
  },
    [:power_multiplier, 0.5, _INTL("The attack was cleansed...")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[GHOST].include?(type)
  },
    [:power_multiplier, 0.5, _INTL("The attack was cleansed...")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[DARK].include?(type)
      next if move.specialMove?
  },
}

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[CURSE OMINOUSWIND PHANTOMFORCE SHADOWFORCE TRICKORTREAT].include?(move.id)
    @battle.create_new_field(:haunted, Battle::Field::INFINITE_FIELD_DURATION) # this line starts a new field
  end
}

    end
  end

Battle::Field.register(:blessed, {
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