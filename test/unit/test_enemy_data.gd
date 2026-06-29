extends GutTest

# Teste pentru motorul de efecte de status (comun soldatilor si inamicilor).

func test_status_potency_accumulates():
	var e := EnemyData.new()
	e.add_status("weaken", 3, 2)
	e.add_status("weaken", 2, 2)
	assert_eq(e.get_status_potency("weaken"), 5, "potenta de slabire se aduna")

func test_shield_routes_into_shield_hp():
	var e := EnemyData.new()
	e.add_status("shield", 8, 1)
	assert_eq(e.shield_hp, 8, "scutul ajunge in shield_hp, nu in lista de status")

func test_effective_power_reduced_by_weaken():
	var e := EnemyData.new()
	e.power = 10
	e.add_status("weaken", 4, 2)
	assert_eq(e.get_effective_power(), 6, "puterea efectiva scade cu slabirea")

func test_poison_dot_reduces_hp():
	var e := EnemyData.new()
	e.hp_max = 50
	e.hp_current = 50
	e.add_status("poison", 5, 3)
	e.apply_status_dot()
	assert_eq(e.hp_current, 45, "otrava aplica 5 daune pe tura")
