
#===============================================================================
# Decreases the target's Attack and Special Attack by 1 stage each. Then, user
# switches out. Ignores trapping moves. (Parting Shot)
#===============================================================================
class Battle::Move::LowerTargetAtkSpAtk1SwitchOutUser < Battle::Move::TargetMultiStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:ATTACK, 1, :SPECIAL_ATTACK, 1]
  end

  def pbOnStartUse(user, targets)
    @statDown = [:ATTACK, 1, :SPECIAL_ATTACK, 1]
    @statDown = [:ATTACK, 2, :SPECIAL_ATTACK, 2] if %i[backalley].any?{|f| @battle.is_field?(f)}
    @statDown = [:ATTACK, 1, :SPECIAL_ATTACK, 1, :SPEED, 1] if %i[frozendimensional].any?{|f| @battle.is_field?(f)}
  end

  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    switcher = user
    targets.each do |b|
      next if switchedBattlers.include?(b.index)
      switcher = b if b.effects[PBEffects::MagicCoat] || b.effects[PBEffects::MagicBounce]
    end
    return if switcher.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(switcher.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", switcher.pbThis,
                            @battle.pbGetOwnerName(switcher.index)))
    @battle.pbPursuit(switcher.index)
    return if switcher.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(switcher.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(switcher.index, newPkmn)
    @battle.pbClearChoice(switcher.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false if switcher.index == user.index
    @battle.pbOnBattlerEnteringBattle(switcher.index)
    switchedBattlers.push(switcher.index)
  end
end

#===============================================================================
# Trapping move. Traps for 5 or 6 rounds. Trapped Pokémon lose 1/16 of max HP
# at end of each round.
#===============================================================================
class Battle::Move::BindTarget < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.fainted? || target.damageState.substitute
    return if target.effects[PBEffects::Trapping] > 0
    # Set trapping effect duration and info
    if user.hasActiveItem?(:GRIPCLAW)
      target.effects[PBEffects::Trapping] = (Settings::MECHANICS_GENERATION >= 5) ? 8 : 6
    else
      target.effects[PBEffects::Trapping] = 5 + @battle.pbRandom(2)
    end
    target.effects[PBEffects::TrappingMove] = @id
    target.effects[PBEffects::TrappingUser] = user.index
    # Message
    msg = _INTL("{1} was trapped in the vortex!", target.pbThis)
    case @id
    when :BIND
      msg = _INTL("{1} was squeezed by {2}!", target.pbThis, user.pbThis(true))
    when :CLAMP
      msg = _INTL("{1} clamped {2}!", user.pbThis, target.pbThis(true))
    when :FIRESPIN
      msg = _INTL("{1} was trapped in the fiery vortex!", target.pbThis)
    when :INFESTATION
      msg = _INTL("{1} has been afflicted with an infestation by {2}!", target.pbThis, user.pbThis(true))
    when :MAGMASTORM
      msg = _INTL("{1} became trapped by Magma Storm!", target.pbThis)
    when :SANDTOMB
      msg = _INTL("{1} became trapped by Sand Tomb!", target.pbThis)
    when :WHIRLPOOL
      msg = _INTL("{1} became trapped in the vortex!", target.pbThis)
    when :WRAP
      msg = _INTL("{1} was wrapped by {2}!", target.pbThis, user.pbThis(true))
    end
        if id == :WHIRLPOOL && %i[water underwater].any?{|f| @battle.is_field?(f)}
      target.effects[PBEffects::TrappingMove] = :WHIRLPOOL
    end
    @battle.pbDisplay(msg)
  end
end

#===============================================================================
# Interrupts a foe switching out or using U-turn/Volt Switch/Parting Shot. Power
# is doubled in that case. (Pursuit)
# (Handled in Battle's pbAttackPhase): Makes this attack happen before switching.
#===============================================================================
class Battle::Move::PursueSwitchingFoe < Battle::Move
  def pbAccuracyCheck(user, target)
    return true if @battle.switching
    return super
  end

  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 2 if @battle.switching
    return baseDmg
  end
  
  def pbEffectAfterAllHits(user, target)
    return if !%i[backalley].any?{|f| @battle.is_field?(f)}
    return if !target.damageState.fainted
    return if !user.pbCanRaiseStatStage?(:ATTACK, user, self)
    user.pbRaiseStatStage(:ATTACK, 1, user)
  end
end
