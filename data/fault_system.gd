extends RefCounted
## res://data/fault_system.gd
## Lógica compartida de eventos aleatorios (la usan GameManager y MockState).
## Dos tipos:
##  - "marte":  emergencia. Bloquea TODO lo demás hasta resolverla (cuesta $ y un día).
##  - "tierra": falla en la base terrestre. Se repara asignando un trabajador
##              durante N días; solo hay `workers_total` trabajadores a la vez.

const MARS_COOLDOWN_DAYS := 4     # días SIN emergencias nuevas tras resolver una
const MARS_GRACE_SOLS := 3        # primeros Soles sin emergencias en Marte
const DEFAULT_WORKERS := 2

var workers_total: int = DEFAULT_WORKERS
var mars_cooldown: int = 0
## Emergencia marciana anticipada por el detector de humo (se activa el Sol siguiente).
var pending_mars_id: String = ""

# prob = probabilidad diaria. costo solo aplica a Marte. dias_rep solo a Tierra.
var faults: Array = [
	# ---- MARTE ----
	{"id": "m_oxigeno",    "tipo": "marte", "titulo": "Fuga de oxígeno",   "desc": "Presión cayendo en el módulo habitable.", "prob": 0.04, "costo": 300, "dias_rep": 0, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "m_polvo",      "tipo": "marte", "titulo": "Tormenta de polvo", "desc": "Paneles solares cubiertos de polvo.",     "prob": 0.05, "costo": 150, "dias_rep": 0, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "m_estructura", "tipo": "marte", "titulo": "Daño estructural",  "desc": "Micrometeorito impactó el casco.",        "prob": 0.03, "costo": 400, "dias_rep": 0, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "m_agua",       "tipo": "marte", "titulo": "Fuga de agua",      "desc": "Pérdida en el reciclador de agua.",       "prob": 0.04, "costo": 250, "dias_rep": 0, "activa": false, "en_reparacion": false, "restante": 0},
	# ---- TIERRA ----
	{"id": "t_control",    "tipo": "tierra", "titulo": "Falla en centro de control", "desc": "Consolas de la base terrestre caídas.",   "prob": 0.06, "costo": 0, "dias_rep": 2, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "t_antena",     "tipo": "tierra", "titulo": "Pérdida de comunicación",    "desc": "Antena terrestre desalineada.",            "prob": 0.05, "costo": 0, "dias_rep": 2, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "t_software",   "tipo": "tierra", "titulo": "Falla de software",          "desc": "Servidor de simulación reiniciándose.",    "prob": 0.07, "costo": 0, "dias_rep": 1, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "t_proveedor",  "tipo": "tierra", "titulo": "Retraso de proveedor",       "desc": "Un proveedor no entregó a tiempo.",        "prob": 0.05, "costo": 0, "dias_rep": 3, "activa": false, "en_reparacion": false, "restante": 0},
	{"id": "t_energia",    "tipo": "tierra", "titulo": "Corte de energía en la base","desc": "Apagón en las instalaciones terrestres.",  "prob": 0.06, "costo": 0, "dias_rep": 2, "activa": false, "en_reparacion": false, "restante": 0},
]


func get_faults() -> Array:
	return faults


func find_fault(id: String) -> Dictionary:
	for f in faults:
		if f["id"] == id:
			return f
	return {}


# ---------- Marte ----------

func get_blocking_event() -> Dictionary:
	for f in faults:
		if f["tipo"] == "marte" and f["activa"]:
			return f
	return {}


func has_mars_event() -> bool:
	return not get_blocking_event().is_empty()


## Marca la emergencia como resuelta y arranca el enfriamiento.
## (+1 porque tick_day descuenta un día en el mismo Sol que se pierde.)
func resolve_mars(id: String) -> bool:
	var f := find_fault(id)
	if f.is_empty() or f["tipo"] != "marte" or not f["activa"]:
		return false
	f["activa"] = false
	mars_cooldown = MARS_COOLDOWN_DAYS + 1
	return true


# ---------- Tierra / trabajadores ----------

func workers_busy() -> int:
	var n := 0
	for f in faults:
		if f["tipo"] == "tierra" and f["en_reparacion"]:
			n += 1
	return n


func workers_free() -> int:
	return maxi(workers_total - workers_busy(), 0)


func workers_info() -> Dictionary:
	return {"total": workers_total, "busy": workers_busy(), "free": workers_free()}


func start_earth_repair(id: String, free_override: int = -1) -> Dictionary:
	var f := find_fault(id)
	if f.is_empty() or f["tipo"] != "tierra":
		return {"ok": false, "msg": "Falla desconocida."}
	if has_mars_event():
		return {"ok": false, "msg": "Emergencia en Marte: resuélvela primero."}
	if not f["activa"]:
		return {"ok": false, "msg": "Esa falla ya no está activa."}
	if f["en_reparacion"]:
		return {"ok": false, "msg": "Ya hay un trabajador asignado."}
	var libres := free_override if free_override >= 0 else workers_free()
	if libres <= 0:
		return {"ok": false, "msg": "No hay trabajadores libres."}
	f["en_reparacion"] = true
	f["restante"] = int(f["dias_rep"])
	return {"ok": true, "msg": "Trabajador asignado: se resuelve en %d d." % int(f["dias_rep"])}


# ---------- Paso del tiempo ----------

## Se llama una vez por Sol. Devuelve los ids de eventos recién activados.
## Con `has_smoke_detector`, una emergencia en Marte se anuncia 1 Sol antes
## (queda en `pending_mars_id`) y se activa en el siguiente tick.
func tick_day(current_sol: int, has_smoke_detector: bool = false) -> Array:
	var triggered: Array = []

	# 0) Si había una emergencia anticipada, se activa hoy.
	if pending_mars_id != "":
		var pf := find_fault(pending_mars_id)
		if not pf.is_empty():
			pf["activa"] = true
			triggered.append(pending_mars_id)
		pending_mars_id = ""

	# 1) Avanzan las reparaciones terrestres (siguen aunque haya emergencia en Marte)
	for f in faults:
		if f["tipo"] == "tierra" and f["en_reparacion"]:
			f["restante"] = int(f["restante"]) - 1
			if int(f["restante"]) <= 0:
				f["restante"] = 0
				f["en_reparacion"] = false
				f["activa"] = false

	# 2) Enfriamiento de emergencias en Marte
	if mars_cooldown > 0:
		mars_cooldown -= 1

	# 3) Sorteo de fallas terrestres (cada una por separado)
	for f in faults:
		if f["tipo"] == "tierra" and not f["activa"] and randf() < float(f["prob"]):
			f["activa"] = true
			triggered.append(f["id"])

	# 4) Sorteo de emergencia en Marte: máx. UNA, nunca dos a la vez,
	#    ni en los primeros Soles, ni durante el enfriamiento.
	if current_sol > MARS_GRACE_SOLS and mars_cooldown == 0 and not has_mars_event() and pending_mars_id == "":
		var candidatas: Array = faults.filter(func(x): return x["tipo"] == "marte" and not x["activa"])
		candidatas.shuffle()
		for f in candidatas:
			if randf() < float(f["prob"]):
				if has_smoke_detector:
					pending_mars_id = str(f["id"])   # aviso previo, se activa mañana
				else:
					f["activa"] = true
					triggered.append(f["id"])
				break

	return triggered


## Solo para pruebas: fuerza un evento activo.
func force_activate(id: String) -> void:
	var f := find_fault(id)
	if not f.is_empty():
		f["activa"] = true
