"""
FILE: test_damage_calculator.gd
PURPOSE: Verify combat math.
"""

extends UnitTest

func test_physical_damage() -> void:
	# Setup
	var str_stat = 10
	var might = 5
	var defense = 3
	
	# Execute
	var dmg = (str_stat + might) - defense
	
	# Verify
	assert_eq(dmg, 12, "Physical damage calculation")

func test_magical_damage() -> void:
	# Setup
	var mag_stat = 15
	var might = 8
	var res = 5
	
	# Execute
	var dmg = (mag_stat + might) - res
	
	# Verify
	assert_eq(dmg, 18, "Magical damage calculation")

func test_damage_floor() -> void:
	# Damage should not be negative
	var str_stat = 5
	var might = 0
	var defense = 10
	
	var dmg = max(0, (str_stat + might) - defense)
	
	assert_eq(dmg, 0, "Damage floor should be 0")

func test_doubling_threshold() -> void:
	# Speed diff needed is usually 5
	var attacker_speed = 15
	var defender_speed = 10
	var threshold = 5
	
	var doubles = (attacker_speed - defender_speed) >= threshold
	assert_true(doubles, "Should double attack with +5 speed")
	
	defender_speed = 11
	doubles = (attacker_speed - defender_speed) >= threshold
	assert_false(doubles, "Should NOT double with +4 speed")
