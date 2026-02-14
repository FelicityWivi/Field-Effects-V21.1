#===============================================================================
# Custom PBEffects for Field System
# Add these battle effects that the field system uses
#===============================================================================

module PBEffects
  # Field effect: Shelter reduces damage from a specific type by half
  # Stores the type symbol (e.g., :FIRE, :WATER, :POISON)
  Shelter = 200
  
  # Add any other custom effects your field system needs here
  # Make sure to use numbers that don't conflict with existing effects
  # Standard PBEffects use 0-199, so start custom ones at 200+
end

#===============================================================================
# Initialize the Shelter effect in battlers
#===============================================================================

class Battle::Battler
  alias field_pbInitEffects pbInitEffects
  
  def pbInitEffects(batonPass)
    field_pbInitEffects(batonPass)
    
    # Initialize Shelter effect
    @effects[PBEffects::Shelter] = nil unless batonPass
  end
end

#===============================================================================
# Shelter Move Implementation (if needed)
#===============================================================================

# Uncomment this if you want to implement the Shelter move
=begin
class Battle::Move::SetUserTypeThenProtectFromType < Battle::Move
  def pbMoveFailed?(user, targets)
    return true if user.effects[PBEffects::Shelter]
    return false
  end
  
  def pbEffectGeneral(user)
    # Get the shelter type from the field
    shelter_type = @battle.apply_field_effect(:shelter_type)
    shelter_type ||= :NORMAL
    
    user.effects[PBEffects::Shelter] = shelter_type
    @battle.pbDisplay(_INTL("{1} took shelter from {2} moves!", user.pbThis, GameData::Type.get(shelter_type).name))
  end
end
=end

#===============================================================================
# USAGE NOTES
#===============================================================================

=begin

WHAT IS SHELTER?
================

Shelter is a field-dependent effect that reduces damage from a specific type.
Each field has a :shelter_type defined in FIELDEFFECTS.rb:

:VOLCANIC => {
  :shelter_type => :FIRE  # Shelter reduces Fire damage by half
}

:SAHARA => {
  :shelter_type => :GROUND  # Shelter reduces Ground damage by half
}

HOW IT WORKS
============

1. User uses Shelter move (or it's automatically applied)
2. Field's shelter_type is stored in user.effects[PBEffects::Shelter]
3. When damage is calculated, if target has Shelter effect matching the move type:
   - Damage is reduced by half

This is already implemented in 003_Field_base_and_keys.rb:
```ruby
multipliers[:final_damage_multiplier] *= 0.5 if target.effects[PBEffects::Shelter] && target.effects[PBEffects::Shelter] == type
```

FIELD SHELTER TYPES
===================

Current field shelter types defined:
- INDOOR: :NORMAL
- VOLCANIC: :FIRE (custom - you may want to change this)
- SAHARA: :FIRE (from your custom field)
- ENCHANTEDFOREST: :POISON (from your custom field)
- POISONLIBRARY: :PSYCHIC (from your custom field)

Most Rejuvenation fields don't define shelter_type, so they default to the field's mimicry type.

CUSTOM IMPLEMENTATION
=====================

If you want to make Shelter a usable move, you need to:

1. Create a move in your PBS/moves.txt:
```
[SHELTER]
Name = Shelter
Type = NORMAL
Category = Status
Accuracy = 0
TotalPP = 10
Target = User
FunctionCode = SetUserTypeThenProtectFromType
Flags = Snatch
Description = The user takes shelter, reducing damage from the field's type.
```

2. Uncomment the move implementation above

3. The move will automatically use the field's shelter type

ALTERNATIVE: AUTO-SHELTER
=========================

If you want certain Pokemon or abilities to automatically get Shelter:

```ruby
# In an ability effect:
Battle::AbilityEffects::OnSwitchIn.add(:MYABILITY,
  proc { |ability, battler, battle|
    shelter_type = battle.apply_field_effect(:shelter_type)
    battler.effects[PBEffects::Shelter] = shelter_type if shelter_type
    battle.pbDisplay(_INTL("{1} took shelter!", battler.pbThis))
  }
)
```

CLEARING SHELTER
===============

Shelter effect persists until:
- Battle ends
- Pokemon switches out
- Pokemon faints
- Specific moves clear it

To clear it manually:
```ruby
battler.effects[PBEffects::Shelter] = nil
```

CHECKING SHELTER
===============

To check if a Pokemon has Shelter:
```ruby
if battler.effects[PBEffects::Shelter]
  puts "Protected from #{battler.effects[PBEffects::Shelter]} type"
end
```

WHY 200?
========

PBEffects constants need unique numbers. Standard Essentials uses 0-199,
so custom effects should start at 200+ to avoid conflicts.

If you get errors about number conflicts, increment the number:
```ruby
Shelter = 201  # Or 202, 203, etc.
```

TROUBLESHOOTING
===============

Error: "already initialized constant PBEffects::Shelter"
Solution: The constant is already defined elsewhere. Find it and use that number.

Error: "Shelter is already defined as [number]"
Solution: Use a different number (201, 202, etc.)

Effect not working:
Solution: Make sure damage calculation in 003_Field_base_and_keys.rb checks for it

COMPATIBILITY
=============

This is compatible with:
- Pokemon Essentials v20+
- Pokemon Essentials v21+
- Rejuvenation's field system (they use similar mechanics)

=end
