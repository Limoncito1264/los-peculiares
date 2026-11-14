class_name SpacecraftPart
extends Resource

enum Category { LAUNCH_VEHICLE, PROPULSION, POWER_SYSTEM, SCIENCE_INSTRUMENT }

@export var part_name: String = "Nuevo Componente"
@export var category: Category = Category.PROPULSION
@export_multiline var description: String = ""

@export_group("Trade-offs de Ingeniería")
@export var budget_cost: int = 100         # Impacto en el presupuesto
@export var mass_kg: float = 250.0         # Impacto en la masa total
@export var power_balance: float = -10.0   # Negativo = consume energía, Positivo = genera
@export var science_value: int = 0         # Puntos de objetivos científicos
@export var build_days_required: int = 5   # Tiempo base de construcción en la Tierra
