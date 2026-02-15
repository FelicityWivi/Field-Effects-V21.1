#===============================================================================
# Increases the user's Attack by 1 stage.
#===============================================================================
class Battle::Move::RaiseUserAttack1 < Battle::Move::StatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1]
  end

  def pbOnStartUse(user, targets)
    @statUp = [:ATTACK, 3] if %i[beach].any?{|f| @battle.is_field?(f)} && %i[MEDITATE].include?(@id)
  end
end

#===============================================================================
# Increases the user's Defense by 2 stages. (Acid Armor, Barrier, Iron Defense)
#===============================================================================
class Battle::Move::RaiseUserDefense2 < Battle::Move::StatUpMove
  def initialize(battle, move)
    super
    @statUp = [:DEFENSE, 2]
  end

  def pbOnStartUse(user, targets)
    ret = @battle.apply_field_effect(:shelter_type, user, targets, self)
    user.effects[PBEffects::Shelter] = ret if ret
  end
end

#===============================================================================
# Increases the user's Special Attack by 2 stages. (Nasty Plot)
#===============================================================================
class Battle::Move::RaiseUserSpAtk2 < Battle::Move::StatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 2]
  end

  def pbOnStartUse(user, targets)
    @statUp = [:SPECIAL_ATTACK, 2]
    @statUp = [:SPECIAL_ATTACK, 3] if %i[backalley].any?{|f| @battle.is_field?(f)}
  end
end

#===============================================================================
# Increases the user's Speed by 2 stages. Lowers user's weight by 100kg.
# (Autotomize)
#===============================================================================
class Battle::Move::RaiseUserSpeed2LowerUserWeight < Battle::Move::StatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPEED, 2]
  end

  def pbEffectGeneral(user)
    if user.pbWeight + user.effects[PBEffects::WeightChange] > 1
      user.effects[PBEffects::WeightChange] -= 1000
      @battle.pbDisplay(_INTL("{1} became nimble!", user.pbThis))
    end
    super
  end

  def pbOnStartUse(user, targets)
    @statUp = [:SPEED, 3] if %i[city].any?{|f| @battle.is_field?(f)} && %i[AUTOMATIZE].include?(@id)
    end
end

#===============================================================================
# Increases the user's critical hit rate. (Focus Energy)
#===============================================================================
class Battle::Move::RaiseUserCriticalHitRate2 < Battle::Move
  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::FocusEnergy] >= 2
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    user.effects[PBEffects::FocusEnergy] = 2
    @battle.pbDisplay(_INTL("{1} is getting pumped!", user.pbThis))
  end

  def pbOnStartUse(user, targets)
    user.effects[PBEffects::FocusEnergy] = 3 if %i[beach].any?{|f| @battle.is_field?(f)}
  end
end

#===============================================================================
# Increases the user's Attack and Special Attack by 1 stage each. (Work Up)
#===============================================================================
class Battle::Move::RaiseUserAtkSpAtk1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :SPECIAL_ATTACK, 1]
  end

  def pbOnStartUse(user, targets)
    @statUp = [:ATTACK, 2, :SPECIAL_ATTACK, 2] if %i[city].any?{|f| @battle.is_field?(f)} && %i[WORKUP].include?(@id)
    end
end

#===============================================================================
# Increases the user's Speed by 2 stages, and its Attack by 1 stage. (Shift Gear)
#===============================================================================
class Battle::Move::RaiseUserAtk1Spd2 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPEED, 2, :ATTACK, 1]
  end

  def pbOnStartUse(user, targets)
    @statUp = [:SPEED, 2, :ATTACK, 2] if %i[city].any?{|f| @battle.is_field?(f)} && %i[SHIFTGEAR].include?(@id)
  end
end

#===============================================================================
# Increases the user's Sp. Attack and Sp. Defense by 1 stage each. (Calm Mind)
#===============================================================================
class Battle::Move::RaiseUserSpAtkSpDef1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPECIAL_DEFENSE, 1]
  end

  def pbOnStartUse(user, targets)
    @statUp = [:SPECIAL_ATTACK, 2, :SPECIAL_DEFENSE, 2] if %i[beach].any?{|f| @battle.is_field?(f)} && %i[CALMMIND].include?(@id)
  end
end

#===============================================================================
# Decreases the target's Special Attack by 1 stage.
#===============================================================================
class Battle::Move::LowerTargetSpAtk1 < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:SPECIAL_ATTACK, 1]
  end

  def pbOnStartUse(user, targets)
    @statDown = [:SPECIAL_ATTACK, 1]
    @statDown = [:SPECIAL_ATTACK, 2] if %i[backalley].any?{|f| @battle.is_field?(f)} &&
                                        id == :SNARL
    @statDown = [:SPECIAL_ATTACK, 2] if %i[swamp].any?{|f| @battle.is_field?(f)} &&
                                        id == :STRUGGLEBUG
  end
end

#===============================================================================
# Decreases the target's Special Defense by 2 stages.
#===============================================================================
class Battle::Move::LowerTargetSpDef2 < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:SPECIAL_DEFENSE, 2]
  end

  def pbOnStartUse(user, targets)
    @statDown = [:SPECIAL_DEFENSE, 2]
    @statDown = [:SPECIAL_DEFENSE, 3] if %i[backalley].any?{|f| @battle.is_field?(f)} &&
                                         id == :FAKETEARS
    @statDown = [:SPECIAL_DEFENSE, 3] if %i[factory].any?{|f| @battle.is_field?(f)} &&
                                         id == :METALSOUND
  end
end

#===============================================================================
# Decreases the target's Speed by 1 stage. Power is halved in Grassy Terrain.
# (Bulldoze)
#===============================================================================
class Battle::Move::LowerTargetSpeed1WeakerInGrassyTerrain < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:SPEED, 1]
  end

  def pbBaseDamage(baseDmg, user, target)
    baseDmg = (baseDmg / 2.0).round if @battle.field.terrain == :Grassy
    return baseDmg
  end
end

#===============================================================================
# Decreases the target's accuracy by 1 stage.
#===============================================================================
class Battle::Move::LowerTargetAccuracy1 < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:ACCURACY, 1]
  end

  def pbOnStartUse(user, targets)
    @statDown = [:ACCURACY, 1]
    @statDown = [:ACCURACY, 2] if %i[city backalley volcanic volcanotop].any?{|f| @battle.is_field?(f)} &&
                                  id == :SMOKESCREEN
    @statDown = [:ACCURACY, 2] if %i[shortcircuit].any?{|f| @battle.is_field?(f)} &&
                                  id == :FLASH
    @statDown = [:ACCURACY, 2] if %i[beach desert].any?{|f| @battle.is_field?(f)} &&
                                  id == :SANDATTACK
    @statDown = [:ACCURACY, 2] if %i[beach desert].any?{|f| @battle.is_field?(f)} &&
                                  id == :KINESIS
  end
end

#===============================================================================
# User copies the target's stat stages. (Psych Up)
#===============================================================================
class Battle::Move::UserCopyTargetStatStages < Battle::Move
  def ignoresSubstitute?(user); return true; end

  def pbEffectAgainstTarget(user, target)
    GameData::Stat.each_battle do |s|
      if user.stages[s.id] > target.stages[s.id]
        user.statsLoweredThisRound = true
        user.statsDropped = true
      elsif user.stages[s.id] < target.stages[s.id]
        user.statsRaisedThisRound = true
      end
      user.stages[s.id] = target.stages[s.id]
    end
    if Settings::NEW_CRITICAL_HIT_RATE_MECHANICS
      user.effects[PBEffects::FocusEnergy] = target.effects[PBEffects::FocusEnergy]
      user.effects[PBEffects::LaserFocus]  = target.effects[PBEffects::LaserFocus]
    end
    @battle.pbDisplay(_INTL("{1} copied {2}'s stat changes!", user.pbThis, target.pbThis(true)))
  end
  def pbEffectGeneral(user)
    return false if %i[beach].any?{|f| @battle.is_field?(f)}
    old_status = user.status
    user.pbCureStatus(false)
    case old_status
    when :BURN
      @battle.pbDisplay(_INTL("{1} healed its burn!", user.pbThis))
    when :POISON
      @battle.pbDisplay(_INTL("{1} cured its poisoning!", user.pbThis))
    when :PARALYSIS
      @battle.pbDisplay(_INTL("{1} cured its paralysis!", user.pbThis))
    end
  end
end
