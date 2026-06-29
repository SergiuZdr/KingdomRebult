extends GutTest

# Teste pentru progresia soldatului: alocarea manuala de statistici si sloturile de abilitati.

func _make(cls: String) -> SoldierData:
	var s := SoldierData.new()
	s.soldier_class = cls
	return s

func test_point_value_favored_and_off():
	var s := _make("Warrior")  # FAVORED: power, hp
	assert_eq(s.point_value("power"), 2, "putere favorizata pentru Warrior (+2)")
	assert_eq(s.point_value("dexterity"), 1, "statistica obisnuita (+1)")
	assert_eq(s.point_value("hp"), 7, "viata favorizata pentru Warrior (+7)")

func test_point_value_hp_off_stat():
	var s := _make("Archer")  # FAVORED: dexterity, speed
	assert_eq(s.point_value("hp"), 5, "viata neutra (+5)")
	assert_eq(s.point_value("speed"), 2, "viteza favorizata pentru Archer (+2)")

func test_spend_stat_point_applies_and_decrements():
	var s := _make("Warrior")
	s.unspent_stat_points = 3
	var p0 := s.power
	assert_true(s.spend_stat_point("power"), "alocarea reuseste cand exista puncte")
	assert_eq(s.power, p0 + 2, "puterea creste cu valoarea favorizata")
	assert_eq(s.unspent_stat_points, 2, "un punct a fost consumat")

func test_spend_stat_point_blocked_without_points():
	var s := _make("Warrior")
	s.unspent_stat_points = 0
	assert_false(s.spend_stat_point("power"), "nu se poate aloca fara puncte")

func test_hp_allocation_raises_max_and_current():
	var s := _make("Warrior")
	s.unspent_stat_points = 1
	var hp_max0 := s.hp_max
	var hp_cur0 := s.hp_current
	s.spend_stat_point("hp")
	assert_eq(s.hp_max, hp_max0 + 7, "hp_max creste cu 7")
	assert_eq(s.hp_current, hp_cur0 + 7, "hp_current creste cu 7")

func test_skill_slots_unlock_by_level():
	var s := _make("Warrior")
	s.level = 1
	assert_eq(s.max_skill_slots(), 1, "1 slot la nivelul 1")
	s.level = 5
	assert_eq(s.max_skill_slots(), 2, "2 sloturi la nivelul 5")
	s.level = 10
	assert_eq(s.max_skill_slots(), 3, "3 sloturi la nivelul 10")
