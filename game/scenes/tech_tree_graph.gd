extends Control
# Scrollable visual dependency graph for the tech tree.
# Lay out nodes in horizontal category lanes; depth = column.

signal research_requested(node_id: String)

# Layout constants
const NODE_W    := 152.0
const NODE_H    := 56.0
const COL_W     := 186.0   # column pitch (node + gap)
const LANE_PAD  := 10.0    # padding inside each lane above/below nodes
const LANE_GAP  := 14.0    # gap between lanes
const MARGIN_X  := 78.0    # left margin (space for category labels)
const MARGIN_Y  := 18.0

# Category display order and tint colors
const CAT_ORDER := ["Energy", "Propulsion", "Science", "Governance", "Probes"]
const CAT_TINTS: Dictionary = {
	"Energy":     Color(0.90, 0.75, 0.10, 0.13),
	"Propulsion": Color(0.20, 0.50, 0.95, 0.13),
	"Science":    Color(0.55, 0.22, 0.90, 0.13),
	"Governance": Color(0.20, 0.80, 0.50, 0.13),
	"Probes":     Color(0.90, 0.48, 0.10, 0.13),
}

# Node status colours
const C_LOCKED    := Color(0.22, 0.22, 0.26)
const C_AVAILABLE := Color(0.15, 0.36, 0.62)
const C_ACTIVE    := Color(0.08, 0.52, 0.88)
const C_QUEUED    := Color(0.42, 0.20, 0.72)
const C_COMPLETE  := Color(0.13, 0.48, 0.18)

var _db: TechTreeDB
var _state: SimulationState
var _rects: Dictionary = {}        # node_id -> Rect2
var _lane_bands: Array = []        # [{cat, y, h}]
var _hovered_id: String = ""
var _layout_done := false

const STATE_LOCKED    := "locked"
const STATE_AVAILABLE := "available"
const STATE_ACTIVE    := "active"
const STATE_QUEUED    := "queued"
const STATE_COMPLETE  := "complete"


func setup(db: TechTreeDB) -> void:
	_db = db
	mouse_filter = MOUSE_FILTER_STOP


func refresh(state: SimulationState) -> void:
	_state = state
	if not _layout_done:
		_compute_layout()
		_layout_done = true
	queue_redraw()


# ── Layout ────────────────────────────────────────────────────────────────────

func _compute_layout() -> void:
	var all_nodes: Array = _db.get_all_nodes()

	# Compute topological depth (column) for each node
	var depth: Dictionary = {}
	for n: TechNode in all_nodes:
		depth[n.id] = 0
	var changed := true
	while changed:
		changed = false
		for n: TechNode in all_nodes:
			for prereq in n.prerequisites:
				var d: int = depth.get(prereq, 0) + 1
				if d > depth[n.id]:
					depth[n.id] = d
					changed = true

	# Group nodes by category
	var by_cat: Dictionary = {}
	for cat in CAT_ORDER:
		by_cat[cat] = []
	for n: TechNode in all_nodes:
		var cat: String = n.category
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(n)

	# Within each category sort by depth then name
	for cat in by_cat:
		by_cat[cat].sort_custom(func(a: TechNode, b: TechNode) -> bool:
			if depth[a.id] != depth[b.id]:
				return depth[a.id] < depth[b.id]
			return a.display_name < b.display_name
		)

	# Assign pixel positions lane by lane
	_rects.clear()
	_lane_bands.clear()
	var cy := MARGIN_Y
	var max_x := 0.0

	for cat in CAT_ORDER:
		var nodes: Array = by_cat.get(cat, [])
		if nodes.is_empty():
			continue

		# Count max stacking (nodes sharing a column) in this lane
		var per_col: Dictionary = {}
		for n: TechNode in nodes:
			var d: int = depth[n.id]
			per_col[d] = per_col.get(d, 0) + 1
		var max_stack := 1
		for d in per_col:
			max_stack = maxi(max_stack, per_col[d])

		var lane_h := max_stack * NODE_H + (max_stack - 1) * 6.0 + LANE_PAD * 2.0
		_lane_bands.append({"cat": cat, "y": cy, "h": lane_h})

		var col_rows: Dictionary = {}   # depth -> row counter
		for n: TechNode in nodes:
			var d: int = depth[n.id]
			var row: int = col_rows.get(d, 0)
			col_rows[d] = row + 1

			var x := MARGIN_X + d * COL_W
			var y := cy + LANE_PAD + row * (NODE_H + 6.0)
			_rects[n.id] = Rect2(Vector2(x, y), Vector2(NODE_W, NODE_H))
			max_x = maxf(max_x, x + NODE_W + MARGIN_X)

		cy += lane_h + LANE_GAP

	cy += MARGIN_Y
	custom_minimum_size = Vector2(max_x, cy)


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _state == null or _rects.is_empty():
		return

	var canvas_w := custom_minimum_size.x
	var font := ThemeDB.fallback_font

	# Lane background bands + category labels
	for band: Dictionary in _lane_bands:
		var cat: String = band["cat"]
		var by := float(band["y"])
		var bh := float(band["h"])
		var tint: Color = CAT_TINTS.get(cat, Color.TRANSPARENT)
		draw_rect(Rect2(0.0, by, canvas_w, bh), tint, true)
		draw_string(font, Vector2(4.0, by + bh * 0.5 + 5.0),
				cat, HORIZONTAL_ALIGNMENT_LEFT, MARGIN_X - 8.0, 11,
				Color(1.0, 1.0, 1.0, 0.45))

	# Edges (drawn before nodes so nodes appear on top)
	for n: TechNode in _db.get_all_nodes():
		if not _rects.has(n.id):
			continue
		var to_rect: Rect2 = _rects[n.id]
		var to_pt := Vector2(to_rect.position.x, to_rect.position.y + NODE_H * 0.5)
		var ns := _node_state(n)

		for prereq in n.prerequisites:
			if not _rects.has(prereq):
				continue
			var fr: Rect2 = _rects[prereq]
			var fr_pt := Vector2(fr.position.x + NODE_W, fr.position.y + NODE_H * 0.5)
			var col := Color(0.65, 0.65, 0.65, 0.55) if ns != STATE_LOCKED else Color(0.35, 0.35, 0.35, 0.40)
			_bezier(fr_pt, to_pt, col, 1.4)

	# Nodes
	for n: TechNode in _db.get_all_nodes():
		if not _rects.has(n.id):
			continue
		var rect: Rect2 = _rects[n.id]
		var ns := _node_state(n)
		var hover := n.id == _hovered_id

		# Background
		draw_rect(rect, _bg(ns), true)
		# Border (brighter + thicker on hover)
		draw_rect(rect, _border(ns, hover), false, 2.2 if hover else 1.4)

		# Tech name
		var name_col := Color(1.0, 1.0, 1.0, 1.0) if ns != STATE_LOCKED else Color(0.55, 0.55, 0.55)
		draw_string(font, rect.position + Vector2(6.0, 17.0),
				n.display_name, HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 12.0, 12, name_col)

		# Sub-line (cost / status)
		draw_string(font, rect.position + Vector2(6.0, 33.0),
				_sub_text(n, ns), HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 12.0, 10, _sub_col(ns))

		# Progress bar for the active node
		if ns == STATE_ACTIVE and n.research_cost > 0.0:
			var pct := clampf(_state.research_progress / n.research_cost, 0.0, 1.0)
			var bar_y := rect.position.y + NODE_H - 9.0
			draw_rect(Rect2(rect.position.x + 4.0, bar_y, NODE_W - 8.0, 5.0),
					Color(0.25, 0.25, 0.35, 0.9), true)
			draw_rect(Rect2(rect.position.x + 4.0, bar_y, (NODE_W - 8.0) * pct, 5.0),
					Color(0.15, 0.78, 1.0, 0.95), true)


func _bezier(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var mx := (a.x + b.x) * 0.5
	var pts := PackedVector2Array()
	for i in 16:
		var t := float(i) / 15.0
		var u := 1.0 - t
		# cubic bezier with control points at mid-x, same y as endpoints
		var p := u*u*u*a + 3.0*u*u*t*Vector2(mx, a.y) + 3.0*u*t*t*Vector2(mx, b.y) + t*t*t*b
		pts.append(p)
	draw_polyline(pts, col, w, true)


# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		if h != _hovered_id:
			_hovered_id = h
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked := _hit(event.position)
			if clicked != "":
				var n := _db.get_node(clicked)
				if n and _node_state(n) == STATE_AVAILABLE:
					research_requested.emit(clicked)


func _hit(pos: Vector2) -> String:
	for nid in _rects:
		if (_rects[nid] as Rect2).has_point(pos):
			return nid
	return ""


# ── State / color helpers ─────────────────────────────────────────────────────

func _node_state(n: TechNode) -> String:
	if n.id in _state.completed_research:   return STATE_COMPLETE
	if _state.active_research == n.id:      return STATE_ACTIVE
	if n.id in _state.research_queue:       return STATE_QUEUED
	if _db.is_available(n.id, _state.completed_research, _state.milestone_flags):
		return STATE_AVAILABLE
	return STATE_LOCKED


func _bg(ns: String) -> Color:
	match ns:
		STATE_COMPLETE:  return C_COMPLETE
		STATE_ACTIVE:    return C_ACTIVE
		STATE_QUEUED:    return C_QUEUED
		STATE_AVAILABLE: return C_AVAILABLE
		_:               return C_LOCKED


func _border(ns: String, hover: bool) -> Color:
	var base: Color
	match ns:
		STATE_COMPLETE:  base = Color(0.30, 0.90, 0.35)
		STATE_ACTIVE:    base = Color(0.30, 0.80, 1.00)
		STATE_QUEUED:    base = Color(0.75, 0.45, 1.00)
		STATE_AVAILABLE: base = Color(0.40, 0.70, 1.00)
		_:               base = Color(0.40, 0.40, 0.45)
	return base.lightened(0.3) if hover else base


func _sub_text(n: TechNode, ns: String) -> String:
	match ns:
		STATE_COMPLETE:  return "✓ Complete"
		STATE_ACTIVE:
			if n.research_cost > 0.0 and _state.research_rate > 0.0:
				var yrs := (_state.research_progress / _state.research_rate)
				var rem := ((n.research_cost - _state.research_progress) / _state.research_rate)
				return "%.0f / %.0f pts  (~%.1f yr)" % [_state.research_progress, n.research_cost, rem]
			return "In progress…"
		STATE_QUEUED:    return "Queued"
		STATE_AVAILABLE:
			if n.research_cost == 0.0:
				return "Political action"
			if _state.research_rate > 0.0:
				var yrs := n.research_cost / _state.research_rate
				return "%.0f pts  (~%.1f yr)" % [n.research_cost, yrs]
			return "%.0f pts" % n.research_cost
		_:
			var missing: Array = []
			for p in n.prerequisites:
				if not p in _state.completed_research:
					var pn := _db.get_node(p)
					missing.append(pn.display_name if pn else p)
			if missing.size() > 0:
				return "Needs: " + ", ".join(missing)
			return "Locked"


func _sub_col(ns: String) -> Color:
	match ns:
		STATE_COMPLETE:  return Color(0.55, 0.95, 0.55)
		STATE_ACTIVE:    return Color(0.65, 0.90, 1.00)
		STATE_QUEUED:    return Color(0.80, 0.65, 1.00)
		STATE_AVAILABLE: return Color(0.75, 0.85, 1.00)
		_:               return Color(0.50, 0.50, 0.52)
