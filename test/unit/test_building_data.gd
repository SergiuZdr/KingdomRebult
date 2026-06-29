extends GutTest

# Teste pentru modelul data-driven al cladirilor: productia pe niveluri si pe muncitori.

func test_per_level_production():
	var b := BuildingData.new()
	b.food_by_level = PackedInt32Array([10, 15, 20])
	assert_eq(b.get_stat_at_level(b.food_by_level, 1, 0), 10, "hrana la nivelul 1")
	assert_eq(b.get_stat_at_level(b.food_by_level, 2, 0), 15, "hrana la nivelul 2")
	assert_eq(b.get_stat_at_level(b.food_by_level, 3, 0), 20, "hrana la nivelul 3")

func test_out_of_range_uses_fallback():
	var b := BuildingData.new()
	b.food_by_level = PackedInt32Array([10])
	assert_eq(b.get_stat_at_level(b.food_by_level, 5, 99), 99, "valoarea de rezerva cand nivelul depaseste tabloul")

func test_production_scales_with_workers():
	var b := BuildingData.new()
	b.food_by_level = PackedInt32Array([10])
	var prod := b.get_production_for_workers(3, 1)
	assert_eq(int(prod.get("Food", 0)), 30, "3 muncitori x 10 hrana = 30")
