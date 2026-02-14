#===============================================================================
# Battle Environment -> Field Auto-Detection
# Place this after your Battle class is defined
#===============================================================================

# This code automatically sets the field based on the battle environment/backdrop
# when a battle starts.

class Battle
  # Get the current field
  def current_field
    @current_field ||= Battle::Field.new(self, :INDOOR, Battle::Field::INFINITE_FIELD_DURATION)
  end
  
  # Check if there's an active field (not base/indoor)
  def has_field?
    @current_field && !@current_field.is_base?
  end
  
  # Get the top field (for field stacking - future feature)
  def top_field
    @current_field
  end
  
  # Apply a field effect
  def apply_field_effect(key, *args)
    return unless @current_field
    @current_field.apply_field_effect(key, *args)
  end
  
  # Create or change the current field
  def create_new_field(field_id, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    field_id = field_id.to_s.upcase.to_sym
    
    # End current field effects if there is one
    if @current_field && !@current_field.is_base?
      @current_field.apply_field_effect(:end_field_battle)
      allBattlers.each { |b| @current_field.apply_field_effect(:end_field_battler, b) if b }
    end
    
    # Create new field
    @current_field = Battle::Field.new(self, field_id, duration)
    
    # Apply field start effects
    @current_field.apply_field_effect(:set_field_battle)
    allBattlers.each { |b| @current_field.apply_field_effect(:set_field_battler, b) if b && !b.fainted? }
    
    return @current_field
  end
  
  # Initialize battle with field detection
  alias field_initialize initialize
  
  def initialize(*args)
    field_initialize(*args)
    
    # Initialize current field to INDOOR if not set
    @current_field ||= Battle::Field.new(self, :INDOOR, Battle::Field::INFINITE_FIELD_DURATION)
  end
  
  alias field_pbStartBattle pbStartBattle
  
  def pbStartBattle
    # Detect field from environment before battle starts
    detected_field = Battle::Field.field_from_environment(@environment)
    
    # Create the field if it's not already set
    if !@current_field || @current_field.is_base?
      create_new_field(detected_field, Battle::Field::INFINITE_FIELD_DURATION)
      
      # Show field message if not the default indoor field
      if detected_field != :INDOOR && @current_field && @current_field.field_announcement[:start]
        pbDisplay(@current_field.field_announcement[:start])
      end
    end
    
    # Continue with normal battle start
    field_pbStartBattle
  end
end

#===============================================================================
# USAGE EXAMPLES
#===============================================================================

=begin

The system will automatically detect fields based on your battle backdrop/environment.

AUTOMATIC DETECTION:
-------------------
If your battle has environment :Cave, it will use CAVE field
If your battle has environment :Volcano, it will use VOLCANIC field
If your battle has environment :Forest, it will use FOREST field
etc.

MANUAL OVERRIDE:
---------------
You can still manually set fields:

# In an event before battle
$game_temp.battle_rules.setBattleField(:ENCHANTEDFOREST)

# During battle (in Battle class)
@battle.create_new_field(:SAHARA, 5)

ENVIRONMENT MAPPING:
-------------------
The system matches your environment name to field graphic names:

Environment "Cave" -> Looks for field with graphic ["Cave"] -> CAVE field
Environment "Volcano" -> Looks for graphic ["Volcano"] -> VOLCANIC field
Environment "EnchantedForest" -> Looks for graphic ["EnchantedForest"] -> ENCHANTEDFOREST field

TESTING:
-------
To test field detection:

```ruby
# Test what field would be detected
environment = :Cave
field_id = Battle::Field.field_from_environment(environment)
puts "Environment #{environment} would use field: #{field_id}"

# Test all environments
[:Cave, :Volcano, :Forest, :Grassy, :Desert].each do |env|
  field_id = Battle::Field.field_from_environment(env)
  field_data = Battle::Field.get_field_data(field_id)
  puts "#{env} -> #{field_id} (#{field_data[:name]})"
end
```

FIELD GRAPHICS REFERENCE:
------------------------
Here are the graphics for custom fields (add to FIELDEFFECTS.rb):

:ENCHANTEDFOREST => {
  :graphic => ["EnchantedForest"],  # Matches environment :EnchantedForest
  ...
}

:SAHARA => {
  :graphic => ["Sahara"],  # Matches environment :Sahara
  ...
}

:POISONLIBRARY => {
  :graphic => ["PoisonLibrary"],  # Matches environment :PoisonLibrary
  ...
}

CUSTOM ENVIRONMENT SETUP:
-------------------------
If you want a specific map to use a custom field:

1. Set the map's environment in the editor to match the field graphic name
2. Or use an event to set the field before battle:

Event script:
```
$game_temp.battle_rules = {}
$game_temp.battle_rules.setBattleField(:ENCHANTEDFOREST)
pbWildBattle(:PIKACHU, 10)
```

REJUVENATION FIELDS:
-------------------
All Rejuvenation fields already have their graphics set up:
- :VOLCANIC => ["Volcano"]
- :ICY => ["Icy"]  
- :CAVE => ["Cave"]
- :FOREST => ["Forest"]
- :GRASSY => ["Grassy"]
- :ELECTERRAIN => ["Electric"]
- :MISTY => ["Misty"]
- :PSYTERRAIN => ["Psychic"]
- etc.

Check 001_FIELDEFFECTS.rb for the complete list.

TROUBLESHOOTING:
---------------
Field not detecting:
1. Check environment name matches graphic name in FIELDEFFECTS
2. Use Battle::Field.field_from_environment(:YourEnvironment) to test
3. Graphics are case-insensitive (Cave = cave = CAVE)
4. Special characters are ignored (Electric_Terrain = ElectricTerrain)

Wrong field detected:
1. Check if multiple fields share the same graphic name
2. Use manual field setting in event before battle
3. Verify FIELDEFFECTS.rb has correct :graphic values

=end
