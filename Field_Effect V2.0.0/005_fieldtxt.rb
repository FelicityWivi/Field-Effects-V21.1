FIELDEFFECTS = {

:INDOOR => {
	:name => "",
	:fieldMessage => [
		""
	],
	:graphic => ["Indoor"],
	:secretPower => "TRIATTACK",
	:naturePower => :TRIATTACK,
	:mimicry => :NORMAL,	
	:damageMods => { #damage modifiers for specific moves, written as multipliers (e.g. 1.5 => [:TACKLE])
	},				# a damage mod of 0 denotes the move failing on this field
	:accuracyMods => { #accuracy chance for specific moves, written as percent chance to hit (e.g. 80 => [:TOXIC])
	},				# a accuracy mod of 0 denotes the move always hitting on this field
	:moveMessages => {	# the field message displayed when using a move (written as "message" => [move1,move2....] )
	},
	:typeMods => {	# secondary types applied to moves (written as "type" => [move1,move2,....])
	},
	:typeAddOns => { # secondary types applied to entire types (written as SecondaryTypeSymbol => [typesymbol1,typesymbol2,...])
	},
	:moveEffects => { # arbitrary commands that are evaled after a move executes but before fieldchanges are checked
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:typeBoosts => { # damage multipliers applied to all moves of a specific type (e.g. 1.3 => [:FIRE,:WATER])
	},
	:typeMessages => {	# field message shown when using a move of the denoted type ("message" => [type1,type2,....])
	},
	:typeCondition => {	# conditions for the type boost written as a string of conditions that are evaled later
	},	#evaled as a function on the move class
	:typeEffects => { # arbitrary commands attached to all moves of a type that are evaled after a move executes but before fieldchanges are checked
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:changeCondition => { # conditions for a field change written as a string of conditions that are evaled later
	},	#evaled as a function on the move class
	:fieldChange => {  # moves that change this field to a different field (Fieldsymbol => [move1,move2,....])
	},
	:dontChangeBackup => [],	#list of moves which store the current field as backup when changing the field
	:changeMessage => {	# message displayed when changing a field to a different one ("message" => [move1,move2,....])
	},
	:statusMods => [],	#list of non-damaging moves boosted by the field in different ways, for field highlighting
	:changeEffects => {#additional effects that happen when specific moves change a field (such as corrisive mist explosion)
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:seed => {		# the seed effects on this field
		:seedtype => nil,	# which seed is activated
		:effect => nil,		# which battler effect is being changed if any
		:duration => nil,	# duration of the extra effect
		:message => nil,	# message shown with the seeds boost
		:animation => nil,	# animation associated with the effect
		:stats => {			# statchanges caused by the seed
		},
	},
	:overlay => {		# effects of this field as an overlay instead of a full field #Rejuv
		:damageMods => { #damage modifiers for specific moves, written as multipliers (e.g. 1.5 => [:TACKLE])
		},				# a damage mod of 0 denotes the move failing on this field
		:typeMods => {	# secondary types applied to moves (written as "type" => [move1,move2,....])
		},
		:moveMessages => {	# the field message displayed when using a move (written as "message" => [move1,move2....] )
		},
		:typeBoosts => { # damage multipliers applied to all moves of a specific type (e.g. 1.3 => [:FIRE,:WATER])
		},
		:typeMessages => {	# field message shown when using a move of the denoted type ("message" => [type1,type2,....])
		},
		:typeCondition => {	# conditions for the type boost written as a string of conditions that are evaled later
		},	#evaled as a function on the move class
		:statusMods => [],	#list of non-damaging moves boosted by the field in different ways, for field highlighting
	},
},
:ELECTERRAIN => {
	:name => "Electric Terrain",
	:fieldMessage => [
		"The field is hyper-charged!"
	],
	:graphic => ["Electric"],
	:secretPower => "SHOCKWAVE",
	:naturePower => :THUNDERBOLT,
	:mimicry => :ELECTRIC,
	# Blocked statuses - grounded Pokemon can't sleep
	:statusImmunity => {
		:SLEEP => {
			grounded: true,
			message: "The electricity jolted {1} awake!"
		}
	},
	# Ability modifications
	:abilityMods => {
		:GALVANIZE => { multiplier: 1.5 },
		:BATTERY => { multiplier: 1.5 },    # Boosts allies' Special Attack
		:TERAVOLT => { multiplier: 1.5 },   # Electric moves boosted + neutral to Ground
	},
	# Abilities activated on Electric Terrain
	:abilityActivate => {
		:PLUS        => {},  # SpAtk 1.5x (passive, hardcoded in section 18)
		:MINUS       => {},  # SpAtk 1.5x (passive, hardcoded in section 18)
		:SURGESURFER => {},  # Speed doubled (passive, hardcoded in section 18)
		:QUICKFEET   => {},  # Speed 1.5x (passive, hardcoded in section 18)
		:VOLTABSORB  => {},  # Heals 1/16 HP EOR (hardcoded in section 18)
		:MOTORDRIVE  => { eor: true },  # Speed +1 stage at end of turn
		:SLOWSTART   => { eor: true },  # Counter decreases by 2 instead of 1
	},
	# Ability stat boosts on switch-in
	:abilityStatBoosts => {
		:STEADFAST => {
			stat: :SPEED,
			stages: 1,
			message: "{1}'s Steadfast boosted its Speed!"
		},
		:LIGHTNINGROD => {
			stat: :SPECIAL_ATTACK,
			stages: 1,
			message: "{1}'s Lightning Rod boosted its Special Attack!"
		},
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:CHARGE => { stats_override: { :SPECIAL_DEFENSE => 2 }, message: "The Electric Terrain supercharged {1}! Sp. Def rose sharply!" },
		:EERIEIMPULSE => { stages: 3, message: "The Electric Terrain amplified the pulse! {1}'s Sp. Atk fell drastically!" },
		:ELECTROWEB => { stages: 2, message: "The Electric Terrain amplified the web! {1}'s Speed fell sharply!" },
	},
	:damageMods => {
		1.5 => [:EXPLOSION, :SELFDESTRUCT, :HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS, :WINDBOLTSTORM],
		2.0 => [:MAGNETBOMB],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The explosion became hyper-charged!" => [:EXPLOSION, :SELFDESTRUCT],
		"The attack became hyper-charged!" => [:HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS, :WINDBOLTSTORM],
		"The attack powered up!" => [:MAGNETBOMB],
	},
	:typeMods => {
		:ELECTRIC => [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS, :HYDROVORTEX],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ELECTRIC],
	},
	:typeMessages => {
		"The Electric Terrain strengthened the attack!" => [:ELECTRIC],
	},
	:typeCondition => {
		:ELECTRIC => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:MUDSPORT, :TECTONICRAGE],
	},
	:dontChangeBackup => [:MUDSPORT],
	:changeMessage => {
		 "The hyper-charged terrain shorted out!" => [:MUDSPORT, :TECTONICRAGE],
	},
	:statusMods => [:CHARGE, :EERIEIMPULSE, :MAGNETRISE, :SPIKES, :ELECTRIFY],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Charge,
		:duration => 2,
		:message => "{1} began charging power!",
		:animation => :CHARGE,
		:stats => {
			:SPEED => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:EXPLOSION, :SELFDESTRUCT, :HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS],
			2.0 => [:MAGNETBOMB],
		},
		:typeMods => {
			:ELECTRIC => [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS],
		},
		:moveMessages => {
			"The explosion became hyper-charged!" => [:EXPLOSION, :SELFDESTRUCT],
			"The attack became hyper-charged!" => [:HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS],
			"The attack powered up!" => [:MAGNETBOMB],
		},
		:typeBoosts => {
			1.5 => [:ELECTRIC],
		},
		:typeMessages => {
			"The Electric Terrain strengthened the attack!" => [:ELECTRIC],
		},
		:typeCondition => {
			:ELECTRIC => "!attacker.isAirborne?",
		},
		:statusMods => [:MAGNETRISE],
	},
},
:GRASSY => {
	:name => "Grassy Terrain",
	:fieldMessage => [
		"The field is in full bloom."
	],
	:graphic => ["Grassy"],
	:secretPower => "SEEDBOMB",
	:naturePower => :ENERGYBALL,
	:mimicry => :GRASS,
	# Abilities activated on Grassy Terrain
	:abilityActivate => {
		:GRASSPELT  => {},  # Defense 1.5x (passive, hardcoded in section 19)
		:LEAFGUARD  => {},  # Always active (passive, hardcoded in section 19)
		:OVERGROW   => {},  # Always active (passive, hardcoded in section 19)
		:SAPSIPPER  => {},  # Heals 1/16 HP EOR (hardcoded in section 19)
		:HARVEST    => {},  # Always activates EOR (hardcoded in section 19)
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:COIL => { stats_override: { :ATTACK => 2, :DEFENSE => 2, :ACCURACY => 2 }, message: "The Grassy Terrain enhanced Coil! Attack, Defense, and Accuracy rose sharply!" },
		:COTTONSPORE => { stages: 4, message: "The Grassy Terrain scattered spores everywhere! {1}'s Speed drastically fell!" },
		:GROWTH => { stats_override: { :ATTACK => 2, :SPECIAL_ATTACK => 2 }, message: "The Grassy Terrain nurtured growth! Attack and Sp. Atk rose sharply!" },
		:WORRYSEED => { additional_stats: { :ATTACK => -1 }, message: "The seed worried {1}! Ability changed and Attack fell!" },
	},
	# Item effect modifications
	:itemEffectMods => {
		:BIGROOT => { multiplier: 1.6, message: nil }  # 60% boost instead of 30%
	},
	# Move-specific charging skip
	:noCharging => [:RAZORWIND],
	:noChargingMessages => {
		:RAZORWIND => "The grass whipped up a cutting wind instantly!",
	},
	:damageMods => {
		1.5 => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER, :GRASSKNOT],
		0.5 => [:MUDDYWATER, :SURF, :EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
	},
	:accuracyMods => {
		80 => [:GRASSWHISTLE],
	},
	:moveMessages => {
		"The wind picked up strength from the field!" => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		"The grass strengthened the attack!" => [:GRASSKNOT],
		"The grass softened the attack..." => [:MUDDYWATER, :SURF, :EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SURF],
		"@battle.field_counters.counter += 2" => [:MUDDYWATER],
	},
	:typeBoosts => {
		1.5 => [:GRASS, :FIRE],
	},
	:typeMessages => {
		"The Grassy Terrain strengthened the attack!" => [:GRASS],
		"The grass below caught flame!" => [:FIRE],
	},
	:typeCondition => {
		:GRASS => "!attacker.isAirborne?",
		:FIRE => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {
		:SWAMP => "@battle.field_counters.counter > 2",
	},
	:fieldChange => {
		:CORROSIVE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		:SWAMP => [:SURF, :MUDDYWATER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The grassy terrain was corroded!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		 "The grassy terrain became marshy!" => [:SURF, :MUDDYWATER],
	},
	:statusMods => [:COIL, :GROWTH, :FLORALHEALING, :SYNTHESIS, :WORRYSEED, :INGRAIN, :GRASSWHISTLE, :LEECHSEED, :COTTONSPORE],
	:changeEffects => {},
	:eorHeal => {
		:fraction => 16,
		:condition => "!battler.airborne?",
		:message => "{1} was healed by the Grassy Terrain!"
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:DEFENSE => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The wind picked up strength from the field!" => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		},
		:typeBoosts => {
			1.5 => [:GRASS],
		},
		:typeMessages => {
			"The Grassy Terrain strengthened the attack!" => [:GRASS],
		},
		:typeCondition => {
			:GRASS => "!attacker.isAirborne?",
		},
		:statusMods => [],
	},
},
:MISTY => {
	:name => "Misty Terrain",
	:fieldMessage => [
		"Mist settles on the field."
	],
	:graphic => ["Misty"],
	:secretPower => "MISTBALL",
	:naturePower => :MISTBALL,
	:mimicry => :FAIRY,
	# Status immunity - grounded Pokemon can't be statused
	:statusImmunity => {
		:BURN => { grounded: true, message: "The mist protected {1}!" },
		:PARALYSIS => { grounded: true, message: "The mist protected {1}!" },
		:POISON => { grounded: true, message: "The mist protected {1}!" },
		:SLEEP => { grounded: true, message: "The mist protected {1}!" },
		:FROZEN => { grounded: true, message: "The mist protected {1}!" },
	},
	# Ability modifications
	:abilityMods => {
		:PIXILATE => { multiplier: 1.5 },
	},
	# Abilities activated on Misty Terrain
	:abilityActivate => {
		:MARVELSCALE => {},  # Defense 1.5x (passive, section 20)
		:DRYSKIN     => {},  # Heals 1/16 HP EOR (section 20)
	},
	# Ability stat boosts on switch-in
	:abilityStatBoosts => {
		:WATERCOMPACTION => {
			stat: :DEFENSE,
			stages: 2,
			message: "{1}'s Water Compaction hardened its shell!"
		},
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:COSMICPOWER => { stats_override: { :DEFENSE => 2, :SPECIAL_DEFENSE => 2 }, message: "The mist enhanced Cosmic Power! Defense and Sp. Def rose sharply!" },
		:AROMATICMIST => { stages: 2, message: "The mist amplified the aroma! {1}'s Sp. Def rose sharply!" },
		:SWEETSCENT => { additional_stats: { :DEFENSE => -1, :SPECIAL_DEFENSE => -1 }, message: "The sweet scent lowered {1}'s defenses!" },
	},
	:damageMods => {
		1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM, :SPRINGTIDESTORM],
		0.5 => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE],
		0 => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
	},
	:accuracyMods => {
		100 => [:SWEETKISS],
	},
	:moveMessages => {
		"The mist's energy strengthened the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM, :SPRINGTIDESTORM],
		"The mist softened the attack..." => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE],
		"The damp mist prevented the explosion..." => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:CLEARSMOG, :SMOG, :POISONGAS],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:FAIRY],
		0.5 => [:DRAGON],
	},
	:typeMessages => {
		"The Misty Terrain strengthened the attack!" => [:FAIRY],
		"The Misty Terrain weakened the attack!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CORROSIVEMIST => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:INDOOR => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		:CORROSIVEMIST => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR]
	},
	:dontChangeBackup => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR],
	:changeMessage => {
		 "The mist was blown away!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The mist was corroded!" => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR],
	},
	:statusMods => [:COSMICPOWER, :AROMATICMIST, :SWEETSCENT, :WISH, :AQUARING],
	:changeEffects => {},
	:eorHeal => {
		:fraction => 16,
		:condition => "!battler.airborne?",
		:message => "{1} was soothed by the Misty Terrain!"
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Wish,
		:duration => 2,
		:message => "A wish was made for {1}!",
		:animation => :WISH,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The mist's energy strengthened the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM],
		},
		:typeBoosts => {
			1.5 => [:FAIRY],
		},
		:typeMessages => {
			"The Misty Terrain strengthened the attack!" => [:FAIRY],
		},
		:typeCondition => {
		},
		:statusMods => [],
	},
},
:CHESSBOARD => {
	:name => "Chess Board",
	:fieldMessage => [
		"Opening variation set."
	],
	:graphic => ["ChessBoard"],
	:secretPower => "PSYSHOCK",   # 14 = Lower Defense
	:naturePower => :ANCIENTPOWER,
	:mimicry => :PSYCHIC,
	:damageMods => {
		2.0 => [:BARRAGE],
		1.5 => [:PSYCHIC_MOVE, :STRENGTH, :ANCIENTPOWER, :CONTINENTALCRUSH, :SECRETPOWER, :SHATTEREDPSYCHE,
		        :FAKEOUT, :FEINT, :FEINTATTACK, :FIRSTIMPRESSION, :SUCKERPUNCH, :SHADOWSNEAK, :SMARTSTRIKE],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The Chess Board magnified the attack!" => [:PSYCHIC_MOVE, :STRENGTH, :ANCIENTPOWER, :CONTINENTALCRUSH, :SECRETPOWER, :SHATTEREDPSYCHE],
		"A decisive strike!" => [:FAKEOUT, :FEINT, :FEINTATTACK, :FIRSTIMPRESSION, :SUCKERPUNCH, :SHADOWSNEAK, :SMARTSTRIKE],
		"A devastating barrage!" => [:BARRAGE],
	},
	:typeMods => {
		:ROCK => [:PSYCHIC_MOVE, :STRENGTH, :ANCIENTPOWER, :CONTINENTALCRUSH, :SECRETPOWER, :SHATTEREDPSYCHE, :BARRAGE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:moveStatStageMods => {
		:CALMMIND  => { stages: 2 },
		:NASTYPLOT => { stages: 4 },
	},
	:statusMods => [:CALMMIND, :NASTYPLOT, :NORETREAT, :FALSESURRENDER, :KINGSSHIELD, :OBSTRUCT, :TRICKROOM],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} is shielded by a magic coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:VOLCANIC => {
	:name => "Volcanic Field",
	:fieldMessage => [
		"The field is molten!"
	],
	:graphic => ["Volcanic"],
	:secretPower => "FLAMETHROWER",
	:naturePower => :FLAMETHROWER,
	:mimicry => :FIRE,
	:blockedStatuses => [:FROZEN],  # Can't freeze on volcanic field
	:blockedWeather => [:Hail, :Snow],
    :abilityStatBoosts => {
      :MAGMAARMOR => { 
        stat: :DEFENSE, 
        stages: 1, 
        message: "{1}'s Magma Armor hardened its body!" 
      },
    },
    :abilityFormChanges => {
      :EISCUE => {
        :ICEFACE => { form: 1, show_ability: true, message: "{1}'s Ice Face melted!" }
      }
    },
    :moveStatStageMods => {
      :SMOKESCREEN => { stages: 2, message: "The {2} boosted the Smokescreen! {1}'s accuracy greatly fell!" },
    },
    :abilityActivate => {
      :BLAZE       => {},             # passive: fire moves get 1.5x (handled by existing Blaze check)
      :FLAREBOOST  => {},             # passive: fire moves get 1.5x when burned
      :FLASHFIRE   => { eor: true, grounded: true },  # EOR: activates Flash Fire boost if grounded
      :STEAMENGINE => { eor: true },  # EOR: boosts Speed by 1 stage at end of turn
    },
	:healthChanges => [
    {
      grounded: true,
      exclude_types: [:FIRE],
      healing: false,
      damage_type: :FIRE,
      amount: 1/8.0,
      message: "{1} was hurt by the {2}!",
      immune_abilities: [:FLAMEBODY, :FLAREBOOST, :FLASHFIRE, :HEATPROOF, 
                        :MAGMAARMOR, :WATERBUBBLE, :WATERVEIL],
      immune_effects: [PBEffects::AquaRing],
      multiplier_abilities: {
        :FLUFFY => 2.0,
        :GRASSPELT => 2.0,
        :ICEBODY => 2.0,
        :LEAFGUARD => 2.0
      },
      multiplier_effects: {
        PBEffects::TarShot => 2.0
      }
    }
  ],
	:damageMods => {
		2.0 => [:SMOG, :CLEARSMOG],
		1.5 => [:SMACKDOWN, :THOUSANDARROWS, :ROCKSLIDE, :INFERNALPARADE],
		0 => [:HAIL],
	},
	:accuracyMods => {
		100 => [:WILLOWISP],
	},
	:moveMessages => {
		"The flames spread from the attack!" => [:SMOG, :CLEARSMOG, :INFERNALPARADE],
		"{1} was knocked into the flames!" => [:SMACKDOWN, :THOUSANDARROWS, :ROCKSLIDE],
		"The hail melted away." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:SMACKDOWN, :SMOG, :CLEARSMOG, :THOUSANDARROWS, :ROCKSLIDE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE],
		0.5 => [:GRASS, :ICE],
	},
	:typeMessages => {
		"The blaze amplified the attack!" => [:FIRE],
		"The blaze softened the attack..." => [:GRASS, :ICE],
	},
	:typeCondition => {
		:FIRE => "!attacker.isAirborne?",
		:GRASS => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:CAVE => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE, :WATERSPORT, :SURF, :MUDDYWATER, :WATERSPOUT, :WATERPLEDGE, :SPARKLINGARIA, :SLUDGEWAVE, :SANDTOMB, :CONTINENTALCRUSH, :HYDROVORTEX, :OCEANICOPERETTA],
	},
	# Weather-based field transitions at end of turn
	:weatherFieldChange => {
		:CAVE => {
			weather: [:Rain, :Sandstorm],
			messages: {
				:Rain => "The rain snuffed out the flame!",
				:Sandstorm => "The sand snuffed out the flame!"
			}
		}
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The grime snuffed out the flame!" => [:SLUDGEWAVE],
		 "The wind snuffed out the flame!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The water snuffed out the flame!" => [:WATERSPORT, :SURF, :MUDDYWATER, :WATERSPOUT, :WATERPLEDGE, :SPARKLINGARIA, :HYDROVORTEX, :OCEANICOPERETTA],
		 "The sand snuffed out the flame!" => [:SANDTOMB, :CONTINENTALCRUSH],
	},
	:statusMods => [:WILLOWISP, :SMOKESCREEN],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :MultiTurnAttack,
		:duration => :FIRESPIN,
		:message => "{1} was trapped in the vortex!",
		:animation => :FIRESPIN,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
			:SPEED => 1,
		},
	},
},
:SWAMP => {
	:name => "Swamp Field",
	:fieldMessage => [
		"The field is swamped."
	],
	:graphic => ["Swamp"],
	:secretPower => "MUDDYWATER",
	:naturePower => :MUDDYWATER,
	:mimicry => :WATER,
	:damageMods => {
		1.5 => [:MUDBOMB, :MUDSHOT, :MUDSLAP, :MUDDYWATER, :SLUDGE, :SLUDGEBOMB, :SLUDGEWAVE, :GUNKSHOT, :BRINE, :SMACKDOWN, :THOUSANDARROWS, :HYDROVORTEX, :SAVAGESPINOUT, :MUDBARRAGE],
		0.25 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		0 => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN]
	},
	:accuracyMods => {
		100 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"The murk strengthened the attack!" => [:MUDBOMB, :MUDSHOT, :MUDSLAP, :MUDDYWATER, :SLUDGE, :SLUDGEBOMB, :SLUDGEWAVE, :GUNKSHOT, :BRINE, :SMACKDOWN, :THOUSANDARROWS, :HYDROVORTEX, :MUDBARRAGE],
		"The attack dissipated in the soggy ground..." => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		"The dampness prevents the explosion!" => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
		"There are bugs EVERYWHERE!" => [:SAVAGESPINOUT],
	},
	:typeMods => {
		:WATER => [:SMACKDOWN, :THOUSANDARROWS],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:BUG,:WATER,:GRASS],
		0.8 => [:FIRE],
	},
	:typeMessages => {
		"Bugs are swarming everywhere!" => [:BUG],
		"The dampness strengthened the attack!" => [:WATER],
		"Thick mangroves line the area!" => [:GRASS],
		"The dampness weakened the flame..." => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:moveStatStageMods => {
		:STRUGGLEBUG => { stages: 2 },
		:MUDSHOT     => { stages: 2 },
	},
	:statusMods => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER, :AQUARING, :STRENGTHSAP, :LEECHSEED, :STRINGSHOT, :SPIDERWEB],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1}'s body became clear!",
		:animation => :ROCKPOLISH,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:RAINBOW => {
	:name => "Rainbow Field",
	:fieldMessage => [
		"What does it mean?"
	],
	:graphic => ["Rainbow"],
	:secretPower => "AURORABEAM",
	:naturePower => :AURORABEAM,
	:mimicry => :DRAGON,
	:damageMods => {
		1.5 => [:SILVERWIND, :MYSTICALFIRE, :DRAGONPULSE, :TRIATTACK, :SACREDFIRE, :FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE, :AURORABEAM, :JUDGMENT, :RELICSONG, :HIDDENPOWER, :SECRETPOWER, :MISTBALL, :HEARTSTAMP, :MOONBLAST, :ZENHEADBUTT, :SPARKLINGARIA, :FLEURCANNON, :PRISMATICLASER, :TWINKLETACKLE, :OCEANICOPERETTA, :SOLARBEAM, :SOLARBLADE, :DAZZLINGGLEAM, :MIRRORBEAM, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		2.0 => [:WEATHERBALL],
		0.5 => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE, :NEVERENDINGNIGHTMARE],
		0 => [:NIGHTMARE]
	},
	:accuracyMods => {},
	:moveMessages => {
		"The attack was rainbow-charged!" => [:SILVERWIND, :MYSTICALFIRE, :DRAGONPULSE, :TRIATTACK, :SACREDFIRE, :FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE, :AURORABEAM, :JUDGMENT, :RELICSONG, :HIDDENPOWER, :SECRETPOWER, :WEATHERBALL, :MISTBALL, :HEARTSTAMP, :MOONBLAST, :ZENHEADBUTT, :SPARKLINGARIA, :FLEURCANNON, :PRISMATICLASER, :TWINKLETACKLE, :OCEANICOPERETTA, :SOLARBEAM, :SOLARBLADE, :DAZZLINGGLEAM, :MIRRORBEAM, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		"The rainbow softened the attack..." => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE, :NEVERENDINGNIGHTMARE],
		"The rainbow ensures good dreams." => [:NIGHTMARE]
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:NORMAL],
	},
	:typeMessages => {
		"The rainbow energized the attack!" => [:NORMAL],
	},
	:typeCondition => {
		:NORMAL => "self.specialMove?(type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:LIGHTTHATBURNSTHESKY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The rainbow was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:noCharging => [:SOLARBEAM, :SOLARBLADE],
	:noChargingMessages => {
		"The rainbow powered up the attack!" => [:SOLARBEAM, :SOLARBLADE],
	},
	:moveStatStageMods => {
		:MEDITATE    => { stages: 2 },
		:COSMICPOWER => { stages: 2 },
	},
	:statusMods => [:COSMICPOWER, :MEDITATE, :WISH, :LIFEDEW, :AURORAVEIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Wish,
		:duration => 2,
		:message => "A wish was made for {1}!",
		:animation => :WISH,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
	:overlay => {
		:damageMods => {
		},
		:typeMods => {
		},
		:moveMessages => {
		},
		:typeBoosts => {
		},
		:typeMessages => {
		},
		:typeCondition => {
		},
		:statusMods => [],
	},
},
:CORROSIVE => {
	:name => "Corrosive Field",
	:fieldMessage => [
		"The field is corrupted!"
	],
	:graphic => ["Poison"],
	:secretPower => "ACID",
	:naturePower => :ACID,
	:mimicry => :POISON,
	# Abilities (section 34)
	:abilityActivate => {
		:POISONHEAL => {},
		:TOXICBOOST => {},
		:MERCILESS  => {},
		:CORROSION  => { damage_boost: 1.5 },
		:GRASSPELT  => { eor_damage: true },
	},
	# Move stat mods
	:moveStatStageMods => {
		:ACIDARMOR => { stats_override: { :DEFENSE => 3 } },
		:FLORALHEAL => { additional_effect: :poison_target },
	},
	:damageMods => {
		1.5 => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDBOMB, :MUDDYWATER, :WHIRLPOOL, :THOUSANDARROWS, :APPLEACID],
		2.0 => [:ACID, :ACIDSPRAY, :GRASSKNOT, :SNAPTRAP],
		0 => [:TOXICSPIKES],  # Can't be absorbed
	},
	:accuracyMods => {
		100 => [:POISONPOWDER, :SLEEPPOWDER, :STUNSPORE, :TOXIC],
	},
	:moveMessages => {
		"The corrosion strengthened the attack!" => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDBOMB, :MUDDYWATER, :WHIRLPOOL, :THOUSANDARROWS, :APPLEACID, :ACID, :ACIDSPRAY, :GRASSKNOT, :SNAPTRAP],
		"The toxic field absorbed the spikes!" => [:TOXICSPIKES],
	},
	:typeMods => {
		:POISON => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDDYWATER, :WHIRLPOOL, :MUDBOMB, :THOUSANDARROWS, :APPLEACID],
	},
	:typeAddOns => {
		:POISON => [:GRASS],
	},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:GRASSY => [:SEEDFLARE, :PURIFY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The polluted field was purified!" => [:SEEDFLARE, :PURIFY],
	},
	:statusMods => [:ACIDARMOR, :POISONPOWDER, :SLEEPPOWDER, :STUNSPORE, :TOXIC, :VENOMDRENCH, :VENOSHOCK, :BARBBARRAGE, :FLORALHEAL, :INGRAIN],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :BanefulBunker,
		:duration => 1,
		:message => "{1} protected itself with Baneful Bunker!",
		:animation => :BANEFULBUNKER,
		:stats => {
		},
	},
},
:CORROSIVEMIST => {
	:name => "Corrosive Mist Field",
	:fieldMessage => [
		"Corrosive mist settles on the field!"
	],
	:graphic => ["CorrosiveMist"],
	:secretPower => "ACIDSPRAY",
	:naturePower => :ACIDSPRAY,
	:mimicry => :POISON,
	# Abilities (section 33)
	:abilityActivate => {
		:POISONHEAL    => {},
		:TOXICBOOST    => {},
		:MERCILESS     => {},
		:WATERCOMPACTION => {},
		:CORROSION     => {},
		:DRYSKIN       => {},  # Special handling
	},
	# Move stat mods
	:moveStatStageMods => {
		:ACIDARMOR => { stats_override: { :DEFENSE => 2 } },
		:SMOKESCREEN => { stages: 2 },
		:FLORALHEAL => { additional_effect: :poison_target },
		:LIFEDEW => { additional_effect: :poison_targets },
	},
	:damageMods => {
		1.5 => [:BUBBLEBEAM, :ACIDSPRAY, :BUBBLE, :SMOG, :CLEARSMOG, :SPARKLINGARIA, :APPLEACID, :OCEANICOPERETTA],
	},
	:accuracyMods => {
		100 => [:TOXIC],
	},
	:moveMessages => {
		"The poison strengthened the attack!" => [:BUBBLEBEAM, :ACIDSPRAY, :BUBBLE, :SMOG, :CLEARSMOG, :SPARKLINGARIA, :APPLEACID, :OCEANICOPERETTA],
	},
	:typeMods => {
		:POISON => [:BUBBLE, :BUBBLEBEAM, :ENERGYBALL, :SPARKLINGARIA, :APPLEACID],
	},
	:typeAddOns => {
		:POISON => [:FLYING],  # Special Flying moves
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE],
	},
	:typeMessages => {
		"The toxic mist caught flame!" => [:FIRE],
	},
	:typeCondition => {
		:FLYING => "!self.physicalMove?",  # Special Flying only
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE, :HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :SELFDESTRUCT, :EXPLOSION],
		:MISTY => [:SEEDFLARE],
		:CORROSIVE => [:GRAVITY],
	},
	:dontChangeBackup => [:GRAVITY],
	:changeMessage => {
		 "The mist was blown away!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The polluted mist was purified!" => [:SEEDFLARE],
		 "The toxic mist collected on the ground!" => [:GRAVITY],
	},
	:statusMods => [:ACIDARMOR, :SMOKESCREEN, :VENOMDRENCH, :VENOSHOCK, :BARBBARRAGE, :TOXIC, :FLORALHEAL, :LIFEDEW, :AQUARING],
	:changeEffects => {
		"@battle.mistExplosion" => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :SELFDESTRUCT, :EXPLOSION],
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :BadlyPoison,
		:duration => 1,
		:message => "{1} was badly poisoned!",
		:animation => :TOXIC,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:DESERT => {
	:name => "Desert Field",
	:fieldMessage => [
		"The field is rife with sand."
	],
	:graphic => ["Desert","Desert2","Desert3","DesertNight","DesertEve"],
	:secretPower => "SANDTOMB",
	:naturePower => :SANDTOMB,
	:mimicry => :GROUND,
	# Weather duration extended
	:weatherDuration => {
		:Sun => 8,
		:HarshSun => 8,
		:Sandstorm => 8,
	},
	# Abilities (section 35)
	:abilityActivate => {
		:SOLARPOWER  => {},
		:CHLOROPHYLL => {},
	},
	:damageMods => {
		1.5 => [:NEEDLEARM, :PINMISSILE, :DIG, :SANDTOMB, :HEATWAVE, :THOUSANDWAVES, :BURNUP, :SEARINGSUNRAZESMASH, :SOLARBLADE, :SOLARBEAM, :SCALD, :STEAMERUPTION, :SANDSEARSTORM,:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE,:SCORCHINGSANDS],
		0 => [:SOAK, :AQUARING, :LIFEDEW],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The desert strengthened the attack!" => [:NEEDLEARM, :PINMISSILE, :DIG, :SANDTOMB, :HEATWAVE, :THOUSANDWAVES, :BURNUP, :SEARINGSUNRAZESMASH, :SOLARBLADE, :SOLARBEAM, :SCALD, :STEAMERUPTION, :SANDSEARSTORM, :SCORCHINGSANDS],
		"The lifeless desert strengthened the attack!" => [:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE],
		"The desert is too dry..." => [:SOAK, :AQUARING, :LIFEDEW],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		0.5 => [:WATER, :ELECTRIC],
	},
	:typeMessages => {
		"The desert softened the attack..." => [:WATER, :ELECTRIC],
	},
	:typeCondition => {
		:WATER => "!attacker.isAirborne? && self.move!=:SCALD && self.move!=:STEAMERUPTION",
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SANDSTORM, :SUNNYDAY, :SANDATTACK, :SHOREUP],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :MultiTurnAttack,
		:duration => :SANDTOMB,
		:message => "{1} was trapped by Sand Tomb!",
		:animation => :SANDTOMB,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
			:SPEED => 1,
		},
	},
},
:ICY => {
	:name => "Icy Field",
	:fieldMessage => [
		"The field is covered in ice."
	],
	:graphic => ["Icy"],
	:secretPower => "ICESHARD",
	:naturePower => :ICEBEAM,
	:mimicry => :ICE,
	:damageMods => {
		1.5 => [:BITTERMALICE],
		0.5 => [:SCALD, :STEAMERUPTION],
	},
	:abilityMods => {
    :REFRIGERATE => { multiplier: 1.5 },
	},
	:accuracyMods => {},
	:moveMessages => {
		"The cold strengthened the attack!" => [:BITTERMALICE],
		"The cold softened the attack..." => [:SCALD, :STEAMERUPTION],
	},
	:typeMods => {},
	:typeAddOns => {
		:ICE => [:ROCK],
	},
	:moveEffects => {
		"@battle.iceSpikes" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		"@battle.field_counters.counter += 1" => [:SCALD],
		"@battle.field_counters.counter = 2" => [:STEAMERUPTION],
	},
	:typeBoosts => {
		1.5 => [:ICE],
		0.5 => [:FIRE],
	},
	:typeMessages => {
		"The cold strengthened the attack!" => [:ICE],
		"The cold softened the attack..." => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:INDOOR => "[:WATERSURFACE,:MURKWATERSURFACE].include?(@battle.field.backup) && (self.move!=:DIVE || @battle.field_counters.counter == 3)",
		:WATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:INDOOR => [:DIVE, :EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		:CAVE => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		:WATERSURFACE => [:SCALD, :STEAMERUPTION],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The ice was broken from underneath!" => [:DIVE],
		"The quake broke up the ice and revealed the water beneath!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		"The ice melted away!" => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		"The hot water melted the ice!" => [:SCALD, :STEAMERUPTION],
	},
	:statusMods => [:HAIL, :AURORAVEIL],
	# Weather duration - Hail lasts 8 turns
	:weatherDuration => {
		:Hail => 8,
		:Snow => 8
	},
	# Abilities activated on icy field
	:abilityActivate => {
		:ICEBODY    => {},  # Restores 1/16 HP at end of turn in hail/snow (passive)
		:SLUSHRUSH  => {},  # Speed doubled in hail/snow (passive)
		:SNOWCLOAK  => {}   # Evasion boosted in hail/snow (passive)
	},
	:statusDamageMods => {
    :BURN => 0.5,     # Halves burn damage (1/16 -> 1/32)
    },
    :moveStatBoosts => [
    {
      grounded: true,
      conditions: [:physical, :contact, :priority],
      stat: :SPEED,
      stages: 1,
      message: "{1} gained momentum on the ice!"
    },
    {
      grounded: true,
      moves: [:DEFENSECURL, :LUNGE, :ROLLOUT, :STEAMROLLER],
      stat: :SPEED,
      stages: 1,
      message: "{1} gained momentum on the ice!"
    }
  ],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was hurt by icy Spikes!",
		:animation => nil,
		:stats => {
			:SPEED => 2,
		},
	},
},
:ROCKY => {
	:name => "Rocky Field",
	:fieldMessage => ["The field is littered with rocks."],
	:graphic => ["Rocky"],
	:secretPower => "ROCKTHROW",
	:naturePower => :ROCKSMASH,
	:mimicry => :ROCK,
	# Abilities (Section 38)
	:abilityActivate => { 
		:ROCKHEAD => { no_miss_recoil: true }, 
		:STURDY => { no_flinch_damage: true }, 
		:STEADFAST => { no_flinch_damage: true },
		:GORILLATACTICS => { double_miss_recoil: true },
	},
	# Ability mods
	:abilityMods => {
		:LONGREACH => { accuracy: 0.9 },  # Accuracy drops
	},
	:moveStatStageMods => { :ROCKPOLISH => { stats_override: { :SPEED => 4 } } },
	:damageMods => {
		1.5 => [:ROCKCLIMB, :STRENGTH, :MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :ACCELEROCK],
		2.0 => [:ROCKSMASH],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The rocks strengthened the attack!" => [:ROCKCLIMB, :STRENGTH, :MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :ACCELEROCK],
		"SMASH'D!" => [:ROCKSMASH],
	},
	:typeMods => {
		:ROCK => [:ROCKCLIMB, :EARTHQUAKE, :MAGNITUDE, :STRENGTH, :BULLDOZE, :ACCELEROCK],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK],
	},
	:typeMessages => {
		"The field strengthened the attack!" => [:ROCK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:ROCKPOLISH, :SANDSTORM, :STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :Endure,  # Takes Stealth Rock damage
		:duration => 1,
		:message => "{1} was hurt by Stealth Rocks!",
		:animation => :STEALTHROCK,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FOREST => {
	:name => "Forest Field",
	:fieldMessage => [
		"The field is abound with trees."
	],
	:graphic => ["Forest"],
	:secretPower => "WOODHAMMER",
	:naturePower => :WOODHAMMER,
	:mimicry => :BUG,
	# Abilities activated on Forest Field
	:abilityActivate => {
		:OVERGROW   => {},  # Always active (hardcoded in section 24)
		:SWARM      => {},  # Always active (hardcoded in section 24)
		:GRASSPELT  => {},  # Defense boost (hardcoded in section 24)
		:LEAFGUARD  => {},  # Status immunity (hardcoded in section 24)
		:SAPSIPPER  => {},  # Gradual HP restore EOR (hardcoded in section 24)
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:GROWTH => { stats_override: { :ATTACK => 2, :SPECIAL_ATTACK => 2 }, message: "The forest nurtured massive growth!" },
		:DEFENDORDER => { stats_override: { :DEFENSE => 2, :SPECIAL_DEFENSE => 2 }, message: "The forest bolstered the defense!" },
	},
	:damageMods => {
		0.5 => [:SURF, :MUDDYWATER],
		1.5 => [:GRAVAPPLE, :ATTACKORDER, :ELECTROWEB, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
		2.0 => [:CUT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The forest softened the attack..." => [:SURF, :MUDDYWATER],
		"They're coming out of the woodwork!" => [:ATTACKORDER],
		"Gossamer and arbor strengthened the attack!" => [:ELECTROWEB],
		"The apple did not fall far from the tree" => [:GRAVAPPLE],
		"A tree slammed down!" => [:CUT, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
	},
	:typeMods => {
		:GRASS => [:CUT, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
	},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SURF],
		"@battle.field_counters.counter += 2" => [:MUDDYWATER],
	},
	:typeBoosts => {
		1.5 => [:BUG, :GRASS],
	},
	:typeMessages => {
		"The attack spread throughout the forest!" => [:BUG],
		"The forestry strengthened the attack!" => [:GRASS],
	},
	:typeCondition => {
		:BUG => "self.specialMove?(type)",
	},
	:typeEffects => {},
	:changeCondition => {
		:SWAMP => "@battle.field_counters.counter > 2",
	},
	:fieldChange => {
		:SWAMP => [:SURF, :MUDDYWATER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The forest became marshy!" => [:SURF, :MUDDYWATER],
	},
	:statusMods => [:STICKYWEB, :DEFENDORDER, :GROWTH, :STRENGTHSAP, :HEALORDER, :NATURESMADNESS, :FORESTSCURSE],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :Protect,
		:duration => :SpikyShield,
		:message => "The Telluric Seed shielded {1} against damage!",
		:animation => :SPIKYSHIELD,
		:stats => {
		},
	},
},
:VOLCANICTOP => {
	:name => "Volcanic Top",
	:fieldMessage => [
		"The mountain top is super-heated!"
	],
	:graphic => ["Volcanictop"],
	:secretPower => "FLAMEBURST",
	:naturePower => :ERUPTION,
	:mimicry => :FIRE,
	# Abilities activated on Volcanic Top
	:abilityActivate => {
		:BLAZE      => { eor_after_eruption: true },  # Activated after eruption
		:FLASHFIRE  => { eor_after_eruption: true },  # Activated after eruption
		:GALEWINGS  => { during_strong_winds: true }, # Active during Strong Winds from Tailwind
		:STEAMENGINE => { eor: true },                # Speed boost at end of turn
	},
	# Ability form changes
	:abilityFormChanges => {
		:EISCUE => {
			:ICEFACE => { form: 1, show_ability: true, message: "{1}'s Ice Face melted!" }
		}
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:SMOKESCREEN => { stages: 2, message: "The volcanic ash boosted the Smokescreen! {1}'s accuracy greatly fell!" },
	},
	:damageMods => {
		1.5 => [:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES, :THUNDER, :SCALD, :STEAMERUPTION, :INFERNALPARADE],
		1.3 => [:ERUPTION, :HEATWAVE, :MAGMASTORM, :LAVAPLUME],
		0.625 => [:SURF, :MUDDYWATER, :WATERPLEDGE, :WATERSPOUT, :HYDROPUMP, :SPARKLINGARIA, :HYDROVORTEX, :OCEANICOPERETTA],
		0 => [:HAIL]
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"The field super-heated the attack!" => [:SCALD, :STEAMERUPTION,:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES],
		"The field powers up the flaming attacks!" => [:ERUPTION, :HEATWAVE, :MAGMASTORM, :LAVAPLUME, :INFERNALPARADE],
		"The field powers up the attack!" => [:THUNDER],
		"The hail melted away." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES, :EXPLOSION, :SELFDESTRUCT, :DIG, :DIVE, :SEISMICTOSS, :MAGNETBOMB, :EGGBOMB],
	},
	:typeAddOns => {
		:FIRE => [:ROCK],
	},
	:moveEffects => {
		"@battle.fieldAccuracyDrop" => [:SURF, :MUDDYWATER, :WATERPLEDGE, :WATERSPOUT, :SPARKLINGARIA, :OCEANICOPERETTA, :HYDROVORTEX, :HYDROPUMP, :WATERSPORT],
		"@battle.eruptionChecker" => [:BULLDOZE, :EARTHQUAKE, :MAGNITUDE, :ERUPTION, :PRECIPICEBLADES, :LAVAPLUME, :EARTHPOWER],
	},
	:typeBoosts => {
		0.5 => [:ICE],
		0.9 => [:WATER],
		1.2 => [:FIRE],
		1.3 => [:FLYING],
	},
	:typeMessages => {
		"The extreme heat softened the attack..." => [:ICE, :WATER],
		"The attack was super-heated!" => [:FIRE],
		"The mountain strengthened the attack!!" => [:FLYING],
	},
	:typeCondition => {
		:WATER => "self.move!=:SCALD && self.move!=:STEAMERUPTION",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:SKY => [:FLY, :BOUNCE,],
		:MOUNTAIN => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle was taken to the skies!" => [:FLY, :BOUNCE,],
		 "The field cooled off!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:statusMods => [:TAILWIND, :STEALTROCK, :SMOKESCREEN, :POISONGAS],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :ShellTrap,
		:duration => true,
		:message => "{1} primed a trap!",
		:animation => :SHELLTRAP,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:FACTORY => {
	:name => "Factory Field",
	:fieldMessage => [
		"Machines whir in the background."
	],
	:graphic => ["Factory"],
	:secretPower => "WATERPULSE",  # 5 = Lower Attack
	:naturePower => :GEARGRIND,
	:mimicry => :STEEL,
	:damageMods => {
		1.5 => [:STEAMROLLER, :TECHNOBLAST, :ULTRAMEGADEATH],
		2.0 => [:FLASHCANNON, :GYROBALL, :MAGNETBOMB, :GEARGRIND, :DOUBLEIRONBASH],
	},
	:accuracyMods => {},
	:moveMessages => {
		"ATTACK SEQUENCE UPDATE." => [:STEAMROLLER, :TECHNOBLAST, :ULTRAMEGADEATH],
		"ATTACK SEQUENCE INITIATE." => [:FLASHCANNON, :GYROBALL, :MAGNETBOMB, :GEARGRIND, :DOUBLEIRONBASH],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.2 => [:ELECTRIC],
	},
	:typeMessages => {
		"The attack took energy from the field!" => [:ELECTRIC],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:SHORTCIRCUIT => "!(self.move==:ULTRAMEGADEATH && self.specialMove?(@type))",
	},
	:fieldChange => {
		:SHORTCIRCUIT => [:AURAWHEEL, :IONDELUGE, :GIGAVOLTHAVOC, :EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :SELFDESTRUCT, :EXPLOSION, :LIGHTTHATBURNSTHESKY, :ULTRAMEGADEATH],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The field was broken!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :SELFDESTRUCT, :EXPLOSION, :ULTRAMEGADEATH],
		 "All the light was consumed!" => [:LIGHTTHATBURNSTHESKY],
		 "The field shorted out!" => [:AURAWHEEL, :IONDELUGE, :GIGAVOLTHAVOC],
	},
	:moveStatStageMods => {
		:METALSOUND   => { stages: 2 },
		:IRONDEFENSE  => { stages: 2 },
		:SHIFTGEAR    => { stages: 2 },
		:AUTOTOMIZE   => { stages: 2 },
	},
	:statusMods => [:AUTOTOMIZE, :IRONDEFENSE, :METALSOUND, :SHIFTGEAR, :MAGNETRISE, :GEARUP, :MAGNETRISE],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :LaserFocus,
		:duration => 1,
		:message => "{1} is focused!",
		:animation => :LASERFOCUS,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:SHORTCIRCUIT => {
	:name => "Short-Circuit Field",
	:fieldMessage => [
		"Bzzt!"
	],
	:graphic => ["ShortCircuit"],
	:secretPower => "THUNDERBOLT",  # 1 = Paralyze
	:naturePower => :DISCHARGE,
	:mimicry => :ELECTRIC,
	:damageMods => {
		1.667 => [:STEELBEAM],
		1.5 => [:DAZZLINGGLEAM, :SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :FLASHCANNON, :GEARGRIND, :HYDROVORTEX, :ULTRAMEGADEATH],
		1.3 => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWPUNCH, :SHADOWCLAW, :SHADOWSNEAK, :SHADOWFORCE, :SHADOWBONE, :PHANTOMFORCE],
		0.5 => [:LIGHTTHATBURNSTHESKY],
	},
	:accuracyMods => {
		80 => [:ZAPCANNON],
	},
	:moveMessages => {
		"CHARGING UP!" => [:ULTRAMEGADEATH],
		"Blinding!" => [:DAZZLINGGLEAM, :FLASHCANNON],
		"The attack picked up electricity!" => [:SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :GEARGRIND, :HYDROVORTEX],
		"The darkness strengthened the attack!" => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWPUNCH, :SHADOWCLAW, :SHADOWSNEAK, :SHADOWFORCE, :SHADOWBONE, :PHANTOMFORCE],
		"{1} couldn't consume much light..." => [:LIGHTTHATBURNSTHESKY],
	},
	:typeMods => {
		:ELECTRIC => [:SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :FLASHCANNON, :GEARGRIND, :STEELBEAM],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:FACTORY => "!(self.move==:ULTRAMEGADEATH && self.physicalMove?(@type))",
	},
	:fieldChange => {
		:FACTORY => [:AURAWHEEL, :PARABOLICCHARGE, :WILDCHARGE, :CHARGEBEAM, :IONDELUGE, :GIGAVOLTHAVOC, :ULTRAMEGADEATH],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "SYSTEM ONLINE." => [:AURAWHEEL, :PARABOLICCHARGE, :WILDCHARGE, :CHARGEBEAM, :IONDELUGE, :GIGAVOLTHAVOC, :ULTRAMEGADEATH],
	},
	:moveStatStageMods => {
		:METALSOUND  => { stages: 2 },
		:FLASH       => { stages: 2 },
	},
	:statusMods => [:FLASH, :METALSOUND, :MAGNETRISE],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :MagnetRise,
		:duration => 5,
		:message => "{1} levitated with electromagnetism!",
		:animation => :MAGNETRISE,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:WASTELAND => {
	:name => "Wasteland",
	:fieldMessage => [
		"The waste is watching..."
	],
	:graphic => ["Wasteland"],
	:secretPower => "GUNKSHOT",
	:naturePower => :GUNKSHOT,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:VINEWHIP, :POWERWHIP, :MUDSLAP, :MUDBOMB, :MUDSHOT],
		0.25 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		2.0 => [:SPITUP],
		1.2 => [:OCTAZOOKA, :SLUDGE, :GUNKSHOT, :SLUDGEWAVE, :SLUDGEBOMB, :ACIDDOWNPOUR],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The waste did it for the vine!" => [:VINEWHIP, :POWERWHIP],
		"The waste was added to the attack!" => [:MUDSLAP, :MUDBOMB, :MUDSHOT],
		"Wibble-wibble wobble-wobb..." => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		"BLEAAARGGGGH!" => [:SPITUP],
		"The waste joined the attack!" => [:OCTAZOOKA, :SLUDGE, :GUNKSHOT, :SLUDGEWAVE, :SLUDGEBOMB, :ACIDDOWNPOUR],
	},
	:typeMods => {
		:POISON => [:MUDBOMB, :MUDSLAP, :MUDSHOT],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:moveStatStageMods => {},
	:statusMods => [:SWALLOW, :STEALTHROCK, :SPIKES, :TOXICSPIKES, :STICKYWEB],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:BEACH => {
	:name => "Beach",
	:fieldMessage => [
		"Focus and relax to the sound of crashing waves..."
	],
	:graphic => ["Beach","BeachEve","BeachNight"],
	:secretPower => "MUDSHOT",
	:naturePower => :MEDITATE,
	:mimicry => :GROUND,
	# Weather duration extension - Sandstorm lasts 8 turns instead of 5
	:weatherDuration => {
		:Sandstorm => 8
	},
	:damageMods => {
		1.5 => [:HIDDENPOWER, :BRINE, :SMELLINGSALTS, :CRABHAMMER, :RAZORSHELL, :SHELLSIDEARM, :SHELLTRAP, :SCORCHINGSANDS, :SANDSEARSTORM, :STRENGTH, :LANDSWRATH, :THOUSANDWAVES, :SURF, :MUDDYWATER, :WAVECRASH, :CLANGOROUSSOULBLAZE, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		2.0 => [:MUDSLAP, :MUDSHOT, :MUDBOMB, :SANDTOMB],
		1.3 => [:STOREDPOWER, :ZENHEADBUTT, :FOCUSBLAST, :AURASPHERE, :FOCUSPUNCH],
		1.2 => [:PSYCHIC],
	},
	:accuracyMods => {
		90 => [:FOCUSBLAST],  # Focus Blast accuracy increased to 90%
	},
	:moveMessages => {
		"...And with pure focus!" => [:HIDDENPOWER, :STRENGTH, :CLANGOROUSSOULBLAZE, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		"The sand strengthened the atttack!" => [:LANDSWRATH, :THOUSANDWAVES, :SANDTOMB, :SCORCHINGSANDS, :SANDSEARSTORM],
		"Surf's up!" => [:SURF, :MUDDYWATER, :WAVECRASH],
		"A shining shell on the beach!" => [:RAZORSHELL, :SHELLSIDEARM, :SHELLTRAP],
		"The salty sea strengthened the attack!" => [:BRINE, :SMELLINGSALTS],
		"Time for crab!" => [:CRABHAMMER],
		"Sand mixed into the attack!" => [:MUDSLAP, :MUDSHOT, :MUDBOMB],
		"...And with full focus...!" => [:STOREDPOWER, :ZENHEADBUTT, :FOCUSBLAST, :FOCUSPUNCH, :AURASPHERE],
		"...And with focus...!" => [:PSYCHIC],
	},
	:typeMods => {
		:PSYCHIC => [:STRENGTH],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	# Lowers accuracy of all battlers by 1 stage after:
	#   - Specific moves (spin/wind/tornado effects stir up ash)
	#   - Special Flying-type moves (gusts stir up the sand)
	:accuracyDropOnMove => {
		:message => "The attack stirred up the ash on the ground!",
		:moves   => [:FIRESPIN, :LEAFTORNADO, :RAZORWIND, :TWISTER, :WHIRLPOOL],
		:types   => { :FLYING => { special_only: true } },
	},
	# Stat stage changes boosted by the field (uses moveStatStageMods system)
	# stages: 2 = move does twice its normal stages
	# stages: 3 = move does three times its normal stages
	:moveStatStageMods => {
		:CALMMIND   => { stages: 2, message: "The Beach deepened {1}'s focus! Both Special stats rose sharply!" },
		:KINESIS    => { stages: 2, message: "The Beach scattered the sand! {1}'s accuracy fell sharply!" },
		:SANDATTACK => { stages: 2, message: "The Beach scattered the sand! {1}'s accuracy fell sharply!" },
		:MEDITATE   => { stages: 3, message: "The Beach sharpened {1}'s focus! Attack rose drastically!" },
	},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:CALMMIND, :KINESIS, :MEDITATE, :SANDATTACK, :SANDSTORM, :PSYCHUP, :FOCUSENERGY, :SHOREUP],
	:changeEffects => {},
	# Abilities always active or modified on beach field
	:abilityActivate => {
		:SANDFORCE => {},  # Rock/Ground/Steel moves boosted (passive via existing handler)
		:SANDRUSH  => {},  # Speed doubled (passive via existing handler)
		:SANDVEIL  => {},  # Evasion boosted (passive) + ignore acc/eva changes (hardcoded)
	},
	# Form changes triggered by field
	:abilityFormChanges => {
		:DARMANITAN => {
			:ZENMODE => { form: 1, show_ability: true, message: "{1} calmed its mind and entered Zen Mode!" }
		}
	},
	# Abilities that ignore accuracy/evasion changes when attacking on beach field
	# Unless target has As One or Unnerve
	:ignoreAccEvaChanges => [:INNERFOCUS, :OWNTEMPO, :PUREPOWER, :SANDVEIL, :STEADFAST],
	# Status immunity on beach field
	# Fighting-types and Inner Focus cannot be confused
	:statusImmunity => {
		:CONFUSION => {
			types: [:FIGHTING],
			abilities: [:INNERFOCUS],
			message: "The Beach's focus prevents confusion!"
		}
	},
	# Water Compaction: additionally boosts SpDef by 2 stages (hardcoded in section 14)
	# Sand Spit: lowers all foes' accuracy by 1 stage on activation (hardcoded in section 14)
	# Item effect modifications
	# Shell Bell restores 25% of damage dealt instead of 12.5% (1/8)
	# NOTE: Requires manual implementation in base game's Shell Bell code (Battle::Move#pbEffectAfterAllHits)
	:itemEffectMods => {
		:SHELLBELL => { heal_percent: 0.25 }
	},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :FocusEnergy,
		:duration => 3,
		:message => "{1}'s Telluric Seed is getting it pumped!",
		:animation => :FOCUSENERGY,
		:stats => {
		},
	},
},
:WATERSURFACE => {
	:name => "Water Surface",
	:fieldMessage => [
		"The water's surface is calm."
	],
	:graphic => ["Water"],
	:secretPower => "AQUAJET",
	:naturePower => :WHIRLPOOL,
	:mimicry => :WATER,
	# Abilities activated on Water Surface
	:abilityActivate => {
		:SWIFTSWIM      => {},  # Speed 2x (hardcoded section 30)
		:HYDRATION      => {},  # Cures status EOR (hardcoded section 30)
		:TORRENT        => {},  # Always active (hardcoded section 30)
		:SURGESURFER    => {},  # Speed 2x (hardcoded section 30)
		:WATERVEIL      => {},  # Cures all status (hardcoded section 30)
		:DRYSKIN        => {},  # Gradual HP restore (hardcoded section 30)
		:WATERABSORB    => {},  # Gradual HP restore (hardcoded section 30)
		:WATERCOMPACTION => {},  # Each turn activation (hardcoded section 30)
		:STEAMENGINE    => {},  # Speed +1 EOR (hardcoded section 30)
		:SCHOOLING      => {},  # Always active (hardcoded section 30)
		:GULPMISSILE    => {},  # Always Arrokuda (hardcoded section 30)
	},
	# Ability modifications
	:abilityMods => {
		:PROPELLERTAIL => { priority_boost: 1.5 },  # Priority moves 1.5x
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:TAKEHEART => { additional_stats: { :SPECIAL_ATTACK => 1 }, message: "The water cleansed {1} and boosted Sp. Atk!" },
		:SPLASH => { target_effect: :lower_accuracy, message: "{1} splashed water in the opponent's face!" },
		:WAVECRASH => { recoil_reduction: 0.25 },  # Reduce recoil to 25%
	},
	# No charging moves
	:noCharging => [:DIVE],
	:noChargingMessages => {
		:DIVE => "The shallow water allowed instant diving!",
	},
	:damageMods => {
		1.2 => [:WHIRLPOOL, :SURF, :MUDDYWATER, :WHIRLPOOL, :DIVE, :SLUDGEWAVE, :OCTAZOOKA, :ORIGINPULSE, :HYDROVORTEX],
		0 => [:SPIKES, :TOXICSPIKES],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The attack rode the current!" => [:WHIRLPOOL, :SURF, :MUDDYWATER, :WHIRLPOOL, :DIVE, :ORIGINPULSE, :HYDROVORTEX],
		"Poison spread through the water!" => [:SLUDGEWAVE],
		"...The spikes sank into the water and vanished!" => [:SPIKES, :TOXICSPIKES],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SLUDGEWAVE],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:WATER, :ELECTRIC],
		0.5 => [:FIRE],
		0 => [:GROUND],
	},
	:typeMessages => {
		"The water conducted the attack!" => [:ELECTRIC],
		"The water strengthened the attack!" => [:WATER],
		"The water deluged the attack..." => [:FIRE],
		"...But there was no solid ground to attack from!" => [:GROUND],
	},
	:typeCondition => {
		:FIRE => "!opponent.isAirborne?",
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {
		:MURKWATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:UNDERWATER => [:GRAVITY, :DIVE, :ANCHORSHOT, :GRAVAPPLE],
		:ICY => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
		:MURKWATERSURFACE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:dontChangeBackup => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	:changeMessage => {
		 "The battle sank into the depths!" => [:GRAVITY, :GRAVAPPLE],
		 "The battle was pulled underwater!" => [:DIVE, :ANCHORSHOT],
		 "The water froze over!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
		 "The water was polluted!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:statusMods => [:SPLASH, :AQUARING, :LIFEDEW, :TAKEHEART],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :AquaRing,
		:duration => true,
		:message => "{1} surrounded itself with a veil of water!",
		:animation => :AQUARING,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:UNDERWATER => {
	:name => "Underwater",
	:fieldMessage => [
		"Blub blub..."
	],
	:graphic => ["Underwater"],
	:secretPower => "AQUATAIL",
	:naturePower => :WATERPULSE,
	:mimicry => :WATER,
	# No charging
	:noCharging => [:DIVE],
	# Abilities (same as Water Surface mostly)
	:abilityActivate => {
		:SWIFTSWIM   => {},
		:TORRENT     => {},
		:HYDRATION   => {},
		:SURGESURFER => {},
		:WATERVEIL   => {},
		:DRYSKIN     => {},
		:WATERABSORB => {},
	},
	:damageMods => {
		1.5 => [:WATERPULSE],
		2.0 => [:ANCHORSHOT, :DRAGONDARTS, :SLUDGEWAVE, :ACIDDOWNPOUR],
		0 => [:SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE, :SHADOWSKY, :TARSHOT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"Jet-streamed!" => [:WATERPULSE],
		"From the depths!" => [:ANCHORSHOT, :DRAGONDARTS],
		"You're too deep to notice the weather!" => [:SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE, :SHADOWSKY],
		"The tar washed of instantly!" => [:TARSHOT],
	},
	:typeMods => {
		:WATER => [:DRAGONDARTS, :GRAVAPPLE],
	},
	:typeAddOns => {
		:WATER => [:GROUND],
	},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SLUDGEWAVE],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:WATER],
		2.0 => [:ELECTRIC],
		0 => [:FIRE],
	},
	:typeMessages => {
		"The water strengthened the attack!" => [:WATER],
		"The water super-conducted the attack!" => [:ELECTRIC],
		"...But the attack was doused instantly!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:MURKWATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:WATERSURFACE => [:DIVE, :SKYDROP, :FLY, :BOUNCE],
		:MURKWATERSURFACE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle resurfaced!" => [:DIVE, :SKYDROP, :FLY, :BOUNCE, :SHOREUP],
		 "The grime sank beneath the battlers!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:statusMods => [:AQUARING, :TAKEHEART],
	:changeEffects => {
		"@battle.waterPollution" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} transformed into the Water type!",
		:animation => :SOAK,
		:stats => {
			:SPEED => 1,
		},
	},
},
:CAVE => {
	:name => "Cave",
	:fieldMessage => [
		"The cave echoes dully..."
	],
	:graphic => ["Cave"],
	:secretPower => "ROCKWRECKER",
	:naturePower => :ROCKTOMB,
	:mimicry => :ROCK,
	:abilityMods => {
    :PUNKROCK => { multiplier: 1.5 },
	},
	# Abilities activated on cave field
	:abilityActivate => {
		:PUNKROCK => {},  # Sound moves 1.5x (passive, already checked via abilityMods)
	},
	# Ground-type moves can hit airborne Pokemon on cave field
	:groundHitsAirborne => true,
	# Stealth Rock damage doubled (handled in section for hazards)
	:hazardMultiplier => {
		:StealthRock => 2.0
	},
	:damageMods => {
		1.5 => [:ROCKTOMB],
		0 => [:SKYDROP],
	},
    :noCharging => [:BOUNCE, :FLY],  # Skip charging turn - attack immediately
    :noChargingMessages => {
      :FLY => "The cave's low ceiling makes flying high impossible!",
      :BOUNCE => "The cave's low ceiling prevents a high bounce!",
    },
    :soundBoost => {
    multiplier: 1.5,                    # 50% boost to all sound moves
    message: "The cave echoed the sound!"
    },
	:accuracyMods => {},
	:moveMessages => {
		"...Piled on!" => [:ROCKTOMB],
		"The cave's low ceiling makes flying high impossible!" => [:SKYDROP],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.caveCollapse" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :CONTINENTALCRUSH],
		"@battle.field_counters.counter2 += 1" => [:DRAGONPULSE],
		"@battle.field_counters.counter2 = 2" => [:DRACOMETEOR, :DEVASTATINGDRAKE],
		"@battle.field_counters.counter3 += 1" => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		"@battle.field_counters.counter4 += 1" => [:GRAVITY],
	},
	:typeBoosts => {
		1.5 => [:ROCK],
		0.5 => [:FLYING],
	},
	:typeMessages => {
		"The cave choked out the air!" => [:FLYING],
		"The cavern strengthened the attack!" => [:ROCK],
	},
	:typeCondition => {
		:FLYING => "!self.contactMove?",
	},
	:typeEffects => {},
	:changeCondition => {
		:DRAGONSDEN => "@battle.field_counters.counter2 > 1",
		:VOLCANIC => "@battle.field_counters.counter3 > 1",
		:DEEPEARTH => "@battle.field_counters.counter4 > 1",
	},
	:fieldChange => {
		:CRYSTALCAVERN => [:POWERGEM, :DIAMONDSTORM],
		:ICY => [:BLIZZARD, :SUBZEROSLAMMER],
		:CORRUPTED => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		:VOLCANIC => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		:DRAGONSDEN => [:DRAGONPULSE, :DRACOMETEOR, :DEVASTATINGDRAKE],
		:DEEPEARTH => [:GRAVITY],
	},
	:dontChangeBackup => [:BLIZZARD, :SUBZEROSLAMMER],
	:changeMessage => {
		"The cave was littered with crystals!" => [:POWERGEM, :DIAMONDSTORM],
		"The cavern froze over!" => [:BLIZZARD, :SUBZEROSLAMMER],
		"The cave was corrupted!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		"The flame ignited the cave!" => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		"The draconic energy mutated the field!" => [:DRAGONPULSE, :DRACOMETEOR, :DEVASTATINGDRAKE],
		"The battle was pulled deeper into the earth!" => [:GRAVITY],
	},
	:statusMods => [:STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was hurt by Stealth Rocks!",
		:animation => nil,
		:stats => {
			:DEFENSE => 2,
		},
	},
},
:GLITCH => {
	:name => "Glitch Field",
	:fieldMessage => [
		"1n!taliz3 .b//////attl3"
	],
	:graphic => ["Glitch","99"],
	:secretPower => "PSYCHIC",  # 4 = Lower Speed
	:naturePower => :METRONOME,
	:mimicry => :QMARKS,
	:damageMods => {
		0 => [:ROAR, :WHIRLWIND],
	},
	:accuracyMods => {
		90 => [:BLIZZARD],
	},
	:moveMessages => {
		"ERROR! MOVE NOT FOUND!" => [:ROAR, :WHIRLWIND],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.2 => [:PSYCHIC],
	},
	:typeMessages => {
		".0P pl$ nerf!-//" => [:PSYCHIC],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:moveStatStageMods => {},
	:statusMods => [:METRONOME],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1}.TYPE = (:QMARKS)",
		:animation => :AMNESIA,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:CRYSTALCAVERN => {
	:name => "Crystal Cavern",
	:fieldMessage => [
		"The cave is littered with crystals."
	],
	:graphic => ["CrystalCavern"],
	:secretPower => "POWERGEM",
	:naturePower => :POWERGEM,
	:mimicry => :DRAGON,  # Randomly Fire/Water/Grass/Psychic (hardcoded in section 22)
	# Ability modifications
	:abilityMods => {
		:PRISMARMOR => { defense_boost: 1.33 },  # 33% increased defenses
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:ROCKPOLISH => { additional_stats: { :ATTACK => 1, :SPECIAL_ATTACK => 1 }, message: "The crystals enhanced Rock Polish! Speed rose sharply and Attack and Sp. Atk rose!" },
	},
	:damageMods => {
		1.3 => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :DAZZLINGGLEAM, :MIRRORSHOT, :TECHNOBLAST, :DOOMDUMMY, :MOONGEISTBEAM, :PHOTONGEYSER, :MENACINGMOONRAZEMAELSTROM],
		1.5 => [:POWERGEM, :DIAMONDSTORM, :ANCIENTPOWER, :JUDGMENT, :ROCKSMASH, :ROCKTOMB, :STRENGTH, :ROCKCLIMB, :MULTIATTACK, :PRISMATICLASER, :LUSTERPURGE],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The crystals' light strengthened the attack!" => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DAZZLINGGLEAM, :MIRRORSHOT, :TECHNOBLAST, :DOOMDUMMY, :MOONGEISTBEAM, :PHOTONGEYSER, :PRISMATICLASER, :MENACINGMOONRAZEMAELSTROM],
		"The crystals strengthened the attack!" => [:POWERGEM, :DIAMONDSTORM, :ANCIENTPOWER, :JUDGMENT, :ROCKSMASH, :ROCKTOMB, :STRENGTH, :ROCKCLIMB, :MULTIATTACK],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE],
		"@battle.field_counters.counter = 2" => [:TECTONICRAGE],
	},
	:typeBoosts => {
		1.5 => [:ROCK, :DRAGON],
	},
	:typeMessages => {
		"The crystals charged the attack!" => [:ROCK],
		"The crystal energy strengthened the attack!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CAVE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:CAVE => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		:DARKCRYSTALCAVERN => [:DARKPULSE, :DARKVOID, :NIGHTDAZE, :LIGHTTHATBURNSTHESKY],
	},
	:dontChangeBackup => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :DARKPULSE, :DARKVOID, :NIGHTDAZE],
	:changeMessage => {
		 "The crystals were broken up!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		 "The crystals' light was warped by the darkness!" => [:DARKPULSE, :DARKVOID, :NIGHTDAZE],
		 "The crystals' light was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:ROCKPOLISH, :STEALTHROCK, :AURORAVEIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} shrouded itself with Magic Coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:DARKCRYSTALCAVERN => {
	:name => "Dark Crystal Cavern",
	:fieldMessage => [
		"Darkness is gathering..."
	],
	:graphic => ["DarkCrystalCavern"],
	:secretPower => "SHADOWBALL",  # Flinch effect (effect 11 in parser)
	:naturePower => :DARKPULSE,
	:mimicry => :DARK,
	# Ability modifications
	:abilityMods => {
		:PRISMARMOR => { defense_boost: 1.33 },  # 33% increased defenses
		:SHADOWSHIELD => { damage_reduction: 0.75 },  # Take 0.75x damage
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:FLASH => { stages: 2, message: "The darkness amplified Flash! {1}'s accuracy harshly fell!" },
		:SYNTHESIS => { heal_percent: 0.25, message: "{1} barely absorbed any light!" },
		:MORNINGSUN => { heal_percent: 0.25, message: "{1} barely absorbed any light!" },
		:MOONLIGHT => { heal_percent: 0.75, message: "The moonlight was strengthened by darkness!" },
	},
	:damageMods => {
		1.5 => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWCLAW, :SHADOWFORCE, :SHADOWSNEAK, :SHADOWPUNCH, 
		        :AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DAZZLINGGLEAM, :MIRRORSHOT, :DOOMDUMMY, 
		        :TECHNOBLAST, :POWERGEM, :MOONGEISTBEAM, :SHADOWBONE, :PHOTONGEYSER, :DIAMONDSTORM, :BLACKHOLEECLIPSE, 
		        :MENACINGMOONRAZEMAELSTROM, :MIRRORBEAM],
		2.0 => [:PRISMATICLASER],
		0 => [:SOLARBEAM, :SOLARBLADE],
	},
	:accuracyMods => {
		100 => [:DARKVOID],
	},
	:moveMessages => {
		"The darkness strengthened the attack!" => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWCLAW, :SHADOWFORCE, :SHADOWSNEAK, :SHADOWPUNCH],
		"The crystals' darkness charged the attack!" => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DAZZLINGGLEAM, :MIRRORSHOT, :DOOMDUMMY, :TECHNOBLAST, :POWERGEM, :MOONGEISTBEAM, :SHADOWBONE, :PHOTONGEYSER, :DIAMONDSTORM, :BLACKHOLEECLIPSE, :MENACINGMOONRAZEMAELSTROM, :MIRRORBEAM],
		"The attack was supercharged by the dark crystals!" => [:PRISMATICLASER],
		"The darkness prevented the solar attack!" => [:SOLARBEAM, :SOLARBLADE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE],
		"@battle.field_counters.counter = 2" => [:TECTONICRAGE],
	},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CAVE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:CAVE => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
	},
	:weatherFieldChange => {
		:CRYSTALCAVERN => {
			weather: [:Sun, :HarshSun],
			messages: {
				:Sun => "The sunlight dispelled the darkness!",
				:HarshSun => "The harsh sunlight dispelled the darkness!"
			}
		}
	},
	:dontChangeBackup => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
	:changeMessage => {
		"The dark crystals were broken up!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
	},
	:statusMods => [:FLASH, :AURORAVEIL, :SYNTHESIS, :MORNINGSUN, :MOONLIGHT],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} shrouded itself with Magic Coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:MURKWATERSURFACE => {
	:name => "Murkwater Surface",
	:fieldMessage => ["The water is tainted..."],
	:graphic => ["MurkwaterSurface"],
	:secretPower => "SLUDGEBOMB",
	:naturePower => :SLUDGEWAVE,
	:mimicry => :POISON,
	# Abilities (Section 39)
	:abilityActivate => {
		:POISONHEAL => {},
		:TOXICBOOST => {},
		:MERCILESS => {},
		:SWIFTSWIM => {},
		:SURGESURFER => {},
		:WATERCOMPACTION => { eor: true },  # Each turn
		:SCHOOLING => { always_active: true },
	},
	# Move stat mods
	:moveStatStageMods => {
		:ACIDARMOR => { stats_override: { :DEFENSE => 3 } },  # Amplified
		:TARSHOT => { additional_effect: :poison },
		:LIFEDEW => { additional_effect: :poison },
	},
	:damageMods => {
		1.5 => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :ACID, :ACIDSPRAY, :BRINE, :THOUSANDWAVES, :APPLEACID, :MUDBARRAGE],
		0 => [:SPIKES, :TOXICSPIKES],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The toxic water strengthened the attack!" => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :ACID, :ACIDSPRAY, :THOUSANDWAVES, :APPLEACID, :MUDBARRAGE],
		"Stinging!" => [:BRINE],
		"...The spikes sank into the water and vanished!" => [:SPIKES, :TOXICSPIKES],
	},
	:typeMods => {
		:POISON => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :THOUSANDWAVES, :APPLEACID, :MUDBARRAGE],
		:WATER => [:SLUDGEWAVE, :MUDBOMB, :MUDSLAP, :MUDSHOT, :THOUSANDWAVES, :MUDBARRAGE],
	},
	:typeAddOns => {
		:POISON => [:WATER],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:WATER, :POISON],
		1.3 => [:ELECTRIC],
		0 => [:GROUND],
	},
	:typeMessages => {
		"The toxic water strengthened the attack!" => [:WATER, :POISON],
		"The toxic water conducted the attack!" => [:ELECTRIC],
		"...But there was no solid ground to attack from!" => [:GROUND],
	},
	:typeCondition => {
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:WATERSURFACE => [:WHIRLPOOL, :PURIFY],
		:ICY => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:dontChangeBackup => [:WHIRLPOOL, :PURIFY, :BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	:changeMessage => {
		"The maelstrom flushed out the poison!" => [:WHIRLPOOL],
		"The attack cleared the waters!" => [:PURIFY],
		"The toxic water froze over!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:statusMods => [:ACIDARMOR, :TARSHOT, :VENOMDRENCH, :VENOSHOCK, :BARBBARRAGE, :LIFEDEW],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :AquaRing,
		:duration => true,
		:message => "{1} surrounded itself with a veil of water! {1} was poisoned!",
		:animation => :AQUARING,
		:stats => {
			:SPEED => 1,
		},
	},
},
:MOUNTAIN => {
	:name => "Mountain",
	:fieldMessage => [
		"High up!",
	],
	:graphic => ["Mountain"],
	:secretPower => "ROCKBLAST",
	:naturePower => :ROCKSLIDE,
	:mimicry => :ROCK,
	# Weather duration extended
	:weatherDuration => {
		:Sun => 8,
		:HarshSun => 8,
	},
	# Abilities activated/modified on Mountain Field
	:abilityActivate => {
		:GALEWINGS => { during_strong_winds: true },  # Active during Strong Winds
		:LONGREACH => {},  # 1.5x damage (hardcoded section 27)
	},
	# Ability modifications
	:abilityMods => {
		:AERILATE => { multiplier: 1.5 },
	},
	# Tailwind lasts 6 turns and creates Strong Winds (same as Volcanic Top)
	:statusMods => [:TAILWIND, :SUNNYDAY],
	:damageMods => {
		1.5 => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW, :OMINOUSWIND, :ICYWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :THUNDER, :ERUPTION, :AVALANCHE, :HYPERVOICE, :MOUNTAINGALE],
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"{1} was thrown partway down the mountain!" => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW],
		"The wind strengthened the attack!" => [:OMINOUSWIND, :ICYWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :MOUNTAINGALE],
		"The mountain strengthened the attack!" => [:THUNDER, :ERUPTION, :AVALANCHE],
		"Yodelayheehoo~" => [:HYPERVOICE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK, :FLYING],
	},
	:typeMessages => {
		"The mountain strengthened the attack!" => [:ROCK],
		"The open air strengthened the attack!" => [:FLYING],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:SNOWYMOUNTAIN => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER, :MOUNTAINGALE],
		:SKY => [:FLY, :BOUNCE],
		:VOLCANICTOP => [:LAVAPLUME, :ERUPTION, :INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The mountain was covered in snow!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER, :MOUNTAINGALE],
		"The battle was taken to the skies!" => [:FLY, :BOUNCE],
		"The mountain erupted!" => [:LAVAPLUME, :ERUPTION, :INFERNOOVERDRIVE],
	},
	:statusMods => [:TAILWIND, :SUNNYDAY],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 2,
			:ACCURACY => -1,
		},
	},
},
:SNOWYMOUNTAIN => {
	:name => "Snowy Mountain",
	:fieldMessage => [
		"The snow glows white on the mountain..."
	],
	:graphic => ["SnowyMountain"],
	:secretPower => "ICEBALL",
	:naturePower => :AVALANCHE,
	:mimicry => :ICE,
	# Weather duration extended
	:weatherDuration => {
		:Sun => 8,
		:HarshSun => 8,
		:Hail => 8,
		:Snow => 8,
	},
	# Abilities activated/modified on Snowy Mountain Field
	:abilityActivate => {
		:GALEWINGS => { during_strong_winds: true },  # Active during Strong Winds
		:SLUSHRUSH => {},  # Activated in hail (hardcoded section 28)
		:ICEBODY => {},  # Activated in hail (hardcoded section 28)
		:SNOWCLOAK => {},  # Activated in hail (hardcoded section 28)
		:LONGREACH => {},  # 1.5x damage (hardcoded section 28)
		:BALLFETCH => {},  # Gets Snowballs (hardcoded section 28)
	},
	# Ability modifications
	:abilityMods => {
		:REFRIGERATE => { multiplier: 1.5 },
		:AERILATE => { multiplier: 1.5 },
		:ICESCALES => { ignore_ice_weakness: true },  # Ignores Ice weakness (hardcoded section 28)
	},
	# Aurora Veil enabled
	:statusMods => [:TAILWIND, :SUNNYDAY, :HAIL, :AURORAVEIL, :BITTERMALICE],
	:damageMods => {
		1.5 => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW, :OMINOUSWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :AVALANCHE, :POWDERSNOW, :HYPERVOICE, :GLACIATE, :MOUNTAINGALE, :BITTERMALICE],
		0.5 => [:SCALD, :STEAMERUPTION],
		2.0 => [:ICYWIND],
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"{1} was thrown partway down the mountain!" => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW],
		"The wind strengthened the attack!" => [:OMINOUSWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :MOUNTAINGALE],
		"The snow strengthened the attack!" => [:AVALANCHE, :POWDERSNOW, :BITTERMALICE],
		"The cold softened the attack..." => [:SCALD, :STEAMERUPTION],
		"The frigid wind strengthened the attack!" => [:ICYWIND],
		"Yodelayheehoo~" => [:HYPERVOICE],
	},
	:typeMods => {},
	:typeAddOns => {
		:ICE => [:ROCK],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK, :ICE, :FLYING],
		0.5 => [:FIRE],
	},
	:typeMessages => {
		"The snowy mountain strengthened the attack!" => [:ROCK, :ICE],
		"The open air strengthened the attack!" => [:FLYING],
		"The cold softened the attack!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:MOUNTAIN => [:HEATWAVE, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		:VOLCANICTOP => [:ERUPTION],
		:SKY => [:FLY, :BOUNCE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The snow melted away!" => [:HEATWAVE, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		"The mountain erupted!" => [:ERUPTION],
		"The battle was taken to the skies!" => [:FLY, :BOUNCE],
	},
	:statusMods => [:TAILWIND, :SUNNYDAY, :HAIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 2,
			:ACCURACY => -1,
		},
	},
},
:HOLY => {
	:name => "Blessed Field",
	:fieldMessage => [
		"The field is blessed!"
	],
	:graphic => ["Ruin","Ruin2","Ruin3"],
	:secretPower => "DAZZLINGGLEAM",
	:naturePower => :JUDGMENT,
	:mimicry => :NORMAL,
	# Abilities activated/modified on Blessed Field
	:abilityActivate => {
		:JUSTIFIED => {},  # Effect doubled (hardcoded section 26)
		:CURSEDBODY => { disabled: true },  # Has no effect
		:PERISHBODY => { disabled: true },  # Has no effect
		:RKSSYSTEM  => {},  # Always Dark type (hardcoded section 26)
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:COSMICPOWER => { stats_override: { :DEFENSE => 2, :SPECIAL_DEFENSE => 2 }, message: "The blessing enhanced Cosmic Power!" },
		:MIRACLEEYE => { additional_stats: { :SPECIAL_ATTACK => 1 }, message: "Miracle Eye boosted Sp. Atk!" },
	},
	:damageMods => {
		1.3 => [:PSYSTRIKE, :AEROBLAST, :ORIGINPULSE, :DOOMDUMMY, :MISTBALL, :CRUSHGRIP, :LUSTERPURGE, :SECRETSWORD, :PSYCHOBOOST, :RELICSONG, :SPACIALREND, :HYPERSPACEHOLE, :ROAROFTIME, :LANDSWRATH, :PRECIPICEBLADES, :DRAGONASCENT, :MOONGEISTBEAM, :SUNSTEELSTRIKE, :PRISMATICLASER, :FLEURCANNON, :DIAMONDSTORM, :GENESISSUPERNOVA, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM, :BEHEMOTHBLADE, :BEHEMOTHBASH, :ETERNABEAM, :DYNAMAXCANNON],
		1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :ANCIENTPOWER, :JUDGMENT, :SACREDFIRE, :EXTREMESPEED, :SACREDSWORD, :RETURN],
	},
	:accuracyMods => {},
	:moveMessages => {
		"Legendary power accelerated the attack!" => [:PSYSTRIKE, :AEROBLAST, :SACREDFIRE, :ORIGINPULSE, :DOOMDUMMY, :JUDGMENT, :MISTBALL, :CRUSHGRIP, :LUSTERPURGE, :SECRETSWORD, :PSYCHOBOOST, :RELICSONG, :SPACIALREND, :HYPERSPACEHOLE, :ROAROFTIME, :LANDSWRATH, :PRECIPICEBLADES, :DRAGONASCENT, :MOONGEISTBEAM, :SUNSTEELSTRIKE, :PRISMATICLASER, :FLEURCANNON, :DIAMONDSTORM, :GENESISSUPERNOVA, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM, :BEHEMOTHBLADE, :BEHEMOTHBASH, :ETERNABEAM, :DYNAMAXCANNON],
		"The holy energy resonated with the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :ANCIENTPOWER, :SACREDSWORD, :RETURN],
		"Godspeed!" => [:EXTREMESPEED],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FAIRY, :NORMAL],
		1.2 => [:PSYCHIC, :DRAGON],
		0.5 => [:GHOST, :DARK],
	},
	:typeMessages => {
		"The holy energy resonated with the attack!" => [:FAIRY, :NORMAL],
		"The legendary energy resonated with the attack!" => [:PSYCHIC, :DRAGON],
		"The attack was cleansed..." => [:GHOST, :DARK],
	},
	:typeCondition => {
		:FAIRY => "self.specialMove?(type)",
		:NORMAL => "self.specialMove?(type)",
		:DARK => "self.specialMove?(type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:LIGHTTHATBURNSTHESKY],
		:HAUNTED=> [:CURSE, :PHANTOMFORCE, :SHADOWFORCE, :OMINOUSWIND, :TRICKORTREAT],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"Evil spirits gathered!" => [:CURSE, :PHANTOMFORCE, :SHADOWFORCE, :OMINOUSWIND, :TRICKORTREAT],
		"The holy light was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:LIFEDEW, :WISH, :MIRACLEEYE, :COSMICPOWER, :NATURESMADNESS],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} shrouded itself with Magic Coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:FAIRYTALE => {
	:name => "Fairy Tale Field",
	:fieldMessage => [
		"Once upon a time..."
	],
	:graphic => ["FairyTale"],
	:secretPower => "SEEDBOMB",  # Sleep effect (effect 2 in parser)
	:naturePower => :SECRETSWORD,
	:mimicry => :FAIRY,
	:damageMods => {
		1.5 => [:NIGHTSLASH, :LEAFBLADE, :PSYCHOCUT, :SMARTSTRIKE, :AIRSLASH, :SOLARBLADE, :MAGICALLEAF, :MYSTICALFIRE, :ANCIENTPOWER, :RELICSONG, :SPARKLINGARIA, :MOONGEISTBEAM, :FLEURCANNON, :RAZORSHELL, :BEHEMOTHBLADE, :BEHEMOTHBASH, :OCEANICOPERETTA, :MENACINGMOONRAZEMAELSTROM,:CEASELESSEDGE,:STONEAXE,:AQUACUTTER],
		2.0 => [:DRAININGKISS, :MISTBALL],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The blade cuts true!" => [:NIGHTSLASH, :LEAFBLADE, :PSYCHOCUT, :SMARTSTRIKE, :AIRSLASH, :SOLARBLADE, :RAZORSHELL, :BEHEMOTHBLADE],
		"The magical energy strengthened the attack!" => [:MAGICALLEAF, :MYSTICALFIRE, :ANCIENTPOWER, :RELICSONG, :SPARKLINGARIA, :MOONGEISTBEAM, :FLEURCANNON, :BEHEMOTHBASH, :MISTBALL, :OCEANICOPERETTA, :MENACINGMOONRAZEMAELSTROM],
		"True love never hurt so badly!" => [:DRAININGKISS],
	},
	# moveStatStageMods: amplified stat-change moves (§ manual l.1674-1675)
	# Noble Roar amplification (-2 Atk, -2 SpAtk) is hardcoded in 010 (multi-stat)
	:moveStatStageMods => {
		:ACIDARMOR   => { stages: 2, message: "The fairy magic amplified the Defense boost!" },
		:SWORDSDANCE => { stages: 2, message: "The fairy power honed the blade to perfection!" },
	},
	:typeMods => {},
	:typeAddOns => {
		:DRAGON => [:FIRE],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:STEEL, :FAIRY],
		2.0 => [:DRAGON],
	},
	:typeMessages => {
		"For ever after!" => [:FAIRY],
		"For justice!" => [:STEEL],
		"The foul beast's attack gained strength!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	# Single-stat switch-in ability boosts (§ manual l.1696-1705)
	# Multi-stat boosts (Dauntless Shield, Power of Alchemy, Intrepid Sword, Stance Change) are hardcoded in 010
	:abilityStatBoosts => {
		:BATTLEARMOR => { stat: :DEFENSE,         stages: 1, message: "{1}'s Battle Armor hardened!" },
		:SHELLARMOR  => { stat: :DEFENSE,         stages: 1, message: "{1}'s Shell Armor fortified!" },
		:MAGICGUARD  => { stat: :SPECIAL_DEFENSE, stages: 1, message: "{1}'s Magic Guard fortified its spirit!" },
		:MAGICBOUNCE => { stat: :SPECIAL_DEFENSE, stages: 1, message: "{1}'s Magic Bounce shielded its mind!" },
		:MIRRORARMOR => { stat: :SPECIAL_DEFENSE, stages: 1, message: "{1}'s Mirror Armor reflected its resolve!" },
		:PASTELVEIL  => { stat: :SPECIAL_DEFENSE, stages: 1, message: "{1}'s Pastel Veil fortified its spirit!" },
		:MAGICIAN    => { stat: :SPECIAL_ATTACK,  stages: 1, message: "{1}'s Magician power surged!" },
	},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:KINGSSHIELD, :CRAFTYSHIELD, :FLOWERSHIELD, :ACIDARMOR, :NOBLEROAR, :SWORDSDANCE, :WISH, :HEALINGWISH, :MIRACLEEYE, :FORESTSCURSE, :FLORALHEALING, :STRANGESTEAM, :STANCECHANGE],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Protect,
		:duration => :KingsShield,
		:message => "The Magical Seed shielded {1} against damage!",
		:animation => :KINGSSHIELD,
		:stats => {
		},
	},
},
:DRAGONSDEN => {
	:name => "Dragon's Den",
	:fieldMessage => [
		"If you wish to slay a dragon..."
	],
	:graphic => ["DragonsDen"],
	:secretPower => "FLAMETHROWER",
	:naturePower => :DRAGONPULSE,
	:mimicry => :DRAGON,
	:noCharging => [:FLY, :BOUNCE],
	:noChargingMessages => {
		:FLY => "The dragon's wrath pulls the attack down instantly!",
		:BOUNCE => "The scorching lava prevents a high bounce!",
	},
	:damageMods => {
		1.5 => [:MEGAKICK, :MAGMASTORM, :LAVAPLUME, :STOMPINGTANTRUM, :EARTHPOWER, :DIAMONDSTORM, :SHELLTRAP, :POWERGEM, :ROCKCLIMB, :STRENGTH, :MATRIXSHOT, :MAGMADRIFT],
		2.0 => [:SMACKDOWN, :THOUSANDARROWS, :DRAGONASCENT, :PAYDAY, :MISTBALL, :LUSTERPURGE,],
		0 => [:GRASSYTERRAIN, :PSYCHICTERRAIN, :MISTYTERRAIN, :ELECTRICTERRAIN, :MIST, :HAIL],
	},
	:accuracyMods => {
		100 => [:DRAGONRUSH],
	},
	:moveMessages => {
		"Trial of the Dragon!!!" => [:MEGAKICK],
		"Wrath of the Dragon!!!" => [:STOMPINGTANTRUM],
		"Unrivaled Power!" => [:STRENGTH, :ROCKCLIMB],
		"The lava strengthened the attack!" => [:MAGMASTORM, :LAVAPLUME, :EARTHPOWER, :SHELLTRAP, :MAGMADRIFT],
		"The draconic energy guided the shot!" => [:MATRIXSHOT],
		"{1} was knocked into the lava!" => [:SMACKDOWN, :THOUSANDARROWS],
		"The draconic energy boosted the attack!" => [:DRAGONASCENT, :MISTBALL, :LUSTERPURGE],
		"Sparkling treasure!" => [:PAYDAY, :POWERGEM, :DIAMONDSTORM],
		"The draconic power blocked the terrain..." => [:GRASSYTERRAIN, :PSYCHICTERRAIN, :MISTYTERRAIN, :ELECTRICTERRAIN, :MIST],
		"The hail is melting in the heat..." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:SMACKDOWN, :THOUSANDARROWS, :STRENGTH, :ROCKCLIMB, :EARTHQUAKE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:DRAGON, :FIRE],
		1.3 => [:ROCK],
		0.5 => [:ICE, :WATER],
	},
	:typeMessages => {
		"The lava's heat boosted the flame!" => [:FIRE],
		"The draconic energy boosted the attack!" => [:DRAGON],
		"The lava's heat softened the attack..." => [:ICE, :WATER],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CAVE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:CAVE => [:GLACIATE, :SUBZEROSLAMMER, :OCEANICOPERETTA, :HYDROVORTEX],
		:FAIRYTALE => [:MISTBALL],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The lava was frozen solid!" => [:GLACIATE, :SUBZEROSLAMMER],
		 "The lava solidified!" => [:OCEANICOPERETTA, :HYDROVORTEX],
		 "The mist-ical energy altered the surroundings!" => [:MISTBALL],
	},
	# Dragon Dance (+2 Atk/Speed), Noble Roar (-2 Atk/SpAtk), Coil (+2 Atk/Def/Acc)
	# are multi-stat moves amplified in 010_Comprehensive_Field_Mechanics.rb
	:moveStatStageMods => {},
	:statusMods => [:DRAGONDANCE, :NOBLEROAR, :COIL, :STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :FlashFire,
		:duration => true,
		:message => "{1} raised its Fire power!",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:FLOWERGARDEN1 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden0"],
	:secretPower => "SWEETSCENT",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
	},
	:accuracyMods => {},
	:moveMessages => {
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:FLOWERGARDEN2 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	},
	:dontChangeBackup => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY, :ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	:changeMessage => {
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY, :ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN2 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden1"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.1 => [:GRASS],
	},
	:typeMessages => {
		"The garden's power boosted the attack!" => [:GRASS],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:FLOWERGARDEN3 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN1 => [:CUT,:XSCISSOR,:ACIDDOWNPOUR],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN3 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden2"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT],
		1.2 => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The fresh scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE,:BUG],
		1.3 => [:GRASS],
	},
	:typeMessages => {
		"The budding flowers boosted the attack!" => [:GRASS],
		"The attack infested the garden!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN4 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN2 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR,:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN4 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden3"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT,:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The vibrant aroma scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		2.0 => [:BUG],
		1.5 => [:FIRE,:GRASS],
	},
	:typeMessages => {
		"The blooming flowers boosted the attack!" => [:GRASS],
		"The attack infested the flowers!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN5 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN3 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR],
		:FLOWERGARDEN2 => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN5 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden4"],
	:secretPower => "PETALDANCE",
	:naturePower => :PETALBLIZZARD,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT,:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The vibrant aroma scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		2.0 => [:GRASS,:BUG],
		1.5 => [:FIRE],
	},
	:typeMessages => {
		"The thriving flowers boosted the attack!" => [:GRASS],
		"The attack infested the flowers!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN4 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR],
		:FLOWERGARDEN3 => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:INVERSE => {
	:name => "Inverse Field",
	:fieldMessage => [
		"!trats elttaB"
	],
	:graphic => ["Inverse"],
	:secretPower => "CONFUSION",
	:naturePower => :TRICKROOM,
	:mimicry => :NORMAL,
	:damageMods => {
	},
	:accuracyMods => {},
	:moveMessages => {
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		# Type change to Normal + Normalize effect hardcoded in 010 (via on_seed_use hook)
		:message => "{1} was normalized! Its type became Normal!",
		:animation => :SHARPEN,
		:stats => {},
	},
},
:PSYTERRAIN => {
	:name => "Psychic Terrain",
	:fieldMessage => [
		"The field became mysterious!"
	],
	:graphic => ["Psychic","Psychic_2"],
	:secretPower => "PSYCHIC",
	:naturePower => :PSYCHIC,
	:mimicry => :PSYCHIC,
	:damageMods => {
		1.5 => [:SECRETPOWER, :HIDDENPOWER, :HEX, :MAGICALLEAF, :MYSTICALFIRE, :MOONBLAST, :AURASPHERE, :FOCUSBLAST, :MINDBLOWN, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
	},
	:accuracyMods => {
		90 => [:HYPNOSIS],
	},
	:moveMessages => {
		"The psychic energy strengthened the attack!" => [:SECRETPOWER, :HIDDENPOWER, :HEX, :MAGICALLEAF, :MYSTICALFIRE, :MOONBLAST, :AURASPHERE, :FOCUSBLAST, :MINDBLOWN, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:PSYCHIC],
	},
	:typeMessages => {
		"The Psychic Terrain strengthened the attack!" => [:PSYCHIC],
	},
	:typeCondition => {
		:PSYCHIC => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [:CALMMIND, :COSMICPOWER, :KINESIS, :MEDITATE, :NASTYPLOT, :HYPNOSIS, :PSYCHUP, :MINDREADER, :MIRACLEEYE, :TELEKINESIS, :GRAVITY, :MAGICROOM, :TRICKROOM, :WONDERROOM],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} became confused!",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 2,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:SECRETPOWER, :HIDDENPOWER, :MYSTICALFIRE,:MAGICALLEAF,:AURASPHERE,:FOCUSBLAST,:HEX,:MOONBLAST,:MINDBLOWN],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The psychic energy strengthened the attack!" => [:SECRETPOWER, :HIDDENPOWER, :MYSTICALFIRE,:MAGICALLEAF,:AURASPHERE,:HEX,:MOONBLAST,:MINDBLOWN],
		},
		:typeBoosts => {
			1.5 => [:PSYCHIC],
		},
		:typeMessages => {
			"The Psychic Terrain strengthened the attack!" => [:PSYCHIC],
		},
		:typeCondition => {	
			:PSYCHIC => "!attacker.isAirborne?",
		},
		:statusMods => [],
	},
},
:DIMENSIONAL => {
	:name => "Dimensional Field",
	:fieldMessage => [
		"Darkness Radiates."
	],
	:graphic => ["Dimensional"],
	:secretPower => "SHADOWBALL",  # Flinch effect (effect 11 in parser)
	:naturePower => :DARKPULSE,
	:mimicry => :DARK,
	:damageMods => {
		1.5 => [:HYPERSPACEFURY, :HYPERSPACEHOLE, :SPACIALREND, :ROAROFTIME, :ETERNABEAM, :DYNAMAXCANNON, :SHADOWFORCE, :OUTRAGE, :THRASH, :STOMPINGTANTRUM, :LASHOUT, :FREEZINGGLARE, :FIREYWRATH, :RAGINGFURY],
		1.2 => [:DARKPULSE, :NIGHTDAZE],
		0 => [:HAIL, :SUNNYDAY, :SANDSTORM, :RAINDANCE, :TEATIME, :LUCKYCHANT],
	},
	:accuracyMods => {
		0 => [:DARKVOID, :DARKPULSE, :NIGHTDAZE],
	},
	:moveMessages => {
		"The attack has been corrupted." => [:HYPERSPACEFURY, :HYPERSPACEHOLE, :SPACIALREND, :ROAROFTIME, :ETERNABEAM, :DYNAMAXCANNON, :SHADOWFORCE, :DARKPULSE, :NIGHTDAZE],
		"The rage continues." => [:OUTRAGE, :THRASH, :STOMPINGTANTRUM, :LASHOUT, :FREEZINGGLARE, :FIREYWRATH, :RAGINGFURY],
		"But it failed." => [:TEATIME, :LUCKYCHANT],
		"The dark dimension swallowed the sand." => [:SANDSTORM],
		"The dark dimension swallowed the rain." => [:RAINDANCE],
		"The dark dimension swallowed the hail." => [:HAIL],
		"The sunlight cannot pierce the darkness." => [:SUNNYDAY],
	},
	:typeMods => {
	},
	:typeAddOns => {
	},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:BLIZZARD, :SHEERCOLD, :COLDTRUTH],
		"@battle.field_counters.counter = 2" => [:ICEBURN, :FREEZESHOCK, :GLACIATE],
	},
	:typeBoosts => {
		1.5 => [:DARK, :SHADOW],
		1.2 => [:GHOST],
		0.5 => [:FAIRY],
	},
	:typeMessages => {
		"The darkness is here..." => [:DARK],
		"The shadow is strengthened..." => [:SHADOW],
		"The evil aura powered up the attack..." => [:GHOST],
		"The evil aura depleted the attack!" => [:FAIRY],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
		:FROZENDIMENSION => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:FROZENDIMENSION => [:BLIZZARD, :SHEERCOLD, :ICEBURN, :FREEZESHOCK, :GLACIATE],
		:INFERNAL => [:PRECIPICEBLADES],
		:INDOOR => [:PURIFY, :SEEDFLARE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The dimension froze up!" => [:BLIZZARD, :SHEERCOLD, :ICEBURN, :FREEZESHOCK, :GLACIATE],
		 "The field went up in flames!" => [:PRECIPICEBLADES],
		 "The dimension was purified!" => [:PURIFY, :SEEDFLARE],
	},
	:statusMods => [:OBSTRUCT, :QUASH, :EMBARGO, :HEALBLOCK, :DARKVOID],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		# Trick Room effect is battle-wide; hardcoded in 010 via apply_field_effect hook
		:message => "The Magical Seed raised {1}'s Defense! The dimensions warped!",
		:animation => :TRICKROOM,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:FROZENDIMENSION => {
	:name => "Frozen Dimensional Field",
	:fieldMessage => [
		"Hate and anger radiates."
	],
	:graphic => ["FrozenDimensional"],
	:secretPower => "BLIZZARD",
	:naturePower => :ICEBEAM,
	:mimicry => :ICE,
	:noCharging => [:ICEBURN, :FREEZESHOCK],
	:noChargingMessages => {
		:ICEBURN => "The frozen dimension accelerated the attack!",
		:FREEZESHOCK => "The frozen dimension accelerated the attack!",
	},
	:damageMods => {
		1.5 => [:RAGINGFURY, :OUTRAGE, :THRASH, :LASHOUT, :FREEZINGGLARE, :ROAROFTIME, :FIERYWRATH, :RAGE, :STOMPINGTANTRUM],
		1.2 => [:HYPERSPACEFURY, :HYPERSPACEHOLE, :SURF, :MUDDYWATER, :WATERPULSE, :HYDROPUMP, :NIGHTSLASH, :DARKPULSE],
		0   => [:TEATIME, :COURTCHANGE],
	},
	:accuracyMods => {
		100 => [:DARKVOID],
	},
	:moveMessages => {
		"The cold fury raged on!" => [:RAGINGFURY, :OUTRAGE, :THRASH, :LASHOUT, :STOMPINGTANTRUM],
		"Time itself froze in place!" => [:ROAROFTIME],
		"A glacial hatred was unleashed!" => [:FREEZINGGLARE, :FIERYWRATH, :RAGE],
		"The dimensional rift enhanced the attack!" => [:HYPERSPACEFURY, :HYPERSPACEHOLE],
		"The frozen waters surged with power!" => [:SURF, :MUDDYWATER, :WATERPULSE, :HYDROPUMP],
		"The frozen darkness cut deep!" => [:NIGHTSLASH, :DARKPULSE],
		"The dark void found its mark!" => [:DARKVOID],
		"But it failed..." => [:TEATIME, :COURTCHANGE],
	},
	:typeMods => {
		:ICE => [:SURF, :MUDDYWATER, :WATERPULSE, :HYDROPUMP, :NIGHTSLASH, :DARKPULSE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:DARK],
		1.2 => [:ICE],
	},
	:typeMessages => {
		"The frozen hatred boosted the dark attack!" => [:DARK],
		"The frozen dimension boosted the ice attack!" => [:ICE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:DIMENSIONAL => [:BLASTBURN, :INFERNO, :LAVAPLUME, :HEATWAVE, :ERUPTION, :FLAMEBURST, :BURNUP, :RAGINGFURY],
		:ICY         => [:PURIFY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The flames melted through the frost!" => [:BLASTBURN, :INFERNO, :LAVAPLUME, :HEATWAVE, :ERUPTION, :FLAMEBURST, :BURNUP, :RAGINGFURY],
		"The dimension was purified!" => [:PURIFY],
	},
	# Snow Warning / Hail lasts 8 turns per the manual
	:weatherDuration => {
		:Hail => 8, :Snow => 8,
	},
	# statusMods flags moves with special field effects for highlighting/custom logic:
	# SNARL lowers SpAtk by 2 stages, PARTINGSHOT additionally lowers Speed,
	# AURORAVEIL works without Hail, RAGE becomes 60bp Dark-type always raises Atk,
	# DRAGONRAGE deals 140 flat damage, POWERTRIP gains 40bp per boost (not 20bp)
	:statusMods => [:SNARL, :PARTINGSHOT, :AURORAVEIL, :RAGE, :DRAGONRAGE, :POWERTRIP],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => nil,
		:duration => nil,
		# Full effect: +2 Speed + confuse + taunt + torment — secondary effects need custom implementation
		:message => "{1} was sped up and overwhelmed by the frozen dimension!",
		:animation => nil,
		:stats => {
			:SPEED => 2,
		},
	},
},
:HAUNTED => {
	:name => "Haunted Field",
	:fieldMessage => [
		"The field is haunted!"
	],
	:graphic => ["Haunted"],
	:secretPower => "SHADOWCLAW",
	:naturePower => :PHANTOMFORCE,
	:mimicry => :GHOST,
	# Abilities activated/modified on Haunted Field (Section 25)
	:abilityActivate => {
		:PERISHBODY  => { traps_opponent: true },
		:CURSEDBODY  => { always_activates_faint: true },
		:WANDERINGSPIRIT => { speed_loss_eor: true },
		:SHADOWTAG   => { frisks_on_entry: true },
		:RATTLED     => { speed_boost_entry: true },
		:POWERSPOT   => {},
	},
	# Ability mods
	:abilityMods => {
		:POWERSPOT => { multiplier: 1.5 },
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:SCARYFACE => { stages: 4, message: "The haunted atmosphere made it terrifying! {1}'s Speed harshly fell!" },
		:BITTERMALICE => { additional_stats: { :SPECIAL_ATTACK => -1 } },
		:OMINOUSWIND => { stat_boost_chance: 20 },  # 20% to boost all stats
		:MAGICPOWDER => { status_effect: :sleep },
		:LICK => { paralyze_chance: 100 },
		:NIGHTSHADE => { damage_multiplier: 1.5 },
		:CURSE => { ghost_hp_cost: 0.25 },  # 25% HP for Ghost-types
		:SPITE => { pp_reduction: 4 },  # -4 PP total (base -2, +2 more)
		:DESTINYBOND => { never_fails: true },
	},
	# No charging moves (Phantom Force, Shadow Force become 1-turn)
	:noCharging => [:PHANTOMFORCE, :SHADOWFORCE],
	:noChargingMessages => {
		:PHANTOMFORCE => "The spirits guided the strike instantly!",
		:SHADOWFORCE => "The shadows struck immediately!",
	},
	:damageMods => {
		1.5 => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN, :BONECLUB, :BONERUSH, :BONEMERANG, :ASTONISH],
		1.2 => [:SHADOWBONE],
	},
	:accuracyMods => {
		90 => [:WILLOWISP, :HYPNOSIS],
	},
	:moveMessages => {
		"Will-o'-wisps joined the attack!" => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN],
		"Spooky scary skeletons!" => [:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE],	
		"Boo!" => [:ASTONISH],
	},
	:typeMods => {
		:GHOST => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN],
	},
	:typeAddOns => {
	},
	:moveEffects => {
		"target_both_opponents" => [:MEANLOOK, :FIRESPIN],
		"fire_spin_damage_boost" => [:FIRESPIN],  # 1/6 instead of 1/8
		"spirit_break_se_ghost" => [:SPIRITBREAK],
	},
	:typeBoosts => {
		1.5 => [:GHOST],
	},
	:typeMessages => {
		"The evil aura powered up the attack!" => [:GHOST],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:HOLY => [:JUDGEMENT, :ORIGINPULSE, :SACREDFIRE, :PURIFY],
		:INDOOR => [:FLASH, :DAZZLINGGLEAM],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The evil spirits have been exorcised!" => [:JUDGEMENT, :ORIGINPULSE, :PURIFY, :SACREDFIRE],
		 "The evil spirits have been forced back!" => [:FLASH, :DAZZLINGGLEAM],
	},
	:statusMods => [:NIGHTMARE, :SPITE, :CURSE, :DESTINYBOND, :MEANLOOK, :SCARYFACE, :MAGICPOWDER, :HYPNOSIS, :WILLOWISP, :INFERNALPARADE, :OMINOUSWIND, :BITTERMALICE, :LICK, :NIGHTSHADE],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Burn,
		:duration => 1,
		:message => "{1} was burned!",
		:animation => :WILLOWISP,
		:stats => {
			:SPECIAL_DEFENSE => 1,
			:DEFENSE => 1,
		},
	},
},
:CORRUPTED => {
	:name => "Corrupted Cave",
	:fieldMessage => [
		"Corruption seeps from every crevice!"
	],
	:graphic => ["Corrupted"],
	:secretPower => "POISONJAB",
	:naturePower => :GUNKSHOT,
	:mimicry => :POISON,
	# Abilities (section 32)
	:abilityActivate => {
		:POISONHEAL  => {},
		:POISONTOUCH => { doubled_rate: true },
		:POISONPOINT => { doubled_rate: true },
		:CORROSION   => { damage_boost: 1.5 },
		:TOXICBOOST  => { doubled_boost: true },  # 100% instead of 50%
		:GRASSPELT   => { eor_damage: true },
		:LEAFGUARD   => { eor_damage: true },
		:FLOWERVEIL  => { eor_damage: true },
		:DRYSKIN     => {},  # Special handling in hardcode
		:LIQUIDOOZE  => { doubled_damage: true },
	},
	# Move modifications
	:moveStatStageMods => {
		:TARSHOT => { additional_effect: :poison },
		:TOXICTHREAD => { badly_poison: true },
	},
	:damageMods => {
		1.5 => [:SEEDFLARE, :APPLEACID],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The move absorbed the filth!" => [:SEEDFLARE],
	},
	:typeMods => {
		:POISON => [:ROCKSLIDE, :SMACKDOWN, :STONEEDGE, :ROCKTOMB, :DIAMONDSTORM, :APPLEACID],
		:ROCK => [:SLUDGEWAVE, :GUNKSHOT],
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:POISON],
		1.2 => [:ROCK, :GRASS],
		0.5 => [:FAIRY, :FLYING],
	},
	:typeMessages => {
		"The chemicals strengthened the attack." => [:POISON],
		"The corruption morphed the attack!" => [:ROCK, :GRASS],
		"The corruption weakened the attack." => [:FAIRY],
		"The cave choked out the air!" => [:FLYING],
	},
	:typeCondition => {
		:FLYING => "!self.contactMove?",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:CAVE => [:SOLARBEAM, :SOLARBLADE, :PURIFY, :SEEDFLARE],
		:VOLCANIC => [:HEATWAVE, :ERUPTION, :LAVAPLUME, :BLASTBURN, :INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The cave was purified!" => [:SOLARBEAM, :SOLARBLADE, :PURIFY, :SEEDFLARE],
	},
	:statusMods => [:NIGHTMARE, :SPITE, :CURSE, :DESTINYBOND, :MEANLOOK, :SCARYFACE, :MAGICPOWDER, :HYPNOSIS, :WILLOWISP, :INGRAIN, :STEALTHROCK],
	:changeEffects => {
		"@battle.mistExplosion" => [:HEATWAVE, :ERUPTION, :LAVAPLUME, :BLASTBURN, :INFERNOOVERDRIVE],
	},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :BadlyPoison,
		:duration => 1,
		:message => "{1} was badly poisoned!",
		:animation => :TOXIC,
		:stats => {
			:DEFENSE => 2,
		},
	},
},
:SKY => {
	:name => "Sky Field",
	:fieldMessage => [
		"The sky is filled with clouds. "
	],
	:graphic => ["GoldenArena"],
	# Secret Power causes Confusion on Sky Field (override in 010 via EffectDependsOnEnvironment).
	# Parser has no confuse effect — using AIRSLASH placeholder (effect 12) so base move works;
	# the confuse application is injected in 010.
	:secretPower => "AIRSLASH",
	:naturePower => :SKYATTACK,
	:mimicry => :FLYING,
	:noCharging => [:RAZORWIND, :SKYATTACK, :BOUNCE, :FLY],
	:noChargingMessages => {
		:RAZORWIND => "The open skies let the razor winds loose instantly!",
		:SKYATTACK => "The heavens answered the call immediately!",
		:BOUNCE    => "The sky currents carry the leap instantly!",
		:FLY       => "The updrafts launch the attack without delay!",
	},
	:damageMods => {
		1.5 => [:ICYWIND, :SILVERWIND, :OMINOUSWIND, :FAIRYWIND, :AEROBLAST, :FLYINGPRESS, :SKYUPPERCUT, :THUNDERSHOCK, :THUNDERBOLT, :STEELWING, :DRAGONDARTS, :GRAVAPPLE, :DRAGONASCENT, :THUNDER, :TWISTER, :RAZORWIND, :DIVE, :ESPERWING, :BLEAKWINDSTORM],
		1.3 => [:SPRINGTIDESTORM, :WINDBOLTSTORM, :SANDSEARSTORM],
		0 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE, :DIG, :ROTOTILLER, :SPIKES, :TOXICSPIKES, :STICKYWEB]
	},
	:accuracyMods => {
		0 => [:THUNDER, :HURRICANE]
	},
	:moveMessages => {
		"The open skies strengthened the attack!" => [:ICYWIND, :SILVERWIND, :OMINOUSWIND, :FAIRYWIND, :AEROBLAST, :FLYINGPRESS, :SKYUPPERCUT, :THUNDERSHOCK, :THUNDERBOLT, :STEELWING, :DRAGONDARTS, :GRAVAPPLE, :DRAGONASCENT, :THUNDER, :TWISTER, :RAZORWIND, :DIVE, :ESPERWING, :SPRINGTIDESTORM, :WINDBOLTSTORM, :SANDSEARSTORM, :BLEAKWINDSTORM],
		"But there is no solid ground!" => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE, :DIG, :ROTOTILLER, :SPIKES, :TOXICSPIKES, :STICKYWEB]
	},
	:typeMods => {
		:FLYING => [:DIVE, :TWISTER],
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FLYING],
	},
	:typeMessages => {
		"The open air strengthened the attack!" => [:FLYING],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:MOUNTAIN => [:GRAVITY, :INGRAIN, :THOUSANDARROWS, :SMACKDOWN, :GRAVAPPLE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle has been brought down to the mountains!" => [:GRAVITY, :INGRAIN, :THOUSANDARROWS, :SMACKDOWN, :GRAVAPPLE],
	},
	# All weather lasts 8 turns per the manual; Tailwind duration handled by :tailwindDuration key
	:weatherDuration => {
		:Sun => 8, :HarshSun => 8, :Rain => 8, :HeavyRain => 8,
		:Sandstorm => 8, :Hail => 8, :Snow => 8, :StrongWinds => 8,
	},
	:tailwindDuration => 4,  # Base 4 turns; field extends to 8 via tailwind_duration key (003_Field_base_and_keys)
	:statusMods => [:MIRRORMOVE, :TAILWIND, :SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:COLOSSEUM => {
	:name => "Colosseum",
	:fieldMessage => [
		"All eyes are on the combatants!"
	],
	:graphic => ["Colosseum"],
	:secretPower => "POWERUPPUNCH",  # Overridden in 010 to raise user Attack
	:naturePower => :BEATUP,
	:mimicry => :STEEL,
	:damageMods => {
		2.0 => [:BEATUP, :FELLSTINGER, :PAYDAY, :REVERSAL, :PURSUIT],
		1.5 => [:SACREDSWORD, :SECRETSWORD, :SUBMISSION, :METEORASSAULT, :SMARTSTRIKE, :SMACKDOWN, :BRUTALSWING, :ELECTROWEB, :VINEWHIP, :PSYCHOCUT, :NIGHTSLASH, :BONEMERANG, :FIRSTIMPRESSION, :BONERUSH, :BONECLUB, :LEAFBLADE, :PAYBACK, :PUNISHMENT, :METEORMASH, :BULLETPUNCH, :CLANGINGSCALES, :STEAMROLLER],
		1.2 => [:STORMTHROW, :WOODHAMMER, :DRAGONHAMMER, :POWERWHIP, :SPIRITSHACKLE, :DRILLRUN, :DRILLPECK, :ICEHAMMER, :ICICLESPEAR, :ANCHORSHOT, :CRABHAMMER, :SHADOWBONE, :FIRELASH, :SUCKERPUNCH, :THROATCHOP],
		0 => [:BATONPASS, :ENCORE, :WHIRLWIND],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The fighters rallied together!" => [:BEATUP],
		"The coup de grâce!" => [:FELLSTINGER],
		"The audience hurled coins down!" => [:PAYDAY],
		"There is no escape!" => [:PURSUIT],
		"For Honor!" => [:REVERSAL, :SACREDSWORD, :SECRETSWORD, :SUBMISSION, :METEORASSAULT, :SMARTSTRIKE, :SMACKDOWN, :BRUTALSWING, :STORMTHROW],
		"For Glory!" => [:ELECTROWEB, :VINEWHIP, :PSYCHOCUT, :NIGHTSLASH, :BONEMERANG, :FIRSTIMPRESSION, :BONERUSH, :BONECLUB, :LEAFBLADE, :PAYBACK, :PUNISHMENT, :METEORMASH, :BULLETPUNCH, :CLANGINGSCALES, :STEAMROLLER, :WOODHAMMER, :DRAGONHAMMER, :POWERWHIP, :SPIRITSHACKLE, :DRILLRUN, :DRILLPECK, :ICEHAMMER, :ICICLESPEAR, :ANCHORSHOT, :CRABHAMMER, :SHADOWBONE, :FIRELASH, :SUCKERPUNCH, :THROATCHOP],
		"There can be no retreat!" => [:BATONPASS],
		"{1} stands their ground in the arena!!" => [:WHIRLWIND],
		"The audience demands fighting not repetition!" => [:ENCORE],
	},
	:typeMods => {
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:moveStatStageMods => {
		:SWORDSDANCE => { stages: 4 },
		:HOWL        => { stages: 2 },
	},
	:statusMods => [:SWORDSDANCE, :KINGSSHIELD, :HOWL, :NORETREAT, :ROAR, :SWAGGER, :FLATTER],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Taunt,
		:duration => 4,
		:message => "{1} feels taunted!",
		:animation => :TAUNT,
		:stats => {
			:ATTACK => 2,
		},
	},
},
:MIRRORARENA => {
	:name => "Mirror Arena",
	:fieldMessage => [
		"Mirrors are layed around the field!"
	],
	:graphic => ["MirrorArena"],
	:secretPower => "FLASHCANNON",  # Custom: lower Evasion — overridden in 010
	:naturePower => :MIRRORSHOT,
	:mimicry => :STEEL,
	:damageMods => {
		2.0 => [:MIRRORSHOT],
		1.5 => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DOOMDESY,
		        :DAZZLINGGLEAM, :TECHNOBLAST, :PRISMATICLASER, :PHOTONGEYSER],
	},
	:accuracyMods => {
		1000 => [:MIRRORSHOT, :AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE,
		         :DAZZLINGGLEAM, :TECHNOBLAST, :PRISMATICLASER, :PHOTONGEYSER],
	},
	:moveMessages => {
		"The mirrors strengthened the attack!" => [:MIRRORSHOT],
		"The reflected light was blinding!" => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON,
			:LUSTERPURGE, :DAZZLINGGLEAM, :TECHNOBLAST, :PRISMATICLASER, :PHOTONGEYSER],
		"The mirror arena shattered!" => [:EARTHQUAKE, :BULLDOZE, :BOOMBURST, :HYPERVOICE, :MAGNITUDE, :TECTONICRAGE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.pbChangeField(:INDOOR)" => [:EARTHQUAKE, :BULLDOZE, :BOOMBURST, :HYPERVOICE, :MAGNITUDE, :TECTONICRAGE],
	},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:EARTHQUAKE, :BULLDOZE, :BOOMBURST, :HYPERVOICE, :MAGNITUDE, :TECTONICRAGE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The mirrors shattered!" => [:EARTHQUAKE, :BULLDOZE, :BOOMBURST, :HYPERVOICE, :MAGNITUDE, :TECTONICRAGE],
	},
	:moveStatStageMods => {
		:FLASH      => { stages: 2 },
		:DOUBLETEAM => { stages: 2 },
	},
	:statusMods => [:FLASH, :DOUBLETEAM, :MIRRORCOAT, :MIRRORMOVE, :LIGHTSCREEN, :REFLECT, :AURORAVEIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1}'s Evasion rose sharply!",
		:animation => :DOUBLETEAM,
		:stats => {},
		:evasion => 2,
	},
},
:INFERNAL => {
	:name => "Infernal Field",
	:fieldMessage => [
		"The souls of the damned burn on."
	],
	:graphic => ["Infernal"],
	# "FLAMETHROWER" maps to effect 10 (Burn) in parse_secret_power -- correct per manual
	:secretPower => "FLAMETHROWER",
	:naturePower => :PUNISHMENT,
	:mimicry => :FIRE,
	:damageMods => {
		2.0 => [:PUNISHMENT, :SMOG, :DREAMEATER],
		1.5 => [:BLASTBURN, :EARTHPOWER, :INFERNOOVERDRIVE, :PRECIPICEBLADES, :INFERNO, :RAGINGFURY, :INFERNALPARADE],
		0  => [:RAINDANCE, :HAIL],
	},
	:accuracyMods => {
		0 => [:WILLOWISP, :DARKVOID, :INFERNO],
	},
	:moveMessages => {
		"Hellish Suffering!" => [:PUNISHMENT, :SMOG, :DREAMEATER],
		"Infernal flames strengthened the attack!" => [:BLASTBURN, :EARTHPOWER, :INFERNOOVERDRIVE, :PRECIPICEBLADES, :INFERNO, :RAGINGFURY, :INFERNALPARADE],
		"The hail melted away." => [:HAIL],
		"The rain evaporated." => [:RAINDANCE],
	},
	:typeMods => {
		:DARK => [:SPIRITBREAK, :AURASPHERE, :FRUSTRATION],
	},
	:typeAddOns => {
		:FIRE => [:GROUND, :STEEL, :ROCK],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE, :DARK],
		0.5 => [:FAIRY, :WATER],
	},
	:typeMessages => {
		"The infernal flames strengthened the attack!" => [:FIRE, :DARK],
		"The hellfire burnt out the attack!" => [:FAIRY, :WATER],
	},
	:typeCondition => {
		# Spirit Break is explicitly excluded from the FAIRY nerf per the manual
		:FAIRY => "move.id != :SPIRITBREAK",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:FROZENDIMENSION => [:GLACIATE],
		:VOLCANICTOP => [:JUDGEMENT, :ORIGINPULSE, :PURIFY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The frozen hellscape transcends dimensions!" => [:GLACIATE],
		 "The hellish landscape was purified!" => [:JUDGEMENT, :ORIGINPULSE, :PURIFY],
	},
	# NASTYPLOT: stat-change amplified; TORMENT/NIGHTMARE: custom passive effects;
	# STEALTHROCK: Fire-type damage; WILLOWISP/DARKVOID/INFERNO: never miss (also in accuracyMods)
	:statusMods => [:WILLOWISP, :DARKVOID, :TORMENT, :NIGHTMARE, :STEALTHROCK, :NASTYPLOT],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1} can't escape now!",
		:animation => :MEANLOOK,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:DEEPEARTH => {
	:name => "Deep Earth",
	:fieldMessage => [
		"The core is pulling you in...",
	],
	:graphic => ["DeepEarth","Zeight","Zeight2","Zeight3","Zeight4"],
	:secretPower => "ROCKSLIDE",  # 7 = Flinch
	:naturePower => :GRAVITY,
	:mimicry => :GROUND,
	:damageMods => {
		2.0 => [:LANDSWRATH, :PRECIPICEBLADES, :MAGNETBOMB, :TECTONICRAGE, :CRUSHGRIP, :SMACKDOWN, :COREENFORCER],
		1.5 => [:HEAVYSLAM,	:HEATCRASH, :BODYSLAM, :STOMP, :DRAGONRUSH, :STEAMROLLER, :GRAVAPPLE, :ANCIENTPOWER, :FLING, :GRASSKNOT, :LOWKICK, :SPACIALREND, :STORMTHROW, :CIRCLETHROW, :VITALTHROW, :BODYPRESS, :SUBMISSION, :ICEHAMMER, :HAMMERARM, :CRABHAMMER, :ICICLECRASH, :THOUSANDARROWS, :THOUSANDWAVES],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The attack came crashing down!" => [:HEAVYSLAM, :HEATCRASH, :BODYSLAM, :STOMP, :DRAGONRUSH, :STEAMROLLER, :GRAVAPPLE, :BODYPRESS, :ICICLECRASH, :FLING],
		"Enjoy the trip!" => [:GRASSKNOT, :LOWKICK],
		"{1} threw their whole weight into it!" => [:ICEHAMMER, :HAMMERARM, :CRABHAMMER],
		"Slammed into the ground!" => [:STORMTHROW, :CIRCLETHROW, :VITALTHROW, :SUBMISSION, :SMACKDOWN],
		"CRUSHED!" => [:CRUSHGRIP],
		"The magnetic field is strengthened!" => [:MAGNETBOMB],
		"The power of the earth is utterly overwhelming!"  => [:THOUSANDARROWS, :THOUSANDWAVES, :LANDSWRATH, :PRECIPICEBLADES, :TECTONICRAGE],
		"The power of ages gone by..." => [:ANCIENTPOWER],
		"The power of the core obliterates all!" => [:COREENFORCER],
		"The intense gravity is ruptured!" => [:SPACIALREND],
	},
	:typeMods => {},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:ROCK, :PSYCHIC],
		1.5 => [:GROUND],
	},
	:typeMessages => {
		"The core's magical forces are immense!" => [:PSYCHIC],
		"The earth empowered the attack!" => [:ROCK, :GROUND],
	},
	:typeCondition => {
		:GROUND => "!opponent.pbHasType?(:GROUND)",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:moveStatStageMods => {
		:AUTOTOMIZE   => { stages: 2 },
		:ROTOTILLER   => { stages: 2 },
		:MAGNETFLUX   => { stages: 2 },
		:EERIEIMPULSE => { stages: 2 },
	},
	:statusMods => [:AUTOTOMIZE, :GEOMANCY, :ROTOTILLER, :MAGNETFLUX, :EERIEIMPULSE, :MAGNETRISE, :GRAVITY, :TOPSYTURVY, :SEISMICTOSS, :PSYWAVE],
	:noCharging => [:GEOMANCY],
	:noChargingMessages => {
		"The gravity compressed the charging time!" => [:GEOMANCY],
	},
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1}'s weight increased!",
		:animation => :QUASH,
		:stats => {
			:DEFENSE => 1,
		}
	},
},
:BACKALLEY => {
	:name => "Backalley",
	:fieldMessage => [
		"Shifty eyes are all around..."
	],
	:graphic => ["Under"],
	:secretPower => "SMOG",
	:naturePower => :BEATUP,
	:mimicry => :STEEL,
	# Passive healing reduction
	:healingReduction => 0.67,  # 33% reduction (multiply by 0.67)
	# Abilities activated/modified on Back Alley Field
	:abilityActivate => {
		:PICKPOCKET   => {},  # Attack +1 on switch-in (hardcoded section 30)
		:MERCILESS    => {},  # Attack +1 on switch-in (hardcoded section 30)
		:MAGICIAN     => {},  # Sp.Atk +1 on switch-in (hardcoded section 30)
		:ANTICIPATION => {},  # Def/SpDef +1 on switch-in (hardcoded section 30)
		:FOREWARN     => {},  # Def/SpDef +1 on switch-in (hardcoded section 30)
		:RATTLED      => {},  # Speed +1 on switch-in (hardcoded section 30)
		:FRISK        => {},  # Steals item if user has none (hardcoded section 30)
	},
	# Ability modifications
	:abilityMods => {
		:DEFIANT     => { stages_bonus: 1 },  # Raises Attack by extra stage
		:STENCH      => { activation_double: true },  # Doubled activation rate
		:HUSTLE      => { accuracy_reduction: 0.67, attack_boost: 1.75 },  # Same as City
		:DOWNLOAD    => { boost_double: true },  # Doubled boost
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:SMOKESCREEN => { stages: 2, message: "The smoke fills the alley!" },
		:NASTYPLOT   => { stages: 4, message: "A devious plan!" },
		:SNARL       => { stages: 2, message: "An intimidating snarl!" },
		:PARTINGSHOT => { stats_override: { :ATTACK => -2, :SPECIAL_ATTACK => -2 } },
		:FAKETEARS   => { stages: 3, message: "Crocodile tears!" },
		:PURSUIT     => { speed_boost_on_ko: true },
		:TRICK       => { stat_swap_effect: true },
		:SWITCHEROO  => { stat_swap_effect: true },
		:SNATCH      => { random_stat_boost_2: true },
		:CORROSIVEGAS => { additional_effect: :lower_all_stats },
	},
	:damageMods => {
		1.5 => [:STEAMROLLER, :SMOG, :BEATUP, :PAYDAY, :INFESTATION, :SPECTRALTHIEF, :FIRSTIMPRESSION, :TECHNOBLAST, :SHADOWSNEAK,
			:XSCISSOR, :FURYCUTTER, :NIGHTSLASH, :SACREDSWORD, :AIRSLASH, :AERIALACE, :AIRCUTTER, :LEAFBLADE, :RAZORLEAF, :SLASH, :CUT, :CROSSPOISON, :PSYCHOCUT, :RAZORSHELL, :SOLARBLADE, :BEHEMOTHBLADE, :CEASELESSEDGE, :STONEAXE, :AQUACUTTER,
			:HORNATTACK, :FURYATTACK, :POISONSTING, :TWINEEDLE, :PINMISSILE, :PECK, :DRILLPECK, :MEGAHORN, :POISONJAB, :NEEDLEARM, :PLUCK, :DRILLRUN, :HORNLEECH, :FELLSTINGER, :SMARTSTRIKE, :BRANCHPOKE, :FALSESURRENDER, :GLACIALLANCE],
	},
	:accuracyMods => {
		0 => [:SMOG, :POISONGAS],
	},
	:moveMessages => {
		"The power of science is amazing!" => [:TECHNOBLAST],
		"A crowd is gathering!" => [:BEATUP],
		"The city smog is suffocating!" => [:SMOG],
		"Careful on the street!" => [:STEAMROLLER],
		"Gotta make ends meet somehow..." => [:PAYDAY, :SPECTRALTHIEF, :SHADOWSNEAK],
		"A frightening first impression!" => [:FIRSTIMPRESSION],
		"A knife glints in the dark!" => [:XSCISSOR, :FURYCUTTER, :NIGHTSLASH, :SACREDSWORD, :AIRSLASH, :AERIALACE, :AIRCUTTER, :LEAFBLADE, :RAZORLEAF, :SLASH, :CUT, :CROSSPOISON, :PSYCHOCUT, :RAZORSHELL, :SOLARBLADE, :BEHEMOTHBLADE, :CEASELESSEDGE, :STONEAXE, :AQUACUTTER],
		"Better watch your back..." => [:HORNATTACK, :FURYATTACK, :POISONSTING, :TWINEEDLE, :PINMISSILE, :PECK, :DRILLPECK, :MEGAHORN, :POISONJAB, :NEEDLEARM, :PLUCK, :DRILLRUN, :HORNLEECH, :FELLSTINGER, :SMARTSTRIKE, :BRANCHPOKE, :FALSESURRENDER, :GLACIALLANCE],
	},
	:typeMods => {
		:DARK => [:FIRSTIMPRESSION],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:DARK],
		1.3 => [:POISON, :BUG, :STEEL],
		0.5 => [:FAIRY],
	},
	:typeMessages => {
		"Street rules!" => [:DARK],
		"The right tool for the job!" => [:STEEL],
		"In the cracks and the walls!" => [:BUG],
		"All kinds of pollution strengthened the attack!" => [:POISON],
		"This is no place for fairytales..." => [:FAIRY],
	},
	:typeCondition => {
		:DARK => "self.physicalMove?(@type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:CITY => [:UPROAR,:HYPERVOICE,:ECHOEDVOICE,:BOOMBURST],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"Cops! Everyone scatter!" => [:UPROAR,:HYPERVOICE,:ECHOEDVOICE,:BOOMBURST],
	},
	:statusMods => [:SMOKESCREEN, :NASTYPLOT, :PARTINGSHOT, :FAKETEARS, :POISONGAS, :SMOG, :TRICK, :SWITCHEROO, :CORROSIVEGAS, :SNATCH],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:ACCURACY => 1,
		},
	},
},
:CITY => {
	:name => "City",
	:fieldMessage => [
		"The streets are busy..."
	],
	:graphic => ["City"],
	:secretPower => "SMOG",
	:naturePower => :SMOG,
	:mimicry => :NORMAL,
	# Abilities activated/modified on City Field
	:abilityActivate => {
		:EARLYBIRD => {},  # Attack +1 on switch-in (hardcoded section 29)
		:PICKUP    => {},  # Speed +1 on switch-in (hardcoded section 29)
		:BIGPECKS  => {},  # Defense +1 on switch-in (hardcoded section 29)
		:RATTLED   => {},  # Speed +1 on switch-in (hardcoded section 29)
		:FRISK     => {},  # Lower opponent Sp.Def (hardcoded section 29)
	},
	# Ability modifications
	:abilityMods => {
		:COMPETITIVE => { stages_bonus: 1 },  # Raises Sp.Atk by extra stage
		:STENCH      => { activation_double: true },  # Doubled activation rate
		:HUSTLE      => { accuracy_reduction: 0.67, attack_boost: 1.75 },  # Custom effect
		:DOWNLOAD    => { boost_double: true },  # Doubled boost
	},
	# Move stat stage modifiers
	:moveStatStageMods => {
		:SMOKESCREEN => { stages: 2, message: "The city smog amplified Smokescreen!" },
		:WORKUP      => { stats_override: { :ATTACK => 2, :SPECIAL_ATTACK => 2 } },
		:AUTOTOMIZE  => { additional_stats: { :SPEED => 1 } },  # +3 Speed total
		:SHIFTGEAR   => { stats_override: { :SPEED => 3, :ATTACK => 2 } },
		:RECYCLE     => { random_stat_boost: true, message: "Recycle raised a random stat!" },
		:CORROSIVEGAS => { additional_effect: :lower_all_stats },
	},
	:damageMods => {
		1.5 => [:STEAMROLLER, :SMOG, :BEATUP, :PAYDAY, :FIRSTIMPRESSION, :TECHNOBLAST],
	},
	:accuracyMods => {
		0 => [:SMOG, :POISONGAS],
	},
	:moveMessages => {
		"The power of science is amazing!" => [:TECHNOBLAST],
		"A crowd is gathering!" => [:BEATUP],
		"The city smog is suffocating!" => [:SMOG],
		"Careful on the street!" => [:STEAMROLLER],
		"Working 9 to 5 for this!" => [:PAYDAY],
		"An overwhelming first impression!" => [:FIRSTIMPRESSION],
	},
	:typeMods => {
		:NORMAL => [:FIRSTIMPRESSION],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:NORMAL],
		1.3 => [:POISON, :BUG, :STEEL],
		0.7 => [:FAIRY],
	},
	:typeMessages => {
		"The hustle and bustle of the city!" => [:NORMAL],
		"The power of science is amazing!" => [:STEEL],
		"In the cracks and the walls!" => [:BUG],
		"All kinds of pollution strengthened the attack!" => [:POISON],
		"This is no place for fairytales..." => [:FAIRY],
	},
	:typeCondition => {
		:NORMAL => "self.physicalMove?(@type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:BACKALLEY => [:THIEF,:COVET,:PURSUIT],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The criminal ran into a backalley!" => [:THIEF,:COVET,:PURSUIT],
	},
	:statusMods => [:SMOKESCREEN, :WORKUP, :AUTOTOMIZE, :SHIFTGEAR, :POISONGAS, :SMOG, :RECYCLE, :CORROSIVEGAS],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:ACCURACY => 1,
		},
	},
},
:PSYCHIC => {
	:name => "Psychic Terrain",
	:fieldMessage => ["The field became mysterious!"],
	:graphic => ["PsychicTerrain"],
	:secretPower => "PSYCHIC",
	:naturePower => :PSYCHIC,
	:mimicry => :PSYCHIC,
	# Ability form changes
	:abilityFormChanges => {
		:ZENMODE => {
			:ZENMODE => { form: 1, show_ability: true, message: "{1} entered Zen Mode!" }
		}
	},
	# Abilities (Section 37)
	:abilityActivate => {
		:ANTICIPATION => {}, :FOREWARN => {}, :PUREPOWER => {}, :ZENMODE => {}, :TELEPATHY => {},
		:POWERSPOT => {}, :MAGICIAN => { status_accuracy: 50 },  # Status moves 50% accuracy
	},
	# Ability stat boosts on switch-in
	:abilityStatBoosts => {
		:ANTICIPATION => {
			stat: :SPECIAL_ATTACK,
			stages: 1,
			message: "{1}'s Anticipation boosted its Sp. Atk!"
		},
		:FOREWARN => {
			stat: :SPECIAL_ATTACK,
			stages: 1,
			message: "{1}'s Forewarn boosted its Sp. Atk!"
		},
	},
	# Ability mods
	:abilityMods => {
		:POWERSPOT => { multiplier: 1.5 },  # Increased from 1.3x
	},
	:moveStatStageMods => {
		:NASTYPLOT => { stats_override: { :SPECIAL_ATTACK => 4 } },
		:CALMMIND => { stats_override: { :SPECIAL_ATTACK => 2, :SPECIAL_DEFENSE => 2 } },
		:COSMICPOWER => { stats_override: { :DEFENSE => 2, :SPECIAL_DEFENSE => 2 } },
		:MEDITATE => { additional_stats: { :SPECIAL_ATTACK => 2 } },
		:KINESIS => { additional_stats: { :ATTACK => -2, :SPECIAL_ATTACK => -2 } },
		:TELEKINESIS => { additional_stats: { :DEFENSE => -2, :SPECIAL_DEFENSE => -2 } },
		:PSYCHUP => { additional_stats: { :SPECIAL_ATTACK => 2 } },
		:MINDREADER => { additional_stats: { :SPECIAL_ATTACK => 2 } },
		:MIRACLEEYE => { additional_stats: { :SPECIAL_ATTACK => 2 } },
		:PSYCHIELDBASH => { additional_stats: { :SPECIAL_DEFENSE => 1 } },
		:ESPERWING => { speed_double: true },  # Speed boost doubled
		:MYSTICALPOWER => { spatk_double: true },  # SpAtk boost doubled
	},
	:damageMods => { 1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :AURASPHERE, :HEX, :MOONBLAST, :MINDBLOWN, :FOCUSBLAST, :SECRETPOWER, :HIDDENPOWER] },
	:accuracyMods => { 90 => [:HYPNOSIS] },
	:typeBoosts => { 1.5 => [:PSYCHIC] },
	:typeCondition => { :PSYCHIC => "!attacker.isAirborne?" },
	:statusMods => [:GRAVITY, :TRICKROOM, :MAGICROOM, :WONDERROOM, :PSYCHUP, :MINDREADER, :MIRACLEEYE],
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Confusion,
		:duration => 3,
		:message => "{1} became confused!",
		:animation => :CONFUSION,
		:stats => { :SPECIAL_ATTACK => 1, :SPECIAL_DEFENSE => 1 },
	},
},
:BEWITCHED => {
	:name => "Bewitched Woods",
	:fieldMessage => ["Everlasting glow and glamour!"],
	:graphic => ["BewitchedWoods"],
	:secretPower => "DAZZLINGGLEAM",
	:naturePower => :DAZZLINGGLEAM,
	:mimicry => :FAIRY,
	# Abilities (Section 36)
	:abilityActivate => {
		:EFFECTSPORE => { doubled_rate: true },
		:NATURALCURE => { eor_healing: true },
		:FLOWERVEIL => { affects_all: true },
		:FLOWERGIFT => { always_active: true },
		:PASTELVEIL => { remove_fairy_weakness: true },
		:COTTONDOWN => { doubled_effect: true },
		:POWERSPOT => {},
	},
	# Ability mods
	:abilityMods => {
		:POWERSPOT => { multiplier: 1.5 },
	},
	# Move stat mods
	:moveStatStageMods => {
		:STRENGTHSAP => { additional_stats: { :SPECIAL_ATTACK => -1 } },
		:FORESTSCURSE => { additional_effect: :curse },
		:MAGICPOWDER => { status_effect: :sleep },
		:MOONLIGHT => { healing_amount: 0.75 },
	},
	:damageMods => {
		1.5 => [:HEX, :MYSTICALFIRE, :SPIRITBREAK, :MAGICALLEAF],
		1.4 => [:ICEBEAM, :HYPERBEAM, :SIGNALBEAM, :AURORABEAM, :BUBBLEBEAM, :CHARGEBEAM, :PSYBEAM, :FLASHCANNON, :MIRRORBEAM],
		1.2 => [:DARKPULSE, :NIGHTDAZE, :MOONBLAST],
	},
	:accuracyMods => { 85 => [:POISONPOWDER, :SLEEPPOWDER, :GRASSWHISTLE, :STUNSPORE] },
	:typeBoosts => { 1.5 => [:FAIRY, :GRASS], 1.3 => [:DARK] },
	:fieldChange => { :FOREST => [:PURIFY] },
	:statusMods => [:MOONLIGHT, :FORESTSCURSE, :STRENGTHSAP, :MAGICPOWDER],
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => { :SPECIAL_DEFENSE => 1 },
	},
},
:BIGTOP => {
	:name => "Big Top Arena",
	:fieldMessage => ["Now presenting...!"],
	:graphic => ["BigTop"],
	:secretPower => "POWERUPPUNCH",
	:naturePower => :ACROBATICS,
	:mimicry => :NORMAL,
	# High Striker moves - physical Fighting + specific moves
	:highStrikerMoves => [
		# All physical Fighting-type moves (handled in hardcode section 40)
		:STRENGTH, :WOODHAMMER, :DUALCHOP, :HEATCRASH, :SKYDROP,
		:BULLDOZE, :ICICLECRASH, :BODYSLAM, :STOMP, :GIGAIMPACT,
		:POUND, :SMACKDOWN, :IRONTAIL, :METEORMASH, :CRABHAMMER,
		:DRAGONRUSH, :BOUNCE, :SLAM, :HEAVYSLAM, :HIGHHORSEPOWER,
		:EARTHQUAKE, :ICEHAMMER, :DRAGONHAMMER, :CONTINENTALCRUSH, :STOMPINGTANTRUM,
		:GRAVAPPLE, :BRUTALSWING, :MAGNITUDE, :BLAZEKICK, :DOUBLEIRONBASH,
		:HEADLONGRUSH
	],
	# High Striker guarantee abilities
	:abilityActivate => {
		:GUTS => { high_striker_guarantee: true },
		:HUGEPOWER => { high_striker_guarantee: true },
		:PUREPOWER => { high_striker_guarantee: true },
		:SHEERFORCE => { high_striker_guarantee: true },
		:DANCER => {},  # Speed/SpAtk boost on dance moves (needs hardcode)
		:PUNKROCK => {},  # 1.5x sound boost (already in abilityMods)
	},
	# Ability mods
	:abilityMods => {
		:PUNKROCK => { multiplier: 1.5 },  # Sound moves boosted
	},
	:moveStatStageMods => {
		:DRAGONDANCE => { stats_override: { :ATTACK => 2, :SPEED => 2 } },
		:QUIVERDANCE => { stats_override: { :SPECIAL_ATTACK => 2, :SPECIAL_DEFENSE => 2, :SPEED => 2 } },
		:SWORDSDANCE => { stats_override: { :ATTACK => 4 } },
		:FEATHERDANCE => { stages: 4 },
		:BELLYDRUM => { additional_stats: { :DEFENSE => 1, :SPECIAL_DEFENSE => 1 } },
		:CLANGOROUSSOUL => { stats_override: { :ATTACK => 2, :DEFENSE => 2, :SPECIAL_ATTACK => 2, :SPECIAL_DEFENSE => 2, :SPEED => 2 }, hp_cost: 0.5 },
		:SPOTLIGHT => { additional_stats: { :ATTACK => 1, :SPECIAL_ATTACK => 1 } },  # For user AND target
	},
	:damageMods => {
		2.0 => [:PAYDAY],
		1.5 => [:VINEWHIP, :POWERWHIP, :FIERYDANCE, :PETALDANCE, :FLY, :ACROBATICS, :FIRELASH, :REVELATIONDANCE, :FIRSTIMPRESSION, :DRUMBEATING,
		        # Sound-based moves (needs comprehensive list or soundMove? check)
		        :BOOMBURST, :BUGBUZZ, :CHATTER, :CLANGINGSCALES, :CONFIDE, :DISARMINGVOICE, :ECHOEDVOICE,
		        :GRASSWHISTLE, :GROWL, :HEALBELL, :HYPERVOICE, :METALSOUND, :NOBLEROAR, :OVERDRIVE,
		        :PERISHSONG, :RELICSONG, :ROAR, :ROUND, :SCREECH, :SING, :SNARL, :SNORE, :SPARKLINGARIA,
		        :SUPERSONIC, :UPROAR],
	},
	:accuracyMods => { 100 => [:SING] },
	:weatherDuration => { :Rain => 8 },
	:statusMods => [:ENCORE, :RAINDANCE, :PAYDAY, :SPOTLIGHT, :DRAGONDANCE, :QUIVERDANCE, :SWORDSDANCE, :FEATHERDANCE, :BELLYDRUM, :CLANGOROUSSOUL],
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :HelpingHand,
		:duration => 1,
		:message => "{1} is ready to help!",
		:stats => { :ATTACK => 1 },
	},
},
:ENCHANTEDFOREST => {
	:name => "Enchanted Forest",
	:fieldMessage => [
		"Once upon a time!"
	],
	:graphic => ["Enchanted_Forest"],
	:secretPower => "DAZZLINGGLEAM",
	:naturePower => :DAZZLINGGLEAM,
	:mimicry => :FAIRY,
	:damageMods => {
		1.5 => [:HEX, :MYSTICALFIRE, :SPIRITBREAK, :MAGICALTORQUE, :FLEURCANNON, :RELICSONG,
		        :AIRSLASH, :AQUACUTTER, :BEHEMOTHBLADE, :CEASELESSEDGE, :LEAFBLADE, :NIGHTSLASH, 
		        :PSYCHOCUT, :RAZORSHELL, :SMARTSTRIKE, :SOLARBLADE, :STONEAXE, :TACHYONCUTTER, 
		        :BITTERBLADE, :PSYBLADE],
		1.4 => [:AURORABEAM, :BUBBLEBEAM, :CHARGEBEAM, :HYPERBEAM, :ICEBEAM, 
		        :PSYBEAM, :SIGNALBEAM, :TWINBEAM],
		1.2 => [:DARKPULSE, :MOONBLAST, :NIGHTDAZE, :BLOODMOON],
	},
	:accuracyMods => {
		85 => [:GRASSWHISTLE, :POISONPOWDER, :SLEEPPOWDER, :STUNSPORE],
	},
	:moveMessages => {
		"Magic aura amplified the attack!" => [:HEX, :MYSTICALFIRE, :SPIRITBREAK, :MAGICALTORQUE, :FLEURCANNON, :RELICSONG],
		"The Knight is Justified!" => [:AIRSLASH, :AQUACUTTER, :BEHEMOTHBLADE, :CEASELESSEDGE, :LEAFBLADE, :NIGHTSLASH, 
		                                :PSYCHOCUT, :RAZORSHELL, :SMARTSTRIKE, :SOLARBLADE, :STONEAXE, :TACHYONCUTTER, 
		                                :BITTERBLADE, :PSYBLADE],
		"Magic aura amplified the beams!" => [:AURORABEAM, :BUBBLEBEAM, :CHARGEBEAM, :HYPERBEAM, :ICEBEAM, 
		                                      :PSYBEAM, :SIGNALBEAM, :TWINBEAM],
		"It was a curse!" => [:DARKPULSE, :MOONBLAST, :NIGHTDAZE, :BLOODMOON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FAIRY, :GRASS, :POISON],
		1.3 => [:DARK],
		1.2 => [:STEEL],
	},
	:typeMessages => {
		"The enchanted aura boosted the attack!" => [:FAIRY, :STEEL],
		"Flourish!" => [:GRASS],
		"Poison seeps from the darkness!" => [:POISON],
		"Not all fairy tales..." => [:DARK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:FORESTSCURSE, :MAGICPOWDER, :MOONLIGHT, :STRENGTHSAP],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
	},
:SAHARA => {
	:name => "Sahara",
	:fieldMessage => [
		"The air is dry and humid."
	],
	:graphic => ["Sahara"],
	:secretPower => "NEEDLEARM",
	:naturePower => :NEEDLEARM,
	:mimicry => :GROUND,
	:damageMods => {
		1.5 => [:NEEDLEARM, :OVERHEAT, :PINMISSILE, :ROCKWRECKER, :SANDTOMB, :SCORCHINGSANDS, :ATTACKORDER, :BUGBUZZ],
		0.8 => [:WATER],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The dry earth boosted the attack!" => [:NEEDLEARM, :OVERHEAT, :PINMISSILE, :ROCKWRECKER, :SANDTOMB, :SCORCHINGSANDS],
		"They're coming out of the woodwork!" => [:ATTACKORDER, :BUGBUZZ],
		"The water evaporated!" => [:WATER],
	},
	:typeMods => {
		:WATER => [:ICE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:BUG, :FIRE, :GROUND, :ROCK],
	},
	:typeMessages => {
		"The humid air boosted the attack!" => [:BUG, :FIRE, :GROUND, :ROCK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SANDATTACK, :DEFENDORDER, :SILVERWIND],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:DEFENSE => 1,
		},
	},
	},
:POISONLIBRARY => {
	:name => "Poison Library",
	:fieldMessage => [
		"The library is seeping knowledge."
	],
	:graphic => ["PoisonLibrary"],
	:secretPower => "ACID",
	:naturePower => :ACID,
	:mimicry => :POISON,
	:damageMods => {},
	:accuracyMods => {},
	:moveMessages => {},
	:typeMods => {},
	:typeAddOns => {
		:POISON => [:GRASS],
		:FAIRY => [:PSYCHIC],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.4 => [:POISON],
		1.2 => [:GRASS, :FIRE, :FAIRY],
	},
	:typeMessages => {
		"The Poison permeates through the field!" => [:POISON],
		"The library is overgrown!" => [:GRASS],
		"Alexandria!" => [:FIRE],
		"The power of knowledge!" => [:FAIRY],
	},
	:typeCondition => {
		:POISON => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},

:STARLIGHTARENA => {
	:name => "Starlight Arena",
	:fieldMessage => [
		"Starlight fills the battlefield."
	],
	:graphic => ["StarLight"],
	:secretPower => "PSYWAVE",  # 14 = Lower Sp. Def
	:naturePower => :MOONBLAST,
	:mimicry => :DARK,
	:damageMods => {
		1.5 => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DAZZLINGGLEAM, :MIRRORSHOT,
		        :MOONBLAST, :TECHNOBLAST, :SOLARBEAM, :PHOTONGEYSER, :PRISMATICLASER, :NIGHTSLASH,
		        :NIGHTDAZE, :MIRRORBEAM],
		2.0 => [:DRACOMETEOR, :METEORMASH, :COMETPUNCH, :SPACIALREND, :SWIFT,
		        :HYPERSPACEHOLETARGET, :HYPERSPACEFURY, :MOONGEISTBEAM, :SUNSTEELSTRIKE,
		        :METEORASSAULT, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM,
		        :LIGHTTHATBURNSTHESKY, :BLACKHOLEECLIPSE],
		4.0 => [:DOOMDESIRE],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The starlight powered up the attack!" => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE,
		        :DAZZLINGGLEAM, :MIRRORSHOT, :MOONBLAST, :TECHNOBLAST, :SOLARBEAM, :PHOTONGEYSER,
		        :PRISMATICLASER, :NIGHTSLASH, :NIGHTDAZE, :MIRRORBEAM],
		"The cosmos amplified the attack!" => [:DRACOMETEOR, :METEORMASH, :COMETPUNCH, :SPACIALREND,
		        :SWIFT, :HYPERSPACEHOLETARGET, :HYPERSPACEFURY, :MOONGEISTBEAM, :SUNSTEELSTRIKE,
		        :METEORASSAULT, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM,
		        :LIGHTTHATBURNSTHESKY, :BLACKHOLEECLIPSE],
		"Doom Desire ignited in starfire!" => [:DOOMDESIRE],
	},
	:typeMods => {},
	:typeAddOns => {
		# Dark-type attacks deal additional Fairy damage; Solar Beam/Blade also
		# (Dark-type moves are handled via typeBoosts; individual moves listed for add-on)
		:FAIRY => [:SOLARBEAM, :SOLARBLADE],
	},
	:typeBoosts => {
		1.5 => [:PSYCHIC, :DARK],
		1.3 => [:FAIRY],
	},
	:typeMessages => {
		"The starlight charged the Psychic attack!" => [:PSYCHIC],
		"The darkness of the cosmos powered the attack!" => [:DARK],
		"The starlight shimmered with fairy energy!" => [:FAIRY],
	},
	:typeCondition => {},
	:typeEffects => {},
	:moveEffects => {},
	:moveStatStageMods => {
		:COSMICPOWER => { stages: 2 },
		:FLASH       => { stages: 2 },
	},
	:noCharging => [:METEORASSAULT, :METEORBEAM, :GEOMANCY, :SOLARBEAM, :SOLARBLADE],
	:noChargingMessages => {
		"The starlight let it attack instantly!" => [:METEORASSAULT, :METEORBEAM, :GEOMANCY, :SOLARBEAM, :SOLARBLADE],
	},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:LIGHTTHATBURNSTHESKY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"Light That Burns the Sky consumed the starlight!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:COSMICPOWER, :FLASH, :WISH, :MOONLIGHT, :LUNARBLESSING, :AURORAVEIL,
		            :HEALINGWISH, :LUNARDANCE],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Wish,
		:duration => 2,
		:message => "The stardust granted {1} a wish!",
		:animation => :WISH,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
	:overlay => {
		:damageMods => {},
		:typeMods => {},
		:moveMessages => {},
		:typeBoosts => {},
		:typeMessages => {},
		:typeCondition => {},
		:statusMods => [],
	},
},


:NEWWORLD => {
	:name => "New World",
	:fieldMessage => [
		"From darkness, from stardust, from memories of eons passed and visions yet to come..."
	],
	:graphic => ["NewWorld"],
	:secretPower => "DRACOMETEOR",  # 13 = Flinch (closest to "lower all stats" — hardcoded separately)
	:naturePower => :SPACIALREND,
	:mimicry => :NORMAL,  # random type — hardcoded in 010
	:damageMods => {
		1.5 => [:MIRRORSHOT, :AURORABEAM, :SIGNALBEAM, :DAZZLINGGLEAM, :COREENFORCER, :MIRRORBEAM,
		        :FLASHCANNON, :PSYSTRIKE, :AEROBLAST, :SACREDFIRE, :MISTBALL,
		        :LUSTERPURGE, :ORIGINPULSE, :PRECIPICEBLADES, :DRAGONASCENT, :PHOTONGEYSER,
		        :PSYCHOBOOST, :ROAROFTIME, :MAGMASTORM, :CRUSHGRIP, :MINDBLOWN,
		        :SHADOWFORCE, :SEEDFLARE, :JUDGMENT, :SEARINGSHOT, :PLASMAFISTS,
		        :VCREATE, :SACREDSWORD, :SECRETSWORD, :FUSIONBOLT,
		        :FUSIONFLARE, :BOLTSTRIKE, :BLUEFLARE, :GLACIATE,
		        :ICEBURN, :FREEZESHOCK, :RELICSONG, :TECHNOBLAST,
		        :OBLIVIONWING, :LANDSWRATH, :THOUSANDARROWS, :THOUSANDWAVES,
		        :DIAMONDSTORM, :STEAMERUPTION, :ERUPTION, :POWERGEM,
		        :EARTHPOWER, :FLEURCANNON, :PRISMATICLASER, :SUNSTEELSTRIKE,
		        :SPECTRALTHIEF, :MOONGEISTBEAM, :MULTIATTACK, :CONTINENTALCRUSH,
		        :GENESISSUPERNOVA, :SOULEATINGSEVENSTARSTRIKE,
		        :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM],
		2.0 => [:VACUUMWAVE, :DRACOMETEOR, :METEORMASH, :MOONBLAST,
		        :COMETPUNCH, :SPACIALREND, :SWIFT, :FUTURESIGHT,
		        :ANCIENTPOWER, :HYPERSPACEHOLETARGET, :HYPERSPACEFURY,
		        :LIGHTTHATBURNSTHESKY, :BLACKHOLEECLIPSE],
		0.25 => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE],
		4.0 => [:DOOMDESIRE],
	},
	:accuracyMods => {
		100 => [:DARKVOID],
	},
	:moveMessages => {
		"The cosmos amplified the attack!" => [:MIRRORSHOT, :AURORABEAM, :SIGNALBEAM, :DAZZLINGGLEAM,
		        :COREENFORCER, :MIRRORBEAM, :FLASHCANNON, :PSYSTRIKE, :AEROBLAST, :SACREDFIRE,
		        :MISTBALL, :LUSTERPURGE, :ORIGINPULSE, :PRECIPICEBLADES, :DRAGONASCENT, :PHOTONGEYSER,
		        :PSYCHOBOOST, :ROAROFTIME, :MAGMASTORM, :CRUSHGRIP, :MINDBLOWN, :SHADOWFORCE,
		        :SEEDFLARE, :JUDGMENT, :SEARINGSHOT, :PLASMAFISTS, :VCREATE, :SACREDSWORD,
		        :SECRETSWORD, :FUSIONBOLT, :FUSIONFLARE, :BOLTSTRIKE, :BLUEFLARE, :GLACIATE,
		        :ICEBURN, :FREEZESHOCK, :RELICSONG, :TECHNOBLAST, :OBLIVIONWING, :LANDSWRATH,
		        :THOUSANDARROWS, :THOUSANDWAVES, :DIAMONDSTORM, :STEAMERUPTION, :ERUPTION,
		        :POWERGEM, :EARTHPOWER, :FLEURCANNON, :PRISMATICLASER, :SUNSTEELSTRIKE,
		        :SPECTRALTHIEF, :MOONGEISTBEAM, :MULTIATTACK, :CONTINENTALCRUSH,
		        :GENESISSUPERNOVA, :SOULEATINGSEVENSTARSTRIKE, :SEARINGSUNRAZESMASH,
		        :MENACINGMOONRAZEMAELSTROM],
		"The cosmic tide doubled the attack!" => [:VACUUMWAVE, :DRACOMETEOR, :METEORMASH, :MOONBLAST,
		        :COMETPUNCH, :SPACIALREND, :SWIFT, :FUTURESIGHT, :ANCIENTPOWER,
		        :HYPERSPACEHOLETARGET, :HYPERSPACEFURY, :LIGHTTHATBURNSTHESKY, :BLACKHOLEECLIPSE],
		"The ground-shaking move weakened in the void!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE],
		"Doom Desire ignited in cosmic starfire!" => [:DOOMDESIRE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:typeBoosts => {
		1.5 => [:DARK],
	},
	:typeMessages => {
		"The darkness of space powered the attack!" => [:DARK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:moveEffects => {},
	:moveStatStageMods => {
		:COSMICPOWER => { stages: 2 },
		:FLASH       => { stages: 2 },
	},
	:noCharging => [:METEORBEAM],
	:noChargingMessages => {
		"The cosmos let the beam fire instantly!" => [:METEORBEAM],
	},
	:changeCondition => {},
	:fieldChange => {
		:STARLIGHTARENA => [:GRAVITY, :GEOMANCY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The cosmos shifted to Starlight!" => [:GRAVITY, :GEOMANCY],
	},
	:statusMods => [:COSMICPOWER, :FLASH, :FISSURE, :MOONLIGHT, :LUNARBLESSING, :AURORAVEIL,
		            :LUNARDANCE, :DARKVOID],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => nil,
		:duration => nil,
		:message => "The cosmic seed powered up {1}!",
		:animation => :COSMICPOWER,
		:stats => {
			:ATTACK          => 1,
			:DEFENSE         => 1,
			:SPECIAL_ATTACK  => 1,
			:SPECIAL_DEFENSE => 1,
			:SPEED           => 1,
		},
	},
	:overlay => {
		:damageMods => {},
		:typeMods => {},
		:moveMessages => {},
		:typeBoosts => {},
		:typeMessages => {},
		:typeCondition => {},
		:statusMods => [],
	},
},

}
}
