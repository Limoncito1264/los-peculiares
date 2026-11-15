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

const _CIRCUITS := [
	{"id": "sensor",     "nombre": "Sensor de presión",     "precio": 25},
	{"id": "panel_sol",  "nombre": "Controlador solar",     "precio": 30},
	{"id": "regulador",  "nombre": "Regulador de voltaje",  "precio": 35},
	{"id": "motor_ctl",  "nombre": "Controlador de motor",  "precio": 45},
	{"id": "bateria",    "nombre": "Módulo de batería",     "precio": 55},
	{"id": "procesador", "nombre": "Procesador de vuelo",   "precio": 60},
	{"id": "comms",      "nombre": "Módulo de comunicación","precio": 65},
]

# Recetas de cohete (placeholder: ajusta a tu documento). Aún no las usa la UI.
const ROCKET_RECIPES := [
	{"id": "r1", "nombre": "Cohete Explorador I",   "requiere": {"aluminio": 4, "sensor": 2}},
	{"id": "r2", "nombre": "Cohete Explorador II",  "requiere": {"acero": 4, "regulador": 2}},
	{"id": "r3", "nombre": "Cohete Carguero",       "requiere": {"fibra_c": 3, "motor_ctl": 2}},
	{"id": "r4", "nombre": "Cohete Orbital",        "requiere": {"titanio": 3, "procesador": 1}},
	{"id": "r5", "nombre": "Cohete de Rescate",     "requiere": {"titanio": 4, "comms": 2, "bateria": 2}},
	{"id": "r6", "nombre": "Cohete de Retorno",     "requiere": {"titanio": 6, "procesador": 2, "comms": 2}},
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
