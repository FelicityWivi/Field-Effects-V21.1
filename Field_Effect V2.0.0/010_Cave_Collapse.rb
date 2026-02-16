#===============================================================================
# Cave Collapse System
# Handles cave collapse mechanics for cave fields when earthquake moves are used
#===============================================================================

class Battle
  # Initialize cave collapse counters
  alias cave_collapse_initialize initialize
  def initialize(*args)
    cave_collapse_initialize(*args)
    @cave_collapse_counter = 0
    @cave_collapse_warning = false
  end
  
  # Check if current field is a cave
  def is_cave?
    return false unless has_field?
    cave_fields = [:cave, :cave1, :cave2, :cave3, :cave4, :crystalcavern, 
                   :darkcrystalcavern, :murkwatersurface]
    return cave_fields.include?(@current_field.id)
  end
  
  # Cave collapse method - called when earthquake moves are used
  def caveCollapse
    return unless is_cave?
    
    @cave_collapse_counter += 1
    @cave_collapse_warning = true if @cave_collapse_counter == 1
    
    if $DEBUG
      Console.echo_li("Cave collapse counter: #{@cave_collapse_counter}")
    end
  end
  
  # Process cave collapse after move hits
  def process_cave_collapse_after_move
    return unless is_cave?
    return if @cave_collapse_counter == 0
    
    if @cave_collapse_counter == 1 && @cave_collapse_warning
      @cave_collapse_warning = false
      pbDisplay(_INTL("Bits of rock fell from the crumbling ceiling!"))
    elsif @cave_collapse_counter >= 2
      trigger_cave_collapse
    end
  end
  
  # Trigger the actual cave collapse
  def trigger_cave_collapse
    @cave_collapse_counter = 0
    pbDisplay(_INTL("The quake collapsed the ceiling!"))
    
    allBattlers.each do |b|
      next if b.fainted?
      
      # Abilities that provide immunity
      next if b.hasActiveAbility?([:BULLETPROOF, :STALWART, :ROCKHEAD])
      
      # Protection moves
      next if b.effects[PBEffects::Protect] || b.effects[PBEffects::SpikyShield] ||
              b.effects[PBEffects::Obstruct] || b.effects[PBEffects::KingsShield] ||
              b.effects[PBEffects::WideGuard]
      # Additional protection effects if they exist
      next if defined?(PBEffects::SilkTrap) && b.effects[PBEffects::SilkTrap]
      next if defined?(PBEffects::BurningBulwark) && b.effects[PBEffects::BurningBulwark]
      
      # Calculate damage based on ability
      damage = calculate_cave_collapse_damage(b)
      
      if damage > 0
        b.pbReduceHP(damage, false)
        pbDisplay(_INTL("{1} was crushed by falling rocks!", b.pbThis))
        b.pbFaint if b.fainted?
      end
    end
  end
  
  # Calculate cave collapse damage for a battler
  def calculate_cave_collapse_damage(battler)
    hp = battler.hp
    total_hp = battler.totalhp
    
    # Abilities that reduce damage
    if battler.hasActiveAbility?([:PRISMARMOR, :SOLIDROCK])
      return (total_hp / 3.0).round
    elsif battler.hasActiveAbility?([:SHELLARMOR, :BATTLEARMOR])
      return (total_hp / 2.0).round
    elsif battler.effects[PBEffects::Endure]
      # Endure leaves at 1 HP
      return [hp - 1, 0].max
    elsif battler.hasActiveAbility?(:STURDY) && hp == total_hp
      # Sturdy at full HP leaves at 1 HP
      return [hp - 1, 0].max
    else
      # Normal collapse kills the Pokemon
      return hp
    end
  end
  
  # Reset cave collapse counter (e.g., when field changes)
  def reset_cave_collapse
    @cave_collapse_counter = 0
    @cave_collapse_warning = false
  end
end

#===============================================================================
# Move Integration
# Add cave collapse to earthquake-type moves
#===============================================================================
class Battle::Move
  alias cave_collapse_pbEffectAfterAllHits pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    # Call original method
    cave_collapse_pbEffectAfterAllHits(user, target)
    
    # Check for cave collapse after earthquake moves
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, 
                       :TECTONICRAGE, :CONTINENTALCRUSH]
    
    if earthquake_moves.include?(@id)
      @battle.process_cave_collapse_after_move
    end
  end
end

#===============================================================================
# Display Message Integration
# Show warning when earthquake move is used in a cave
#===============================================================================
class Battle::Move
  alias cave_collapse_pbDisplayUseMessage pbDisplayUseMessage
  def pbDisplayUseMessage(user)
    # Call original method
    cave_collapse_pbDisplayUseMessage(user)
    
    # Trigger cave collapse counter for earthquake moves
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE,
                       :TECTONICRAGE, :CONTINENTALCRUSH]
    
    if earthquake_moves.include?(@id) && @battle.is_cave?
      @battle.caveCollapse
    end
  end
end

#===============================================================================
# Field Change Integration
# Reset cave collapse counter when field changes
#===============================================================================
class Battle
  alias cave_collapse_set_field set_field
  def set_field(*args)
    cave_collapse_set_field(*args)
    reset_cave_collapse unless is_cave?
  end
end
