

Battle::ItemEffects::TerrainStatBoost.add(:ABSORBBULB,
  proc { |item, battler, battle|
    next false if !%i[water underwater].any?{|f| is_field?(f)}
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_ATTACK, 1, battler, itemName)
    battler.pbConsumeItem
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:LUMINOUSMOSS,
  proc { |item, battler, battle|
    next false if !%i[water underwater].any?{|f| is_field?(f)}
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, battler, itemName)
    battler.pbConsumeItem
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:ELECTRICSEED,
  proc { |item, battler, battle|
    next false if battle.field.terrain != :Electric
    next false if !battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:GRASSYSEED,
  proc { |item, battler, battle|
    next false if battle.field.terrain != :Grassy
    next false if !battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:MISTYSEED,
  proc { |item, battler, battle|
    next false if battle.field.terrain != :Misty
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:PSYCHICSEED,
  proc { |item, battler, battle|
    next false if battle.field.terrain != :Psychic
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::OnSwitchIn.add(:ROOMSERVICE,
  proc { |item, battler, battle|
    next if battle.field.effects[PBEffects::TrickRoom] == 0
    next if !battler.pbCanLowerStatStage?(:SPEED)
    battle.pbCommonAnimation("UseItem", battler)
    battler.pbLowerStatStage(:SPEED, 1, nil)
    battler.pbConsumeItem
  }
)
