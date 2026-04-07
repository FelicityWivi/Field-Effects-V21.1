#===============================================================================
# FIELD EFFECTS — Bug Fixes
# Load order: must be AFTER 010_Comprehensive_Field_Mechanics.rb
# Compatible with: Pokémon Essentials v21.1, Field Effects plugin
#
# Fixes addressed:
#
#  BUG 1  (CRASH) pbHasType? called with multiple arguments (line 1879)
#          Desert field EOR phase: !b.pbHasType?(:GROUND, :ROCK, :STEEL)
#          pbHasType? is defined as def pbHasType?(type) — exactly one arg.
#          Triggered when Sand Spit activated on desert field and EOR ran.
#          Fix: extend pbHasType? to accept varargs with any? semantics.
#               This is fully backwards-compatible.
#
#  BUG 2  (CRASH) pbHasItem? does not exist on Battle::Battler (line 1812)
#          Effect Spore check: user.pbHasItem?(:SAFETYGOGGLES)
#          The correct method is hasActiveItem?
#          Fix: alias pbHasItem? → hasActiveItem?
#
#  BUG 3  (SILENT) AbilityHandlerHash.add overwrites — duplicate handlers
#          lost. Battle::AbilityEffects uses a plain Hash internally;
#          each .add(key, proc) replaces the previous proc for that key.
#          010 registers the same ability keys multiple times for different
#          fields, silently dropping earlier definitions including the base
#          Pokémon Essentials handler.
#
#          Affected abilities and what was lost:
#           - SWIFTSWIM    SpeedCalc:         base rain check broken
#                                             (field.weather bypasses Cloud Nine)
#           - SURGESURFER  SpeedCalc:         line 2326 wrongly gave water-surface
#                                             behavior; line 4794 correct but loses
#                                             base Electric Terrain check
#           - SLUSHRUSH    SpeedCalc:         Snowy Mountain lost (Icy Cave wins)
#           - QUICKFEET    SpeedCalc:         status-based 1.5× lost (field-only wins)
#           - LONGREACH    DamageCalcFromUser: Snowy Mountain lost (Mountain wins)
#           - OVERGROW     DamageCalcFromUser: Canyon version lost; Canyon had no
#                                             hp≤⅓ fallback either
#           - SWARM        DamageCalcFromUser: Canyon lost (Forest wins); Canyon
#                                             had no hp≤⅓ fallback
#           - GRASSPELT    DamageCalcFromTarget: base Grassy Terrain + Canyon +
#                                             Forest all lost (Grassy field wins)
#           - LEAFGUARD    StatusImmunity:    base sun check + Canyon + Forest
#                                             all lost (Grassy field wins)
#           - FRISK        OnSwitchIn:        base item reveal + Back Alley steal
#                                             both lost (City Field wins)
#           - RATTLED      OnSwitchIn:        City Field lost (Haunted Field wins)
#           - GULPMISSILE  OnBeingHit:        Water Surface Arrokuda lost
#                                             (Electric Terrain wins)
#
#          Fix: after 010 has finished loading, re-register ONE consolidated
#               proc per ability that covers every field condition plus the
#               original base PE condition.
#===============================================================================

#-------------------------------------------------------------------------------
# BUG 1 — pbHasType? varargs patch
#
# Original: def pbHasType?(type)   ← exactly one argument
# Fixed:    def pbHasType?(*types)  ← one or many; returns true if the battler
#           has ANY of the given types.
#
# Existing single-arg call sites are completely unaffected because a single
# symbol still works: pbHasType?(:FIRE) → types = [:FIRE].
# Multi-arg call sites (like the desert EOR bug) now work correctly:
#   !b.pbHasType?(:GROUND, :ROCK, :STEEL)
#   → !types.any? { |t| activeTypes.include?(t) }  ← correct sandstorm immunity
#-------------------------------------------------------------------------------
class Battle::Battler
  def pbHasType?(*types)
    return false if types.empty?
    active = pbTypes(true)
    types.any? { |t| next false unless t; active.include?(GameData::Type.get(t).id) }
  end
end

#-------------------------------------------------------------------------------
# BUG 2 — pbHasItem? alias
#
# pbHasItem? is not defined anywhere in Pokémon Essentials v21.1.
# The correct method is hasActiveItem?(item, ignore_fainted = false).
# Adding an alias so any existing or future call to pbHasItem? routes correctly.
#-------------------------------------------------------------------------------
class Battle::Battler
  alias pbHasItem? hasActiveItem? unless method_defined?(:pbHasItem?)
end

#-------------------------------------------------------------------------------
# BUG 3 — Consolidated ability handler re-registrations
#
# Each block below replaces the last-surviving-duplicate with a single proc
# that encodes ALL field conditions for that ability plus the original base
# PE behaviour.  Because this file loads after 010, our registration is the
# final one and becomes the active handler.
#
# Style notes:
#   • effectiveWeather is used instead of field.weather so Cloud Nine / Air
#     Lock properly suppress weather effects.
#   • Every field constant (WATER_SURFACE_IDS, etc.) was defined by 010 before
#     this file loads, so no forward-reference risk.
#   • Each proc is self-contained: it does not call super or rely on the old
#     handler it replaces.
#-------------------------------------------------------------------------------

# ── SWIFTSWIM ────────────────────────────────────────────────────────────────
# Conditions: Water Surface field (always) OR effective rain weather.
# Bug fixed:  field.weather used in 010 bypasses Cloud Nine / Air Lock.
Battle::AbilityEffects::SpeedCalc.add(:SWIFTSWIM,
  proc { |ability, battler, mult|
    battle = battler.battle
    # Field condition — always fast on Water Surface regardless of weather.
    next mult * 2 if battle.has_field? && WATER_SURFACE_IDS.include?(battle.current_field.id)
    # Base condition — rain, respecting Cloud Nine / Air Lock via effectiveWeather.
    next mult * 2 if [:Rain, :HeavyRain].include?(battler.effectiveWeather)
    next mult
  }
)

# ── SURGESURFER ──────────────────────────────────────────────────────────────
# Conditions: Electric Terrain plugin field (always) OR base game Electric
#             Terrain (battle.field.terrain == :Electric).
# Bug fixed:  line 2326 gave Surge Surfer the water-surface / rain behavior
#             by mistake.  Line 4794 was correct but replaced 2326 and dropped
#             the base terrain check.
Battle::AbilityEffects::SpeedCalc.add(:SURGESURFER,
  proc { |ability, battler, mult|
    battle = battler.battle
    # Plugin Electric Terrain field.
    next mult * 2 if battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battle.current_field.id)
    # Base game Electric Terrain (from base PE battle field object).
    next mult * 2 if battle.field.terrain == :Electric
    next mult
  }
)

# ── SLUSHRUSH ────────────────────────────────────────────────────────────────
# Conditions: Snowy Mountain field (hail/snow weather on that field) OR Icy
#             field (always) OR base game Hail / Snow via effectiveWeather.
# Bug fixed:  line 2699 (Snowy Mountain) was overwritten by line 5465 (Icy).
Battle::AbilityEffects::SpeedCalc.add(:SLUSHRUSH,
  proc { |ability, battler, mult|
    battle = battler.battle
    if battle.has_field?
      field_id = battle.current_field.id
      # Snowy Mountain — only when hail or snow is active on the field.
      if SNOWY_MOUNTAIN_IDS.include?(field_id)
        next mult * 2 if [:Hail, :Snow].include?(battler.effectiveWeather)
      end
      # Icy Cave — always fast.
      next mult * 2 if field_id == :icy
    end
    # Base game Hail / Snow weather anywhere else.
    next mult * 2 if [:Hail, :Snow].include?(battler.effectiveWeather)
    next mult
  }
)

# ── QUICKFEET ────────────────────────────────────────────────────────────────
# Conditions: Electric Terrain field (1.5×, always) OR any status condition
#             (1.5×, base game behavior).
# Bug fixed:  base PE's status check was dropped when line 4804 registered
#             the Electric Terrain version.
Battle::AbilityEffects::SpeedCalc.add(:QUICKFEET,
  proc { |ability, battler, mult|
    battle = battler.battle
    # Plugin Electric Terrain field — boost always applies.
    next mult * 1.5 if battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battle.current_field.id)
    # Base game — boost when battler has any non-None status.
    next mult * 1.5 if battler.pbHasAnyStatus?
    next mult
  }
)

# ── LONGREACH ────────────────────────────────────────────────────────────────
# Conditions: Snowy Mountain field OR Mountain field.
# Bug fixed:  line 2736 (Snowy Mountain) was overwritten by line 2790 (Mountain).
Battle::AbilityEffects::DamageCalcFromUser.add(:LONGREACH,
  proc { |ability, user, target, move, mults, power, type|
    battle = user.battle
    next unless battle.has_field?
    field_id = battle.current_field.id
    next unless SNOWY_MOUNTAIN_IDS.include?(field_id) || MOUNTAIN_FIELD_IDS.include?(field_id)
    mults[:attack_multiplier] *= 1.5
  }
)

# ── OVERGROW ─────────────────────────────────────────────────────────────────
# Conditions: Canyon field (always 1.5×) OR Forest field (always 1.5×) OR
#             Grassy Terrain field (always 1.5×) OR anywhere at hp ≤ ⅓ (base).
# Bug fixed:  Canyon version (line 3561) had no hp≤⅓ fallback AND was
#             overwritten by Forest (3663) and then Grassy Terrain (4512).
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :GRASS
    battle = user.battle
    if battle.has_field?
      field_id = battle.current_field.id
      if CANYON_FIELD_IDS.include?(field_id) ||
         FOREST_FIELD_IDS.include?(field_id) ||
         GRASSY_TERRAIN_IDS.include?(field_id)
        mults[:attack_multiplier] *= 1.5
        next
      end
    end
    # Base game — low HP threshold.
    mults[:attack_multiplier] *= 1.5 if user.hp <= user.totalhp / 3
  }
)

# ── SWARM ─────────────────────────────────────────────────────────────────────
# Conditions: Canyon field (always 1.5×) OR Forest field (always 1.5×) OR
#             anywhere at hp ≤ ⅓ (base).
# Bug fixed:  Canyon version (line 3573) had no hp≤⅓ fallback AND was
#             overwritten by Forest (3675).
Battle::AbilityEffects::DamageCalcFromUser.add(:SWARM,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :BUG
    battle = user.battle
    if battle.has_field?
      field_id = battle.current_field.id
      if CANYON_FIELD_IDS.include?(field_id) || FOREST_FIELD_IDS.include?(field_id)
        mults[:attack_multiplier] *= 1.5
        next
      end
    end
    # Base game — low HP threshold.
    mults[:attack_multiplier] *= 1.5 if user.hp <= user.totalhp / 3
  }
)

# ── GRASSPELT ────────────────────────────────────────────────────────────────
# Conditions: base Grassy Terrain (base PE terrain field) OR Canyon field OR
#             Forest field OR Grassy Terrain plugin field — all give 1.5× phys def.
# Bug fixed:  base terrain + Canyon + Forest all overwritten by Grassy field (4495).
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, power, type|
    next unless move.physicalMove?(type)
    battle = target.battle
    boosted = false
    if battle.has_field?
      field_id = battle.current_field.id
      boosted = CANYON_FIELD_IDS.include?(field_id) ||
                FOREST_FIELD_IDS.include?(field_id) ||
                GRASSY_TERRAIN_IDS.include?(field_id)
    end
    # Base game Grassy Terrain from the base PE battle field object.
    boosted ||= (battle.field.terrain == :Grassy)
    mults[:defense_multiplier] *= 1.5 if boosted
  }
)

# ── LEAFGUARD ────────────────────────────────────────────────────────────────
# Conditions: base Sun / HarshSun (effectiveWeather) OR Canyon field OR
#             Forest field OR Grassy Terrain plugin field.
# Bug fixed:  base sun + Canyon + Forest all overwritten by Grassy field (4504).
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    # Base game — harsh sunlight via effectiveWeather (respects Cloud Nine).
    next true if [:Sun, :HarshSun].include?(battler.effectiveWeather)
    battle = battler.battle
    next unless battle.has_field?
    field_id = battle.current_field.id
    next true if CANYON_FIELD_IDS.include?(field_id) ||
                 FOREST_FIELD_IDS.include?(field_id) ||
                 GRASSY_TERRAIN_IDS.include?(field_id)
  }
)

# ── FRISK ────────────────────────────────────────────────────────────────────
# Conditions:
#   Back Alley field  → steal an item from an opponent (if the Frisk user
#                        has no item).
#   City field        → lower all opponents' Special Defense by 1.
#   Anywhere else     → base game: reveal held items of all foes.
# Bug fixed:  Back Alley (1288) overwritten by City Field (2536), and the base
#             PE item-reveal handler (from the PE file) was also overwritten.
Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
  proc { |ability, battler, battle, switch_in|
    if battle.has_field?
      field_id = battle.current_field.id

      # Back Alley — steal an item.
      if BACK_ALLEY_IDS.include?(field_id)
        next if battler.item
        battle.allOtherBattlers(battler.index).each do |b|
          next if !b || b.fainted? || !b.item
          stolen = b.item
          b.pbRemoveItem(false)
          battler.item = stolen
          battle.pbDisplay(
            _INTL("{1} stole {2}'s {3}!", battler.pbThis, b.pbThis(true),
                  GameData::Item.get(stolen).name)
          )
          break
        end
        next  # Skip base reveal on Back Alley.
      end

      # City Field — lower Sp. Def.
      if CITY_FIELD_IDS.include?(field_id)
        battle.allOtherBattlers(battler.index).each do |b|
          next if b.fainted?
          b.pbLowerStatStage(:SPECIAL_DEFENSE, 1, battler)
        end
        next  # Skip base reveal on City Field.
      end
    end

    # Base game — reveal items (player-owned Frisk only, Gen 6+ reveals all foes).
    next if !battler.pbOwnedByPlayer?
    foes = battle.allOtherSideBattlers(battler.index).select { |b| b.item }
    next if foes.empty?
    battle.pbShowAbilitySplash(battler)
    if Settings::MECHANICS_GENERATION >= 6
      foes.each do |b|
        battle.pbDisplay(
          _INTL("{1} frisked {2} and found its {3}!", battler.pbThis, b.pbThis(true), b.itemName)
        )
      end
    else
      foe = foes[battle.pbRandom(foes.length)]
      battle.pbDisplay(_INTL("{1} frisked the foe and found one {2}!", battler.pbThis, foe.itemName))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

# ── RATTLED (OnSwitchIn) ─────────────────────────────────────────────────────
# Conditions: City field OR Haunted field → raise Speed by 1 on switch-in.
# Bug fixed:  City Field (2528) overwritten by Haunted Field (3247).
# Note: the base PE OnBeingHit RATTLED handler (Bug/Dark/Ghost moves) is a
#       DIFFERENT handler type and is not affected by this fix.
Battle::AbilityEffects::OnSwitchIn.add(:RATTLED,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field?
    field_id = battle.current_field.id
    next unless CITY_FIELD_IDS.include?(field_id) || HAUNTED_FIELD_IDS.include?(field_id)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

# ── GULPMISSILE (OnBeingHit) ─────────────────────────────────────────────────
# Triggers when Cramorant (in Gulping or Gorging form) is hit.
#
# Normal behavior (base PE hardcoded in UseMoveTriggerEffects, NOT here):
#   When Cramorant uses Surf or Dive it changes to form 1 (hp>½) or 2 (hp≤½).
#
# Field overrides for the FORM CHANGE on Surf/Dive use (OnBeingHit is about
# the ATTACK that fires when Cramorant is hit while in a gulp form):
#   Water Surface field → always change to Arrokuda form (2) on Surf/Dive use.
#   Electric Terrain field → always change to Pikachu form (2) on Surf/Dive use.
#   Elsewhere → normal: form 1 (hp>½) or form 2 (hp≤½).
# Bug fixed:  Water Surface form-change (2372) overwritten by Electric Terrain (4851).
Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.effects[PBEffects::Transform]
    next unless target.isSpecies?(:CRAMORANT)
    next unless [:SURF, :DIVE].include?(move.id)
    next unless target.form == 0  # Only change form when in base form.
    if battle.has_field?
      field_id = battle.current_field.id
      # Water Surface — Arrokuda (form 2).
      if WATER_SURFACE_IDS.include?(field_id)
        target.pbChangeForm(2, _INTL("{1} caught an Arrokuda!", target.pbThis))
        next
      end
      # Electric Terrain — Pikachu (form 2).
      if ELECTRIC_TERRAIN_IDS.include?(field_id)
        target.pbChangeForm(2, _INTL("{1} caught a Pikachu!", target.pbThis))
        next
      end
    end
    # Normal behavior — form based on remaining HP.
    new_form = (target.hp > target.totalhp / 2) ? 1 : 2
    target.pbChangeForm(new_form, _INTL("{1} caught something!", target.pbThis))
  }
)

#-------------------------------------------------------------------------------
# Sanity log
#-------------------------------------------------------------------------------
Console.echo_li("[Field Effects] 012_Field_Bug_Fixes loaded — 13 bugs patched.") rescue nil
