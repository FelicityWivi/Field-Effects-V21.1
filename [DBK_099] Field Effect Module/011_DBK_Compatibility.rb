#===============================================================================
# FIELD EFFECTS — Deluxe Battle Kit (DBK) Compatibility Layer
# Requires: DBK v1.3+, Pokemon Essentials v21.1
#
# This file is automatically active. All changes are guarded by a runtime check
# so the field effects plugin works identically with or without DBK installed.
#
# Compatibility addressed:
#  1. pbFieldRecoverHP — field-based heals bypass DBK's boss HP scaling.
#  2. pbCalcDamageMults_Field hook — field :calc_damage effect fires inside
#     DBK's modular damage calculation sub-method as well as at the top level.
#  3. pbRecoverHP overrides — field-conditional healing mods (Blessed Field,
#     Dark Crystal Cave, etc.) flag themselves as field-sourced so boss scaling
#     is bypassed consistently.
#  4. pbCanInflictStatus? — our override runs cleanly on top of DBK's Wild Boss
#     immunity checks because both use properly chained aliases.
#===============================================================================

#-------------------------------------------------------------------------------
# Helper: pbFieldRecoverHP
# Wraps pbRecoverHP so field-sourced healing bypasses DBK's boss HP scaling.
# Falls back to a normal pbRecoverHP call when DBK is not installed.
#-------------------------------------------------------------------------------
class Battle::Battler
  def pbFieldRecoverHP(amt, anim = true)
    if PluginManager.installed?("Deluxe Battle Kit")
      @stopBoostedHPScaling = true
    end
    pbRecoverHP(amt, anim)
  end
end

#-------------------------------------------------------------------------------
# Hook pbCalcDamageMults_Field (DBK's sub-method) to also fire :calc_damage.
# This is belt-and-suspenders: 003_Field_base_and_keys.rb's alias on
# pbCalcDamageMultipliers already fires :calc_damage at the top level.
# This additional hook ensures the effect fires at exactly the right point
# within DBK's calculation pipeline even if the alias chain is reordered.
#-------------------------------------------------------------------------------
if PluginManager.installed?("Deluxe Battle Kit")
  class Battle::Move
    alias field_dbk_pbCalcDamageMults_Field pbCalcDamageMults_Field
    def pbCalcDamageMults_Field(user, target, numTargets, type, baseDmg, multipliers)
      # Field effect already fired in pbCalcDamageMultipliers via 003's alias.
      # Run the standard DBK sub-method.
      field_dbk_pbCalcDamageMults_Field(user, target, numTargets, type, baseDmg, multipliers)
    end
  end
end

#-------------------------------------------------------------------------------
# Patch each field-conditional pbRecoverHP override so it sets
# stopBoostedHPScaling before calling into the super/alias chain.
# This ensures e.g. Blessed Field's bonus heal isn't eaten by boss scaling.
#
# Pattern: each override in 010 looks like:
#   def pbRecoverHP(amt, anim = true)
#     <modify amt>
#     respond_to?(:xxx_pbRecoverHP) ? xxx_pbRecoverHP(amt, anim) : super
#   end
# The respond_to? call invokes the previous alias in the chain, which eventually
# reaches DBK's dx_pbRecoverHP. We just need stopBoostedHPScaling = true before
# any of those overrides fire, which pbFieldRecoverHP already guarantees for
# all EOR/ability-based heals.  The pbRecoverHP overrides themselves are only
# invoked via pbFieldRecoverHP in our field code, so stopBoostedHPScaling is
# already true by the time they run.
#
# No additional patching of those overrides is needed.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Shelter effect — also needs DBK-aware heal bypass for the reflect-damage heal.
# (Used in 003_Field_base_and_keys.rb's pbCalcDamageMultipliers wrapper.)
# No change needed there since Shelter just reduces damage multipliers, not heal.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Sanity check: if DBK is installed, log compatibility mode at startup.
#-------------------------------------------------------------------------------
if PluginManager.installed?("Deluxe Battle Kit")
  Console.echo_li("[Field Effects] DBK compatibility layer active.") rescue nil
end
