class_name ShopCatalog
extends RefCounted
## res://data/shop_catalog.gd
## Catálogo estático + funciones puras (sin estado). Todo en dólares ($).
## OJO: nombres/precios de materiales y circuitos son PLACEHOLDERS; reemplázalos
## por los del documento de diseño del equipo (respetando los rangos de precio).

const MAX_ORDERS_PER_SOL := 2
const MAX_QTY := 99

# Rango de precio -> días de entrega: $25-30 = 1 d, $35-45 = 2 d, $55-65 = 3 d
const _MATERIALS := [
	{"id": "aluminio",   "nombre": "Aluminio estructural", "precio": 25},
	{"id": "acero",      "nombre": "Acero inoxidable",     "precio": 35},
	{"id": "polimero",   "nombre": "Polímero térmico",     "precio": 30},
	{"id": "cuarzo",     "nombre": "Vidrio de cuarzo",     "precio": 40},
	{"id": "fibra_c",    "nombre": "Fibra de carbono",     "precio": 55},
	{"id": "titanio",    "nombre": "Titanio aeroespacial", "precio": 65},
]

# Circuitos que piden las recetas de Diseño (GameManager.ROCKET_PARTS). Si cambias una receta, cambia aquí también.
const _CIRCUITS := [
	{"id": "c_termico",  "nombre": "Sensor térmico",        "precio": 25},
	{"id": "c_potencia", "nombre": "Módulo de potencia",    "precio": 45},
	{"id": "c_guiado",   "nombre": "Circuito de guiado",    "precio": 60},
	{"id": "c_enlace",   "nombre": "Módulo de enlace",      "precio": 65},
]

# Suministros de seguridad (se compran de 1 en 1)
const SUPPLIES := [
	{"id": "humo",      "nombre": "Detector de humo",   "costo": 50,   "max": 1, "dias": 1},
	{"id": "extintor",  "nombre": "Extintores",         "costo": 150,  "max": 2, "dias": 2},
	{"id": "enlace",    "nombre": "Módulos de enlace",  "costo": 2000, "max": 3, "dias": 3},
	{"id": "botiquin",  "nombre": "Botiquines",         "costo": 75,   "max": 4, "dias": 1},
]


static func days_for_price(precio: int) -> int:
	if precio <= 30:
		return 1
	if precio <= 45:
		return 2
	return 3


static func _enrich(list: Array) -> Array:
	var out: Array = []
	for it in list:
		var d: Dictionary = it.duplicate()
		d["dias"] = days_for_price(int(d["precio"]))
		out.append(d)
	return out


static func materials() -> Array:
	return _enrich(_MATERIALS)


static func circuits() -> Array:
	return _enrich(_CIRCUITS)


static func all_items() -> Array:
	return materials() + circuits()


static func get_item(id: String) -> Dictionary:
	for it in all_items():
		if it["id"] == id:
			return it
	return {}


static func get_supply(id: String) -> Dictionary:
	for s in SUPPLIES:
		if s["id"] == id:
			return s
	return {}


## items: {id: cantidad}. Devuelve el total en $.
static func order_total(items: Dictionary) -> int:
	var total := 0
	for id in items:
		var qty := int(items[id])
		if qty > 0:
			total += int(get_item(id).get("precio", 0)) * qty
	return total


## Días = máximo de días de entrega entre los ítems con cantidad > 0.
static func order_delivery_days(items: Dictionary) -> int:
	var days := 0
	for id in items:
		if int(items[id]) > 0:
			days = maxi(days, int(get_item(id).get("dias", 1)))
	return days
