
  def pbDisplayUseMessage(user)
    @battle.pbDisplayBrief(_INTL("{1} used {2}!", user.pbThis, @name))
    @battle.field.effects[PBEffects::CaveCollapse] += 1 if @battle.is_cave? &&
     [:MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :FISSURE].include?(id)
    @battle.field.effects[PBEffects::CollapseWarning] = true if @battle.is_cave? &&
     [:MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :FISSURE].include?(id)
  end

def pbEffectAfterAllHitsCave(user, target); # For Cave Collapse
    if @battle.is_cave? && [:BULLDOZE, :EARTHQUAKE, :FISSURE, :MAGNITUDE].include?(id)
      if @battle.field.effects[PBEffects::CaveCollapse] == 1 && @battle.field.effects[PBEffects::CollapseWarning]
        @battle.field.effects[PBEffects::CollapseWarning] = false
        @battle.pbDisplay(_INTL("Bits of rock fell from the crumbling ceiling!"))
      elsif @battle.field.effects[PBEffects::CaveCollapse] == 2
        @battle.field.effects[PBEffects::CaveCollapse] = 0
        @battle.pbDisplay(_INTL("The quake collapsed the ceiling!"))
        @battle.allBattlers.each do |b|
          next if [:BULLETPROOF, :STALWART, :ROCKHEAD].include?(b.ability_id)
          next if b.effects[PBEffects::Protect] || b.effects[PBEffects::SpikyShield] ||
                  b.effects[PBEffects::Obstruct] || b.effects[PBEffects::KingsShield] ||
                  b.effects[PBEffects::WideGuard] || b.effects[PBEffects::SilkTrap] ||
                  b.effects[PBEffects::BurningBulwark]
          if [:PRISMARMOR, :SOLIDROCK].include?(b.ability_id)
            b.pbReduceHP(b.totalhp / 3, false)
            b.pbFaint if b.fainted?
          elsif [:SHELLARMOR, :BATTLEARMOR].include?(b.ability_id)
            b.pbReduceHP(b.totalhp / 2, false)
            b.pbFaint if b.fainted?
          elsif b.effects[PBEffects::Endure]
            if b.hp > 1
             b.pbReduceHP(b.hp - 1, false)
            end
          elsif b.hasActiveAbility?(:STURDY) && (b.hp == b.totalhp)
            b.pbReduceHP(b.hp - 1, false)
          else
            b.pbReduceHP(b.hp, false)
            b.pbFaint if b.fainted?
          end
        end
      end
    end
  end
