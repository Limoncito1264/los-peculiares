extends Control
## res://scripts/supply_row.gd
## Fila de un suministro de seguridad. Emite purchase_requested al pulsar el botón.

signal purchase_requested(supply_id: String)

@onready var lbl_nombre: Label = %LblNombre
@onready var lbl_reserva: Label = %LblReserva
@onready var lbl_costo: Label = %LblCosto
@onready var lbl_entrega: Label = %LblEntrega
@onready var btn_accion: Button = %BtnAccion

var supply_id: String = ""
var _def: Dictionary = {}


func _ready() -> void:
	btn_accion.pressed.connect(func(): purchase_requested.emit(supply_id))
	_apply_static()


## def: entrada de ShopCatalog.SUPPLIES
func setup(def: Dictionary) -> void:
	_def = def
	supply_id = str(def["id"])
	if is_node_ready():
		_apply_static()


func _apply_static() -> void:
	if _def.is_empty():
		return
	lbl_nombre.text = str(_def["nombre"])
	lbl_costo.text = "$%d" % int(_def["costo"])
	lbl_entrega.text = "%d d" % int(_def["dias"])


## Actualiza el estado dinámico (lo llama el tab en cada refresh).
func update_state(reserva: int, en_camino: int, locked: bool) -> void:
	var max_qty := int(_def.get("max", 1))
	var txt := "%d / %d" % [reserva, max_qty]
	if en_camino > 0:
		txt += "  (+%d en camino)" % en_camino
	lbl_reserva.text = txt

	var total := reserva + en_camino
	if total >= max_qty:
		btn_accion.text = "COMPLETO"
		btn_accion.disabled = true
	else:
		btn_accion.text = "INSTALAR" if total == 0 else "REPONER"
		btn_accion.disabled = locked
