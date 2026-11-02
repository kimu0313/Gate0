class_name Terminal
extends Node3D
## Procedurally builds the SEOHAE International Airport terminal and exposes its systems.
##
## Layout from the level plan (Downloads/image (9).png, 2 m grid, drawn with the airside at the bottom); the hall
## is the main lounge of the lounge reference (SKETCH_SHOTS ref_lounge). Metres, Y up, -Z = north/airside, +X = east:
##   HALL (main lounge) x[-20,44] z[-2.5,52] (9 m, a soffit rising to 18 m at the glass facade on the apron to the
##                south, four rows of columns with ad screens, an airliner through the glass) + its north strip
##                x[-12.2,12] z[-8.5,-2.5]
##   2F       the lounge's upper floor (MEZZ_Y): a gallery of one width on three sides round its atrium (UPPER), the
##            staff doors in its north wall, two pairs of escalators from its edge down into the atrium; the shops
##            behind its three walls (Shops: eight empty units of different sizes, the biggest facing the escalators)
##   OFFICE   x[-20,-12.2] z[-2.5,7.6]    STORAGE x[12,22] z[-8.5,-2.5]
##   SECURITY OFFICE (보안실) x[-20,-12.4] z[-21,-11], its door on the staff passage's west wall at z -16
##   SECURITY x[-10,10] z[-27.3,-8.5]     CORRIDOR x[-10,10] z[-76,-27.3] (walkways on its east side)
##   BAGGAGE  x[-36,-10] z[-64,-39.6] + staff passage x[-12.4,-10] z[-39.6,-8.5] from the strip (open from DAY 2,
##            before security; the public opening from the corridor opens with the corridor)
##   MAINT    x[-48,-36] z[-53,-47]       GATES x[-26,26] z[-100,-76]       GATE 0 bridge x[-1.3,1.3] z[-128,-100]
##   AIRCRAFT HALL x[-74,-26] z[-24,62] (AirHall: a floor below the lounge, an airliner parked in it, decks along
##            its east side) — the way in is CABIN WAY (CabinWay) x[-23.7,-20.3] z[25.9,51.5] behind the lounge's 1F west
##            wall, its door at z 27.5; through its haze you come out of a cabin section on the hall's deck at z -24..-20

const HALL_H := 12.0         # main lounge: flat ceiling over its north half (over the 2F)
const HALL_ROOF := 21.0      # ...then a soffit rising to the head of the glass facade
const HALL_E := 44.0         # the lounge's east end wall
const HALL_S := 52.0         # glass facade on the apron (south)
const ROOF_Z := 22.0         # where the soffit starts rising (the third column row)
const COL_X := [-6.0, 3.0, 12.0, 21.0, 30.0]   # lounge column grid (1.3 m square columns) on four rows; the east bay
const COL_Z := [4.0, 11.0, 22.0, 33.0]          # is clear, and only the grid's edge has columns (lounge_columns)
const AISLES := [7.5, 27.5]  # the two aisles along the hall (z), between the column rows 4|11 and 22|33
const MEZZ_Y := 4.2          # the lounge's 2F floor
const SLAB := 0.35           # its thickness (the lounge's ceiling under it at MEZZ_Y - SLAB)
## The 2F over the lounge, an empty floor for what comes later: plates [x0, z0, x1, z1] round the ATRIUM (open from
## the lounge floor to the roof over the middle and the glass side, where the airliner lies). The 2F wraps the lounge
## like a ㄷ, a gallery 7.8 m wide from the walls on all three sides: the north side the length of the hall, the east
## and west sides down to the glass. No column stands on the 2F.
const UPPER := [[-19.9, -2.4, 43.9, 5.5], [-19.9, 5.5, -12.0, 51.85], [36.0, 5.5, 43.9, 51.85]]
const ATRIUM := Rect2(-12.0, 5.5, 48.0, 46.35)
## Two pairs of escalators (an up and a down side by side, ESC_GAP apart) from the 2F's edge down into the atrium,
## toward the airliner (south): the pairs' centres and the lower working points' z. The down one of each pair is the
## one nearer the staff doors.
const ESC_X := [6.0, 18.0]
const ESC_FOOT_Z := 13.8
const ESC_GAP := 1.66
## The terminal's light at night (the abandoned-hall reference): a cold, slightly cyan white. Every zone's panels and
## the lights that take the zone's colour (LightZone) are this; screens and signs keep their own. FILL_LIGHT is the
## colour of the dim omnis that stand in for bounce light: the teal the haze turns everything.
const ZONE_LIGHT := Color(0.84, 0.95, 1.0)
const FILL_LIGHT := Color(0.62, 0.86, 0.92)
const DESK_AT := Vector3(-9.0, 0, 7.5)     # the broadcast desk's middle, at the far (west) end of the aisle
const DECK_DOOR := Vector3(32.0, 4.2, -2.5)   # the staff double doors in the 2F's north wall (MEZZ_Y), facing the
                                              # atrium; the service corridor comes out here in the main story
## The airliner that came down on the apron and slid into the lounge (Props.aircraft frame: nose +Z): its length, the
## frame's origin, heading (north-west, 50° off square to the glass) and roll onto its near (right) wing, so the nose
## and that wing with its engine have broken through the facade.
const WRECK_LEN := 50.0
const WRECK_AT := Vector3(22.0, -1.9, 58.1)
const WRECK_YAW := -2.27
const WRECK_ROLL := 0.2
const WRECK_PITCH := 0.05
const STRIP_H := 3.65       # the strip's and security's ceilings, under the 2F's slab height (MEZZ_Y - SLAB)
const SEC_H := 3.5
const COR_H := 4.5
const BAG_H := 3.6
const LANE_X := [-4.8, 3.25]  # X-ray tunnel centres (lane 1 west, lane 2 east), metal detector 3.6 m east of each
const LANE_Z := -18.0
const MD_DX := 3.6
const BELT_POS := Vector3(-25.5, 0, -59.0)
## The floor point at the far end of the dark vestibule outside the security office's west door, the way in: the
## main story's boarding-bridge gate door lands here (Chapter1's portal; +X = on into the office).
const SEC_ENTRY_PLANE := Vector3(-22.0, 0, -14.6)

## Zone footprints (one Rect2 or an Array of them). Checked in this order by zone_at, so rooms inside the hall's
## rect (the office) come first.
const ZONE_RECTS := {
	"office": Rect2(-20, -2.5, 7.8, 10.1),
	"secoffice": Rect2(-20, -21, 7.6, 10),
	"hall": [Rect2(-20, -2.5, 64, 54.5), Rect2(-12.2, -8.5, 24.2, 6)],
	"storage": Rect2(12, -8.5, 10, 6),
	"security": Rect2(-10, -27.3, 20, 18.8),
	"corridor": Rect2(-10, -76, 20, 48.7),
	"baggage": [Rect2(-36, -64, 26, 24.4), Rect2(-12.4, -39.6, 2.4, 31.1)],
	"maint": Rect2(-48, -53, 12, 6),
	"gates": Rect2(-26, -100, 52, 24),
	"bridge0": Rect2(-1.5, -130, 3, 30),
	# the aircraft hall west of the lounge (AirHall.RECT) and the cabin that is the way in: behind the lounge's west wall
	# (CabinWay.cabin_rect, out to the wall's middle) and its section on the hall's landing (CabinWay.stub_rect)
	"cabin": [Rect2(-23.75, 25.9, 3.75, 25.6), Rect2(-31.45, -24.0, 3.5, 4.0)],
	"airhall": Rect2(-74, -24, 48, 86),
}
const ZONE_NAMES := {
	"office": "시설관리실", "hall": "메인 라운지", "baggage": "수하물 수취", "storage": "자재창고",
	"servicehall": "관리동 복도",
	"maint": "정비 통로", "security": "보안검색", "corridor": "탑승동 통로", "gates": "탑승 게이트",
	"bridge0": "0번 탑승교", "outside": "외부", "jetbridge": "위치 불명", "warped": "위치 불명", "secoffice": "보안실",
	"airhall": "항공기 전시홀", "cabin": "기내",
}

## Named floor points the story scripts, the NPC and the debug bots use instead of their own coordinates.
const SPOTS := {
	# documents and the furniture they lie on
	"doc_log1": Vector3(-14.6, 0.77, 6.9), "log1_desk": Vector3(-14.6, 0.38, 6.95),
	"doc_memo_worker": Vector3(-8.5, 1.01, 6.85),
	"doc_log3": Vector3(20.8, 0.49, -94.6),
	"doc_timecard": Vector3(-14.6, 0.93, -2.05), "timecard_shelf": Vector3(-14.6, 0.9, -2.15),
	"plaque": Vector3(11.45, 0.0, -7.95),     # rusted memorial in the strip's dead-end corner by the storage door
	# DAY 1 rule pages, collected where each facility is (p.9 comes in on the office fax)
	"page_p2": Vector3(-19.79, 1.45, 10.0), "page_p3": Vector3(-6.62, 1.45, -2.293),
	"page_p4": Vector3(-8.81, 1.0, 8.23), "page_p9": Vector3(-13.0, 0.802, 5.86),
	# evening-shift colleague posts (DAY 1–5)
	"npc_office": Vector3(-16.0, 0, 1.2), "npc_b03": Vector3(-33.2, 0, -55.4), "npc_xray": Vector3(-2.3, 0, -16.4),
	"npc_wing": Vector3(2.6, 0, -25.4), "npc_info": Vector3(-10.35, 0, 9.8),
	# wing door card reader (DAY 4–5), passenger-lane metal detectors
	"wing_reader": Vector3(4.7, 1.25, -27.08),
	"md_west": Vector3(-1.2, 0, -18.0), "md_east": Vector3(6.85, 0, -18.0),
	# where a person stands to work each panel (feet) and what they look at
	"view_lights": Vector3(-18.4, 0.05, 8.9), "look_lights": Vector3(-19.78, 1.45, 8.9),
	"view_fids": Vector3(0.0, 0.05, 6.5), "look_fids": Vector3(0.0, 5.8, -2.3),
	"view_pa": Vector3(-9.95, 0.05, 7.5), "look_pa": Vector3(-8.8, 1.0, 7.5),
	"view_baggage": Vector3(-34.3, 0.05, -57.4), "look_baggage": Vector3(-25.5, 0.6, -59.0),
	"view_walkway": Vector3(1.2, 0.05, -28.4), "look_walkway": Vector3(3.4, 0.2, -40.0),
	"view_xray": Vector3(-2.35, 0.05, -18.0), "look_xray": Vector3(-3.4, 1.24, -18.0),
	"view_punch": Vector3(-15.3, 0.05, -1.0), "look_punch": Vector3(-15.3, 1.35, -2.3),
	"view_breaker": Vector3(-13.3, 0.05, -1.0), "look_breaker": Vector3(-13.3, 1.5, -2.3),
	"office_inside": Vector3(-16.0, 0.05, 2.5), "office_look": Vector3(-19.6, 1.0, 2.5),
	# control stands (the green diamond points here for a facility's first inspection)
	"b03_controls": Vector3(-33.6, 1.25, -57.4), "mw1_controls": Vector3(1.2, 1.25, -29.6),
	# DAY 1 arrival: in the hall, up to the office door's card reader, through the door and a few steps inside
	"office_entry": Vector3(-15.2, 0.05, 11.4), "reader_stand": Vector3(-16.95, 0.05, 8.5),
	"office_door_front": Vector3(-17.9, 0.05, 8.35), "office_doorway": Vector3(-18.1, 0.05, 6.7),
	"office_arrive": Vector3(-17.9, 0.05, 5.2),
	"entrance_out": Vector3(-7.8, 0, 54.8),
	"cut_arrivals": Vector3(38.5, 0.05, 9.5),
	"boarding_hold": Vector3(-1.5, 0.05, -62.0), "boarding_look": Vector3(-1.5, 1.6, -40.0),
	"exit_inside": Vector3(-17.0, 0.05, 49.5), "exit_look": Vector3(-17.0, 1.5, 52.0),
	"exit_outside": Vector3(-17.0, 0.05, 54.0), "exit_out_look": Vector3(-17.0, 1.5, 58.0),
	"lounge_start": Vector3(42.5, 0.05, 30.0),    # `--lounge`: the east end of the south aisle, looking west
	"airhall_start": Vector3(-29.35, 0.05, -18.5), # `--airhall`: the aircraft hall's deck by its escalator's foot
	"cabinway_front": Vector3(-16.5, 0.05, 27.5), # `--cabinway`: the lounge's south aisle before the cabin's door
}
## Views matching the sketches: [name, eye, yaw (deg, 0 = -Z), vanishing point (fraction of the image), vertical fov]
## (debug/level_shots.gd, `-- --level-shots <dir>` on the game scene; render at the sketch's aspect). ref_lounge is
## the main lounge reference (dark hall seen from its east end down the aisle; render 1536x1024).
const SKETCH_SHOTS := [
	["ref_lounge", Vector3(43.0, 1.65, 31.0), 90.0, Vector2(0.495, 0.59), 77.0],
	["lounge_north", Vector3(42.5, 1.65, 8.2), 90.0, Vector2(0.495, 0.59), 77.0],
	["lounge_crash", Vector3(35.0, 1.65, 28.0), 140.0, Vector2(0.5, 0.56), 74.0],
	["lounge_nose", Vector3(9.0, 1.65, 33.0), 160.0, Vector2(0.5, 0.55), 72.0],
	["lounge_west", Vector3(-6.0, 1.65, 27.5), -90.0, Vector2(0.5, 0.55), 72.0],
	# the service corridor (ServiceHall at (-160, -320, 0); built for the main story: run these with `--chapter ch1`)
	["hall_ref", Vector3(-159.8, -318.38, 1.4), 180.0, Vector2(0.5, 0.53), 60.0],
	["hall_far", Vector3(-160.3, -318.38, 30.0), 180.0, Vector2(0.5, 0.53), 62.0],
	["hall_back", Vector3(-160.0, -318.38, 40.0), 0.0, Vector2(0.5, 0.53), 66.0],
	["deck_arrive", Vector3(32.0, 5.85, -0.9), 180.0, Vector2(0.5, 0.66), 74.0],
	["upper_back", Vector3(12.0, 5.85, 5.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["upper_ring", Vector3(40.0, 5.85, 50.0), 25.0, Vector2(0.5, 0.55), 74.0],
	["escalators_1f", Vector3(12.0, 1.65, 31.0), 0.0, Vector2(0.5, 0.55), 72.0],
	["upper_north", Vector3(42.0, 5.85, 1.6), 90.0, Vector2(0.5, 0.55), 74.0],
	["upper_west", Vector3(-16.0, 5.85, 46.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["atrium_from_2f", Vector3(-13.5, 5.85, 24.0), -110.0, Vector2(0.5, 0.62), 74.0],
	["escalator_down", Vector3(18.83, 5.85, 3.9), 180.0, Vector2(0.5, 0.62), 72.0],
	# the 2F's empty shop units (Shops): down the west and east galleries, then each unit from its opening (n2, the big
	# one, from the escalators' tops and inside)
	["shops_west", Vector3(-13.0, 5.85, 46.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["shops_east", Vector3(37.0, 5.85, 46.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["unit_n1", Vector3(-16.1, 5.85, 4.0), 0.0, Vector2(0.5, 0.55), 72.0],
	["unit_n2", Vector3(12.6, 5.85, 4.6), 0.0, Vector2(0.5, 0.58), 74.0],
	["unit_n2_in", Vector3(12.6, 5.85, -3.5), 0.0, Vector2(0.5, 0.56), 74.0],
	["unit_n3", Vector3(39.5, 5.85, 4.5), 0.0, Vector2(0.5, 0.55), 74.0],
	["unit_w1", Vector3(-15.8, 5.85, 3.1), 90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e1", Vector3(39.5, 5.85, 5.5), -90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e2", Vector3(39.5, 5.85, 17.0), -90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e3_in", Vector3(44.6, 5.85, 31.0), -90.0, Vector2(0.5, 0.55), 74.0],
	# the way in (CabinWay): its door from the lounge's south aisle, the cabin from the door looking forward (the cabin
	# reference), deeper into the haze, at the join (all haze); out of it in the hall's section (all haze), stepping
	# out of its cut end, and the section from the deck
	["cabinway_door", Vector3(-12.0, 1.65, 27.5), 90.0, Vector2(0.5, 0.55), 70.0],
	["cabinway_ref", Vector3(-21.65, 1.65, 28.4), 180.0, Vector2(0.49, 0.28), 70.0],
	["cabinway_deep", Vector3(-21.65, 1.65, 45.5), 180.0, Vector2(0.5, 0.4), 70.0],
	["cabinway_join", Vector3(-21.65, 1.65, 49.3), 180.0, Vector2(0.5, 0.5), 70.0],
	["stub_join", Vector3(-29.35, 1.65, -21.8), 180.0, Vector2(0.5, 0.5), 70.0],
	["stub_out", Vector3(-29.35, 1.65, -20.3), 170.0, Vector2(0.5, 0.45), 70.0],
	["stub_mouth", Vector3(-27.2, 1.65, -9.0), -12.0, Vector2(0.5, 0.55), 70.0],
	# the aircraft hall (AirHall) west of the lounge: the reference view (the deck's north end by the escalator's foot,
	# the airliner beyond the parapet), from the 2F deck, along the deck
	["air_ref", Vector3(-29.35, 1.65, -18.5), 160.0, Vector2(0.5, 0.5), 75.0],     # what the player sees (fov 75)
	["air_photo", Vector3(-29.35, 1.65, -18.5), 163.0, Vector2(0.5, 0.38), 66.0],     # framed like the photo (portrait)
	["air_plane", Vector3(-33.0, -4.4, 2.0), 100.0, Vector2(0.5, 0.5), 50.0],     # the airliner from the deck's edge
	["air_2f", Vector3(-28.0, 5.85, 30.5), 52.0, Vector2(0.5, 0.6), 72.0],
	["air_deck", Vector3(-27.4, 1.65, 6.0), 130.0, Vector2(0.5, 0.56), 72.0],
	# the security office (run with --prologue): from the start, the room toward the CCTV room, the CCTV room from its
	# doorway and from its chair, the island from the east, the south end from the north
	["sec_start", Vector3(-16.2, 1.6, -11.75), 0.0, Vector2(0.5, 0.52), 70.0],
	["sec_cctv", Vector3(-15.0, 1.6, -13.6), 52.0, Vector2(0.5, 0.55), 70.0],
	["sec_booth", Vector3(-17.9, 1.6, -16.3), 35.0, Vector2(0.5, 0.52), 74.0],
	["sec_cctv_chair", Vector3(-18.3, 1.25, -18.55), 90.0, Vector2(0.5, 0.42), 72.0],
	["sec_island", Vector3(-13.3, 1.6, -15.2), 60.0, Vector2(0.5, 0.55), 70.0],
	["sec_south", Vector3(-15.4, 1.6, -19.6), 170.0, Vector2(0.5, 0.55), 72.0],
]
const SHOTS := []
## Walk graph for people crossing the terminal (straight segments clear of counters, pillars and carousels).
const NAV := {
	"office": [Vector3(-16.0, 0, 2.5), ["office_door_in"]],
	"office_door_in": [Vector3(-18.2, 0, 6.2), ["office", "office_door_out"]],
	"office_door_out": [Vector3(-18.2, 0, 9.2), ["office_door_in", "hall_sw"]],
	"hall_sw": [Vector3(-11.0, 0, 10.0), ["office_door_out", "entrance_in", "hall_s"]],
	"entrance_in": [Vector3(-7.8, 0, 50.4), ["hall_sw"]],
	"hall_s": [Vector3(-4.8, 0, 12.3), ["hall_sw", "hall_c"]],
	"hall_c": [Vector3(-1.5, 0, 7.5), ["hall_s", "desk_s", "hall_w"]],
	"desk_s": [Vector3(-7.6, 0, 9.6), ["hall_c", "hall_ne"]],
	"hall_w": [Vector3(-2.6, 0, 1.0), ["hall_c", "hall_n"]],
	"hall_ne": [Vector3(2.7, 0, 1.2), ["desk_s", "strip_c"]],
	"hall_n": [Vector3(-2.6, 0, -1.6), ["hall_w", "strip_c", "strip_w"]],
	"strip_c": [Vector3(1.1, 0, -5.5), ["hall_n", "hall_ne", "strip_w", "sec_in"]],
	"strip_w": [Vector3(-11.2, 0, -6.2), ["hall_n", "strip_c", "pass_in"]],
	"sec_in": [Vector3(1.1, 0, -10.0), ["strip_c", "sec_mid"]],
	"sec_mid": [Vector3(1.1, 0, -17.0), ["sec_in", "sec_out", "xray_post"]],
	"xray_post": [Vector3(-2.3, 0, -16.4), ["sec_mid"]],
	"sec_out": [Vector3(1.1, 0, -26.0), ["sec_mid", "cor_s"]],
	"cor_s": [Vector3(-1.5, 0, -29.0), ["sec_out", "cor_bag"]],
	"cor_bag": [Vector3(-1.5, 0, -49.0), ["cor_s", "cor_n", "bag_e"]],
	"cor_n": [Vector3(-1.5, 0, -66.0), ["cor_bag", "gates_in"]],
	"gates_in": [Vector3(0.0, 0, -78.5), ["cor_n"]],
	"pass_in": [Vector3(-11.2, 0, -10.0), ["strip_w", "pass_out"]],
	"pass_out": [Vector3(-11.2, 0, -40.5), ["pass_in", "bag_ne"]],
	"bag_ne": [Vector3(-14.0, 0, -43.0), ["pass_out", "bag_e", "bag_mid"]],
	"bag_e": [Vector3(-12.0, 0, -49.0), ["bag_ne", "cor_bag", "bag_mid"]],
	"bag_mid": [Vector3(-21.0, 0, -55.0), ["bag_ne", "bag_e", "bag_ped"]],
	"bag_ped": [Vector3(-33.2, 0, -55.4), ["bag_mid"]],
}

static var current: Terminal

var zones := {}            # name -> LightZone
var facilities := {}       # id -> Facility
var gates := {}            # "01".."04","0" -> BoardingGate
var shutters := {}         # name -> Shutter
var doors := {}            # name -> SlidingDoor
var readers := {}          # name -> CardReader
var signs := {}            # name -> Array[Label3D]
var pickups := {}          # id -> Pickup
var spawns := {}           # name -> Transform3D
var triggers := {}         # name -> Area3D
var lights_panel: LightPanel
var sec_door: Node3D              # the security office's steel door on the staff passage (_build_security_office)
var sec_signs: Array[Node3D] = [] # its plate beside it and the SECURITY OFFICE sign over the passage
var sec_passage: Dictionary        # the same door as {root, leaf, block, use} (rattle / swing_door)
var sec_entry: Dictionary          # the office's west door (OfficeKit.door), locked; past it a dark vestibule
var sec_closet: Dictionary         # the store-room door in the north wall, locked
var sec_reader: CardReader         # by the passage door, room side; off until the story wants it
var sec_drawers := {}              # a1..a3 CRT desk, c1..c3 the guard's desk, f1..f4 filing, l1..l4 lateral
var sec_vestibule_end: MeshInstance3D   # the far wall of the dark vestibule outside the west door
var sec_leaf: Node3D              # its leaf, a hinge node: rotation.y > 0 swings it into the room
var sec_block: StaticBody3D       # the shut leaf's collider
var sec_use: Interactable         # [E] on the door from either side; the story sets its prompt and callback
## Props the main story's warped airport moves (WarpedTerminal): kiosks, the broadcast desk, the lobby benches, the
## gate seat rows, the aircraft on the apron and the control tower.
var warp := {"kiosks": [], "benches": [], "gate_seats": [], "aircraft": [], "desk": null, "tower": null}
var lights_panel_gates: LightPanel
var breaker: BreakerPanel
var punch_clock: Interactable
var keypad: Interactable
var main_power: Interactable
var exit_door_use: Interactable
var syslog_terminal: Interactable
var gate0_wall: Node3D
var gate0_parts: Node3D
var final_plane: Node3D
var outside_lights: Array[Light3D] = []
var exit_signs: Array[MeshInstance3D] = []
var arrivals: FidsBoard
var emergency_light_root: Node3D
var wreck: Node3D          # the airliner that came in through the lounge glass (_wreck)
var lounge_door: Dictionary   # the staff double doors in the lounge's east wall (ServiceHall.double_door), locked
var _ceilings: Array = []  # [Rect2, y] of every ceiling, for _ceiling_details()
var _probes := {}          # zone -> ReflectionProbe (faded with the zone's lights)
var air_haze: FogMaterial  # the aircraft hall's haze, glowing with its zone's lights (AirHall.HAZE_GLOW)


func build() -> void:
	current = self
	_build_zones()
	_build_office()
	_build_hall()
	_build_upper_floor()
	AirHall.build(self)
	CabinWay.build(self)
	_build_baggage()
	_build_security_office()
	_build_security()
	_build_corridor()
	_build_gates()
	_build_service_rooms()
	_build_outside()
	_build_facility_systems()
	_ceiling_details()
	_build_probes()
	_build_reverb()
	_define_spawns()
	# no light here casts shadows: none but the cabins' own may reach in there (Airliner.VIS_CABIN)
	for l: Light3D in find_children("*", "Light3D", true, false):
		if l.light_cull_mask != Airliner.VIS_CABIN:
			l.light_cull_mask &= ~Airliner.VIS_CABIN
	var fitted := Geo.fit_labels(self, OS.get_cmdline_user_args().has("--tour"))
	if OS.get_cmdline_user_args().has("--tour"):
		print("fit_labels: shrank %d world labels to their signs" % fitted)


## Every footprint of a zone (ZONE_RECTS holds one Rect2 or several).
static func zone_rects(zn: String) -> Array:
	var r: Variant = ZONE_RECTS[zn]
	return r if r is Array else [r]


## The escalators down into the atrium: [foot (the lower working point), down] for each of the four units.
static func escalator_units() -> Array:
	var out := []
	for xc: float in ESC_X:
		var inner := signf(DECK_DOOR.x - xc)
		for k: float in [-1.0, 1.0]:
			out.append([Vector3(xc + k * ESC_GAP * 0.5, 0, ESC_FOOT_Z), k == inner])
	return out


## Where each pair of escalators meets the lounge floor (the middle of its two feet).
static func escalator_feet() -> Array:
	return ESC_X.map(func(xc: float) -> Vector3: return Vector3(xc, 0, ESC_FOOT_Z))


## The floor each pair of escalators stands over, from the 2F's edge to past its out-of-service clutter, `grow`n.
static func escalator_rects(grow := 0.0) -> Array:
	return ESC_X.map(func(xc: float) -> Rect2:
		return Rect2(xc - ESC_GAP * 0.5 - 0.82, ATRIUM.position.y, ESC_GAP + 1.64, ESC_FOOT_Z + 4.0 - ATRIUM.position.y).grow(grow))


static func _under_escalator(p: Vector3, grow := 0.0) -> bool:
	for r: Rect2 in escalator_rects(grow):
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


## A named point from SPOTS.
func spot(name_text: String) -> Vector3:
	assert(SPOTS.has(name_text), "Terminal spot " + name_text)
	return SPOTS[name_text]


## Floor points from `from` to the NAV node `goal`: the nearest node first, then the shortest way along the graph.
func route(from: Vector3, goal: String) -> Array:
	var start := ""
	var best := INF
	for k in NAV.keys():
		var d := Vector2(from.x, from.z).distance_to(Vector2(NAV[k][0].x, NAV[k][0].z))
		if d < best:
			best = d
			start = k
	var dist := {start: 0.0}
	var prev := {}
	var open := [start]
	while not open.is_empty():
		var cur: String = open[0]
		for o in open:
			if dist[o] < dist[cur]:
				cur = o
		open.erase(cur)
		if cur == goal:
			break
		for nb: String in NAV[cur][1]:
			var nd: float = dist[cur] + (NAV[cur][0] as Vector3).distance_to(NAV[nb][0])
			if nd < dist.get(nb, INF):
				dist[nb] = nd
				prev[nb] = cur
				open.append(nb)
	var pts: Array = []
	var k: String = goal
	while true:
		pts.push_front(NAV[k][0])
		if k == start or not prev.has(k):
			break
		k = prev[k]
	return pts


# --------------------------------------------------------------------------------------------
func _build_zones() -> void:
	var defs := [
		["office", "사무실", 2.6],
		["secoffice", "보안실", 2.6],
		["hall", "홀", 3.4],
		["baggage", "수하물", 3.0],
		["security", "보안검색", 3.0],
		["corridor", "통로", 3.0],
		["gates", "게이트", 3.0],
		["service", "보관·정비", 2.0],
		["shops", "상가", 2.8],
		["airhall", "항공기 전시홀", 3.4, AirHall.LIGHT],
	]
	for d in defs:
		var z := LightZone.new()
		z.name = "Zone_" + d[0]
		add_child(z)
		z.setup(d[0], d[1], d[3] if d.size() > 3 else ZONE_LIGHT, d[2])
		zones[d[0]] = z


func _floor(rect: Rect2, mat_name: String) -> void:
	Geo.box(self, Vector3(rect.position.x + rect.size.x * 0.5, -0.05, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x, 0.1, rect.size.y), Mats.get_mat(mat_name))


## Ceiling slab over `rect` (its edges end inside the walls, which stand on the rect lines), lifted 3 mm so it never
## shares a plane with wall tops, lintels above openings or the walls' outer faces (z-fighting).
func _ceiling(rect: Rect2, y: float, mat_name := "ceiling") -> void:
	Geo.box(self, Vector3(rect.position.x + rect.size.x * 0.5, y + 0.103, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x, 0.2, rect.size.y), Mats.get_mat(mat_name), false)
	_ceilings.append([rect, y])


## Ceiling furniture (sprinkler heads, square air diffusers) on every ceiling, kept clear of the
## light fixtures. Runs after all zones are built so it can see where the panels went.
func _ceiling_details() -> void:
	var avoid: Array[AABB] = []
	for zn in zones:
		for p in (zones[zn] as LightZone).panels:
			avoid.append(AABB(p.position - (p.mesh as BoxMesh).size * 0.5, (p.mesh as BoxMesh).size).grow(0.7))
	var sprinklers: Array[Transform3D] = []
	var diffusers: Array[Transform3D] = []
	for c in _ceilings:
		var rect: Rect2 = c[0]
		var y: float = c[1]
		var x := rect.position.x + 1.5
		while x < rect.end.x - 0.5:
			var zz := rect.position.y + 1.5
			while zz < rect.end.y - 0.5:
				var at := Vector3(x, y, zz)
				var clear := true
				for a in avoid:
					if a.has_point(at - Vector3(0, 0.05, 0)):
						clear = false
						break
				if clear:
					var diffuser := int(roundf(x / 3.0) + roundf(zz / 3.0)) % 3 == 0
					(diffusers if diffuser else sprinklers).append(Transform3D(Basis(), at))
				zz += 3.0
			x += 3.0
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.045
	sm.height = 0.05
	sm.radial_segments = 10
	_multi(sm, Mats.get_mat("metal"), sprinklers, Vector3(0, -0.025, 0))
	var dm := BoxMesh.new()
	dm.size = Vector3(0.6, 0.03, 0.6)
	_multi(dm, Mats.get_mat("plastic_white"), diffusers, Vector3(0, -0.012, 0))
	var vm := BoxMesh.new()
	vm.size = Vector3(0.36, 0.01, 0.36)
	_multi(vm, Mats.get_mat("plastic_grey"), diffusers, Vector3(0, -0.03, 0))


func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D], offset: Vector3) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i].translated(offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


# --------------------------------------------------------------------------------------------
## Facility office, west end of the lobby; its door opens south into the lobby beside the lighting panel.
func _build_office() -> void:
	var r: Rect2 = ZONE_RECTS.office
	_floor(r, "floor_office")
	_ceiling(r, 3.2, "ceiling")
	var wm := Mats.get_mat("wall_office")
	var hw := Mats.get_mat("wall")
	# the office is a room under the lounge's 2F: its walls stop under the 2F (into its slab; the 2F's own walls, with
	# the shops' fronts in them, stand on its west and north walls)
	Geo.wall(self, Vector2(-20, -2.5), Vector2(-20, 7.6), MEZZ_Y - 0.1, wm)
	Geo.wall(self, Vector2(-20, -2.5), Vector2(-12.2, -2.5), MEZZ_Y - 0.1, wm)
	Geo.wall(self, Vector2(-12.2, -2.5), Vector2(-12.2, 7.6), MEZZ_Y - 0.1, hw)
	Geo.wall(self, Vector2(-20, 7.6), Vector2(-12.2, 7.6), MEZZ_Y - 0.1, hw, 0.4, [[0.8, 2.8, 2.4]])
	var z: LightZone = zones.office
	z.add_panel(Vector3(-17.0, 3.17, 0.5), Vector2(2.4, 0.5), true, 1.3, 9.0, Color(1.0, 0.95, 0.85), true)
	z.add_panel(Vector3(-15.0, 3.17, 5.0), Vector2(2.4, 0.5), true, 1.1, 9.0, Color(1.0, 0.95, 0.85))
	z.add_hum(Vector3(-16, 3.0, 2.5), -24.0)
	# desk with PC + radio (west wall)
	Props.desk(self, Vector3(-19.1, 0, 2.5), Vector3(2.4, 0.76, 0.9), PI / 2)
	var pc := Props.monitor(self, Vector3(-19.35, 0.86, 1.8), PI / 2, Vector2(0.5, 0.3))
	pc.material_override = Mats.emissive(Color(0.15, 0.3, 0.6), 0.8)
	Geo.box(self, Vector3(-19.2, 0.8, 3.4), Vector3(0.08, 0.12, 0.05), Mats.get_mat("plastic_dark"), false)
	Geo.box(self, Vector3(-19.2, 0.89, 3.4), Vector3(0.01, 0.1, 0.01), Mats.get_mat("plastic_dark"), false)
	if TripoProps.exists("security", "SEC_OfficeChair"):
		TripoProps.spawn(self, "security", "SEC_OfficeChair", Vector3(-18.05, 0, 2.4), -PI / 2, true)
	else:
		Geo.box(self, Vector3(-18.1, 0.45, 2.4), Vector3(0.5, 0.08, 0.5), Mats.get_mat("seat"))
		Geo.box(self, Vector3(-17.85, 0.8, 2.4), Vector3(0.06, 0.6, 0.5), Mats.get_mat("seat"), false)
	# lockers (north wall), doors facing the room
	for i in 6:
		var lx := -19.45 + i * 0.62
		if TripoProps.exists("baggage", "BAG_NumberPillar"):
			# the Tripo pillar box (plinth, cap) stands in as a tall locker cabinet
			TripoProps.spawn(self, "baggage", "BAG_NumberPillar", Vector3(lx, 0, -2.05), 0.0, true, null, Vector3(0.6, 1.9, 0.5))
		else:
			Geo.box(self, Vector3(lx, 0.95, -2.05), Vector3(0.6, 1.9, 0.5), Mats.std(Color(0.42, 0.45, 0.48), 0.4, 0.6))
		Geo.box(self, Vector3(lx + 0.2, 1.2, -1.79), Vector3(0.03, 0.12, 0.02), Mats.get_mat("metal"), false)
		Geo.label(self, "%02d" % (i + 1), Vector3(lx, 1.7, -1.795), 0.0, 24, Color(0.1, 0.1, 0.1), 0.003, false, "print")
	# whiteboard (east wall)
	var wb := Node3D.new()
	add_child(wb)
	wb.position = Vector3(-12.42, 1.6, 2.6)
	wb.rotation.y = -PI / 2
	var board := Geo.box(wb, Vector3.ZERO, Vector3(2.0, 1.1, 0.03), Mats.get_mat("plastic_white"), false)
	if TripoProps.exists("common", "CMN_TrofferLight"):
		# the Tripo troffer's white frame and opal face read as a framed board on the wall
		board.visible = false
		var tb := TripoProps.spawn(wb, "common", "CMN_TrofferLight")
		tb.rotation.x = PI / 2          # face toward the room; scale is set after so it stays in the board's own axes
		TripoProps.fit(tb, Vector3(2.0, 0.03, 1.1))
		TripoProps.centre_on(tb, Vector3(0, 0, -0.0))
		tb.position.z = -0.015
	var note := Geo.fit(Geo.label(wb, "야간 점검 근무 — 반드시 수칙 준수!!\n점검 결과는 태블릿으로 즉시 보고\n0번 게이트 ✕  (존재하지 않음)\n— 소장", Vector3(-0.12, 0.05, 0.02), 0.0, 30, Color(0.1, 0.2, 0.6), 0.0035, false, "hand"), 1.55)
	note.rotation.z = -0.025
	# wall clock
	var clock := Node3D.new()
	add_child(clock)
	clock.position = Vector3(-16.4, 2.5, -2.28)
	Geo.cyl(clock, Vector3.ZERO, 0.18, 0.04, Mats.get_mat("plastic_white")).rotation.x = PI / 2
	Geo.label(clock, "3:00", Vector3(0, 0, 0.03), 0.0, 32, Color(0.1, 0.1, 0.1), 0.003, true, "lcd")
	# fax table for revision pages (east wall, by the door)
	Equipment.fax(self, Vector3(-12.85, 0, 6.2), PI / 2)
	# card reader door (office <-> hall), south wall
	var d := SlidingDoor.create(self, Vector3(-18.2, 0, 7.6), 0.0, 2.0, 2.4, false, false)
	doors["office"] = d
	readers["office_out"] = CardReader.create(self, Vector3(-16.85, 1.25, 7.82), 0.0)
	readers["office_in"] = CardReader.create(self, Vector3(-19.55, 1.25, 7.38), PI)
	readers.office_in.interactable.prompt = "문 열기"
	# room plate on the open side of the door, above the card reader (the west corner hides the other side), softly
	# lit so it reads in the dark
	LevelKit.plate(self, "plate_office", Vector3(-16.55, 1.72, 7.8), 0.0, Vector2(0.6, 0.4), 0.3)
	# punch clock, time cards and breaker (north wall)
	punch_clock = Equipment.punch_clock(self, Vector3(-15.3, 1.35, -2.28), 0.0)


# --------------------------------------------------------------------------------------------
## Main lounge (the lounge reference, SKETCH_SHOTS ref_lounge from its east end): a 64 x 54 m hall, the glass facade
## on the apron to the south under a soffit rising to 18 m, four rows of graphite columns carrying digital ad screens,
## two aisles under hanging Departures / Arrivals signs and a grid of small downlights, black seat rows in two bands,
## the arrivals board hung near the east end, the escalator up to the closed 2F deck on the north side, the broadcast
## desk at the far (west) end in front of the office, and the strip to the north that leads on to security, the staff
## passage (baggage) and the storage room. An airliner has come in through the glass (_wreck, _crash_debris).
func _build_hall() -> void:
	var wm := Mats.get_mat("wall")
	_floor(Rect2(-12.2, -2.5, HALL_E + 12.2, HALL_S + 2.5), "floor_lounge")
	_floor(Rect2(-20, 7.6, 7.8, HALL_S - 7.6), "floor_lounge")
	_floor(Rect2(-12.2, -8.5, 24.2, 6), "floor")
	_ceiling(Rect2(-20, -2.5, HALL_E + 20, ROOF_Z + 2.5), HALL_H, "ceiling_lounge")
	_ceiling(Rect2(-12.2, -8.5, 24.2, 6), STRIP_H)
	_soffit()
	# the airliner first: where it came through decides which panes are gone and where no seat can stand
	_wreck()
	var breaks := _facade_breaks()
	var crushed := _wreck_cells(3.0)
	# facade on the apron (south): mullions every 3 m, transoms every 3.2 m up to the soffit, smashed where the
	# airliner came through; the main entrance and the emergency exit at the west end
	_glass_facade(Vector2(-20, HALL_S), Vector2(HALL_E, HALL_S), HALL_ROOF, [[-9.7, -5.9, 2.7], [-17.8, -16.2, 2.4]],
			-19.4, 3.0, [0.1, 3.3, 6.5, 9.7, 12.9, 16.1, 19.3], breaks)
	# end walls up into the 2F's slab (the 2F's own, with the shops' fronts in them, go on up to the ceiling), the
	# gables over them under the soffit
	Geo.wall(self, Vector2(-20, 7.6), Vector2(-20, HALL_S), MEZZ_Y - 0.1, wm, 0.4,
			[[CabinWay.DOOR_Z - 7.6 - Airliner.DOOR_W * 0.5 - 0.02, CabinWay.DOOR_Z - 7.6 + Airliner.DOOR_W * 0.5 + 0.02,
			Airliner.DOOR_H + 0.02]])      # the cabin's door (CabinWay: its lining runs through)
	Geo.wall(self, Vector2(HALL_E, -2.5), Vector2(HALL_E, HALL_S), MEZZ_Y - 0.1, wm)
	_gable(-20.0, wm)
	_gable(HALL_E, wm)
	# north: the lounge floor's back wall, up into the 2F's slab (the 2F's north wall stands on it): the opening into
	# the strip, the storage room's own wall (x 12..22) with this one on top, then a plain wall
	var top := MEZZ_Y - 0.1
	Geo.wall(self, Vector2(-12.2, -2.5), Vector2(12, -2.5), top, wm, 0.4, [[7.2, 17.2, STRIP_H]])
	Geo.wall(self, Vector2(12, -2.5), Vector2(22, -2.5), top - 3.2, wm, 0.4, [], 3.2)
	Geo.wall(self, Vector2(22, -2.5), Vector2(HALL_E, -2.5), top, wm)
	# strip: west end, storage door east, security + staff passage north
	Geo.wall(self, Vector2(-12.2, -8.5), Vector2(-12.2, -2.5), STRIP_H, wm)
	Geo.wall(self, Vector2(12, -8.5), Vector2(12, -2.5), STRIP_H, wm, 0.4, [[2.1, 3.9, 2.4]])
	Geo.wall(self, Vector2(-12.4, -8.5), Vector2(12, -8.5), STRIP_H, wm, 0.4, [[0.45, 1.95, 2.4], [6.4, 18.4, SEC_H]])
	# main entrance doors (locked at night)
	doors["entrance"] = SlidingDoor.create(self, Vector3(-7.8, 0, HALL_S), 0.0, 3.6, 2.6, true, false)
	Geo.label(self, "출구  EXIT", Vector3(-7.8, 3.2, HALL_S - 0.25), PI, 60, Color(0.95, 0.95, 0.95), 0.006)
	# emergency exit door (chained until main power is cut)
	doors["emergency"] = SlidingDoor.create(self, Vector3(-17, 0, HALL_S), 0.0, 1.6, 2.4, false, false)
	var es := Props.exit_sign(self, Vector3(-17, 2.75, HALL_S - 0.3), PI, "비상구  EXIT ▶")
	exit_signs.append(es)
	for i in 3:
		var ch := Geo.box(self, Vector3(-17, 1.0 + i * 0.12, HALL_S - 0.18), Vector3(1.5, 0.04, 0.04), Mats.get_mat("metal"), false)
		ch.rotation.z = 0.25 * (1 if i % 2 == 0 else -1)
		ch.name = "Chain%d" % i
	exit_door_use = Interactable.create(self, Vector3(-17, 1.2, HALL_S - 0.3), Vector3(1.6, 2.4, 0.3), "비상구 — 체인으로 잠겨 있다", Callable())
	exit_door_use.press_sound = "door_heavy"
	# structure: a beam on each column row across the ceiling, columns with ad screens facing east and onto the aisle
	# beside them round the edge of the grid only (the middle of the lounge is open)
	for cz: float in COL_Z:
		Geo.box(self, Vector3(12.0, roof_y(cz) - 0.4, cz), Vector3(HALL_E + 20.0, 1.0, 0.7), Mats.get_mat("column"), false)
	for c: Vector3 in lounge_columns():
		_lounge_column(c, 1.0 if COL_Z.find(c.z) % 2 == 0 else -1.0)
	_hall_lights()
	_escalator()
	# broadcast desk (PA console on it) at the far end of the aisle in front of the office, its public side looking
	# down the hall; the information sign on the office wall behind it
	var desk := Node3D.new()
	desk.name = "InfoDesk"
	add_child(desk)
	info_desk(desk)
	desk.transform = desk_xform()
	warp.desk = desk
	LevelKit.wall_sign(self, Vector3(-12.0, 3.4, 4.2), 90.0, "안내  INFORMATION", Vector2(3.6, 0.75))
	# seat rows: back-to-back pairs in blocks between the columns (walk through the gaps) in the two seating bands
	# (between the rows at 11 and 22, and from the row at 33 to the glass), a row facing the glass at the front; none
	# in front of the entrance or the emergency exit, none where the airliner lies or under the escalators (one block
	# between their pairs instead). One row each on the north side.
	for x0: float in [-16.0, -1.5, 7.5, 12.0, 16.5, 25.5, 34.5, 40.8]:
		var n := 7 if x0 > 40.0 else 10
		for zz: float in [14.4, 18.6, 37.0, 41.2, 45.4]:
			var under := false
			for r: Rect2 in escalator_rects(0.3):
				under = under or r.intersects(Rect2(x0 - n * 0.31, zz - 1.1, n * 0.62, 1.6))
			if under or (x0 == 12.0 and zz > 30.0):
				continue
			_seat_row(Vector3(x0, 0, zz), n, 0.0, crushed)
			_seat_row(Vector3(x0, 0, zz - 0.58), n, PI, crushed)
		if x0 > -10.0 and x0 != 12.0:
			_seat_row(Vector3(x0, 0, 49.2), n, 0.0, crushed)
	for x0: float in [7.5, 39.0]:
		_seat_row(Vector3(x0, 0, 0.9), 8, 0.0, crushed)
	# bins at the ends of the seat blocks and against the walls, planters in the facade corners
	for p: Vector3 in [Vector3(37.9, 0, 16.5), Vector3(20.0, 0, 16.5), Vector3(2.0, 0, 16.5), Vector3(-5.2, 0, 13.0),
			Vector3(-12.6, 0, 39.1), Vector3(2.0, 0, 39.1), Vector3(37.9, 0, 39.1), Vector3(5.85, 0, -1.95),
			Vector3(-6.6, 0, -1.95), Vector3(43.3, 0, 0.0)]:
		if not _crushed_at(crushed, p) and not _under_escalator(p, 0.6):
			Props.trash_bin(self, p)
	for p in [Vector3(-19.2, 0, HALL_S - 0.8), Vector3(-11.6, 0, HALL_S - 0.8), Vector3(43.1, 0, HALL_S - 0.9)]:
		Props.planter(self, p)
	# signage: Departures / Arrivals across the north aisle seen from the east end (from column to column, below the
	# 2F's level so it does not stand in the view from the staff doors), exit and lounge under the 2F in the north-east
	# corner, security further down (hung from the ceiling between the escalators), the staff sign by the office at the
	# far end
	var under := MEZZ_Y - SLAB                   # the ceiling under the 2F
	Props.wayfinding_sign(self, Vector3(30.5, 2.95, 7.5), PI / 2, Vector2(7.8, 1.15), [
		["arrow", 90.0, 0.62, Vector2(-3.4, 0)],
		["tile", "icon_departures", 0.78, Vector2(-2.6, 0)],
		["text", "출발", 60, Vector2(-1.35, 0.2)],
		["text", "Departures", 44, Vector2(-1.35, -0.22)],
		["rule", Vector2(0, 0)],
		["text", "도착", 60, Vector2(1.35, 0.2)],
		["text", "Arrivals", 44, Vector2(1.35, -0.22)],
		["tile", "icon_luggage", 0.78, Vector2(2.6, 0)],
		["arrow", 0.0, 0.62, Vector2(3.4, 0)],
	])
	Props.wayfinding_sign(self, Vector3(35.5, 3.0, 0.4), PI / 2, Vector2(5.0, 0.95), [
		["arrow", 180.0, 0.5, Vector2(-2.05, 0)],
		["text", "출구 · 교통센터", 48, Vector2(-0.95, 0.17)],
		["text", "Exit · Transport", 34, Vector2(-0.95, -0.2)],
		["rule", Vector2(0.25, 0)],
		["text", "2층 라운지", 48, Vector2(1.3, 0.17)],
		["text", "Lounge 2F", 34, Vector2(1.3, -0.2)],
		["arrow", 90.0, 0.5, Vector2(2.15, 0)],
	], under)
	Props.wayfinding_sign(self, Vector3(12.0, 6.0, 9.6), PI / 2, Vector2(6.4, 1.0), [
		["tile", "icon_departures", 0.68, Vector2(-2.65, 0)],
		["text", "출국 · 보안검색", 54, Vector2(-0.2, 0.18)],
		["text", "Departures · Security", 38, Vector2(-0.2, -0.2)],
		["arrow", 0.0, 0.55, Vector2(2.65, 0)],
	], HALL_H)
	# the south aisle (under the atrium): exit to the left (the entrance at the west end of the glass), departures ahead
	Props.wayfinding_sign(self, Vector3(24.0, 6.8, AISLES[1]), PI / 2, Vector2(7.8, 1.15), [
		["arrow", 180.0, 0.62, Vector2(-3.4, 0)],
		["text", "출구 · 교통센터", 54, Vector2(-1.75, 0.2)],
		["text", "Exit · Transport", 40, Vector2(-1.75, -0.22)],
		["rule", Vector2(0, 0)],
		["tile", "icon_departures", 0.78, Vector2(0.75, 0)],
		["text", "출발", 60, Vector2(2.0, 0.2)],
		["text", "Departures", 44, Vector2(2.0, -0.22)],
		["arrow", 90.0, 0.62, Vector2(3.4, 0)],
	], roof_y(AISLES[1]))
	signs["hall_departures"] = Props.hanging_sign(self, Vector3(0, 3.0, -5.0), 0.0, Vector2(6.0, 0.9), [
		["↑  출국 · 보안검색", 60, Color(1, 1, 1), Vector2(-0.6, 0.18)],
		["DEPARTURES · SECURITY", 40, Color(0.85, 0.88, 0.95), Vector2(-0.6, -0.24)],
		["@icon_departures", 0.66, Color(1, 1, 1), Vector2(2.3, 0.0)],     # airport departures pictogram
	], STRIP_H)
	signs["hall_baggage"] = Props.hanging_sign(self, Vector3(-7.4, 3.05, -6.2), 0.0, Vector2(4.6, 0.8), [
		["◀  수하물 수취  BAGGAGE CLAIM", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], STRIP_H)
	signs["hall_staff"] = Props.hanging_sign(self, Vector3(-13.0, 3.1, 10.6), PI / 2, Vector2(4.4, 0.8), [
		["◀  시설관리실  STAFF ONLY", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], under)
	LevelKit.wall_sign(self, Vector3(-11.05, 2.95, -8.28), 0.0, "직원 통로 · 수하물 수취\nSTAFF · BAGGAGE CLAIM", Vector2(1.7, 0.5))   # clear of the west wall
	_crash_debris(breaks)
	_lounge_smoke()


## A thin smoke hanging in the whole lounge, thicker in slow drifts (a noise density), so the light shows in the air
## (the night-airport reference; on top of the world's own faint fog).
func _lounge_smoke() -> void:
	_smoke(AABB(Vector3(-20, 0, -2.5), Vector3(HALL_E + 20.0, HALL_ROOF, HALL_S + 2.5)), 21)


func _smoke(box: AABB, noise_seed: int, density := 0.065, albedo := Color(0.72, 0.86, 0.9), glow := Color.BLACK) -> FogMaterial:
	var smoke := FogVolume.new()
	smoke.name = "LoungeSmoke"
	smoke.size = box.size
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = albedo
	fm.emission = glow
	fm.edge_fade = 0.04
	var noise := FastNoiseLite.new()
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	noise.seed = noise_seed
	var tex := NoiseTexture3D.new()           # about a texel a metre, so the drifts keep their size
	tex.width = maxi(8, int(box.size.x))
	tex.height = maxi(8, int(box.size.y * 1.15))
	tex.depth = maxi(8, int(box.size.z))
	tex.noise = noise
	fm.density_texture = tex
	smoke.material = fm
	add_child(smoke)
	smoke.position = box.get_center()
	return fm


## Ceiling height of the lounge over `z`: the flat ceiling, then the soffit rising to the head of the glass.
static func roof_y(z: float) -> float:
	if z <= ROOF_Z:
		return HALL_H
	return HALL_H + (minf(z, HALL_S) - ROOF_Z) * (HALL_ROOF - HALL_H) / (HALL_S - ROOF_Z)


## A seat row (Props.seat_row) unless the airliner lies where it would stand (`crushed`: _wreck_cells); a row it
## went by within a few metres is shoved out of line, some thrown over.
func _seat_row(pos: Vector3, n: int, rot: float, crushed: Dictionary) -> void:
	var b := Basis(Vector3.UP, rot)
	var half := n * 0.62 * 0.5
	var near := false
	var x := -half
	while x <= half + 0.01:
		for zz: float in [-0.3, 0.3]:
			var p := pos + b * Vector3(x, 0, zz)
			if _crushed_at(crushed, p):
				return
			near = near or _crushed_at(crushed, p, 4)
		x += 0.6
	var row := Props.seat_row(self, pos, n, rot)
	warp.benches.append(row)
	if near:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0)))
		row.rotate_y(rng.randf_range(-0.5, 0.5))
		row.position += Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
		if rng.randf() < 0.45:
			row.rotate_object_local(Vector3.RIGHT, 1.45 if rng.randf() < 0.5 else -1.45)
			row.position.y += 0.3


## Whether the floor at `p` (or a cell within `r` of it) is under the airliner.
static func _crushed_at(cells: Dictionary, p: Vector3, r := 1) -> bool:
	var c := Vector2i(floori(p.x), floori(p.z))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if cells.has(c + Vector2i(dx, dz)):
				return true
	return false


## Where the broadcast desk (info_desk builds it round (0.2, 6.05), public side north) stands in the lounge: turned
## so its public side looks east down the aisle, its middle on DESK_AT.
static func desk_xform() -> Transform3D:
	var b := Basis(Vector3.UP, -PI / 2)
	return Transform3D(b, DESK_AT - b * Vector3(0.2, 0, 6.05))


## The lounge's lights: a grid of small square downlights in the dark ceiling and, tilted, in the soffit (along the
## aisles every other one throws light down, elsewhere fewer), dim fills that stand in for the bounce, a faint wash
## up the soffit, the strip's troffers. All on the hall zone.
func _hall_lights() -> void:
	var z: LightZone = zones.hall
	var tilt := atan2(HALL_ROOF - HALL_H, HALL_S - ROOF_Z)
	# under the 2F: the lounge floor's low ceiling and the galleries' undersides, a downlight every 5 m, every other
	# one throwing light
	var low := MEZZ_Y - SLAB - 0.02
	var k := 0
	for rz: float in [0.2, 2.8]:
		var x := -10.0
		while x < HALL_E - 1.0:
			z.add_downlight(Vector3(x, low, rz), 0.36, k % 2 == 0, 4.2, 7.5, 50.0)
			k += 1
			x += 5.0
	for gx: float in [-17.5, -14.5, 38.5, 41.5]:
		var gz := ATRIUM.position.y + 2.5
		while gz < HALL_S - 1.0:
			z.add_downlight(Vector3(gx, low, gz), 0.36, k % 2 == 0, 4.2, 7.5, 50.0)
			k += 1
			gz += 5.0
	# the 2F's ceiling and the atrium's: [z, every nth one lit, spot energy]
	var rows := [[1.6, 2, 6.5], [6.0, 2, 7.0], [9.0, 2, 7.0], [14.4, 3, 7.5], [18.6, 3, 7.5],
		[AISLES[1], 2, 12.0], [38.0, 3, 13.0], [45.5, 3, 13.5]]
	for r in rows.size():
		var rz: float = rows[r][0]
		var x := -16.0
		var i := r
		while x < HALL_E - 1.0:
			var lit: bool = i % rows[r][1] == 0
			if rz <= ROOF_Z:
				z.add_downlight(Vector3(x, HALL_H - 0.02, rz), 0.42, lit, rows[r][2], 18.0)
			else:
				z.add_downlight(Vector3(x, roof_y(rz) - 0.03, rz), 0.5, lit, rows[r][2], 26.0, 38.0, Color.TRANSPARENT, tilt)
			i += 1
			x += 5.0
	# fills standing in for the bounce: on the lounge floor under the 2F, on the 2F, in the atrium
	for fx: float in [-8.0, 6.0, 20.0, 34.0]:
		for f: Array in [[Vector3(fx, 3.0, AISLES[0]), 0.45, 12.0], [Vector3(fx + 7.0, 3.0, 16.5), 0.45, 12.0],
				[Vector3(fx, 3.0, AISLES[1]), 0.45, 12.0], [Vector3(fx, MEZZ_Y + 4.0, 1.6), 0.7, 18.0],
				[Vector3(fx + 7.0, MEZZ_Y + 4.0, 26.0), 0.7, 18.0], [Vector3(fx + 7.0, 8.0, 42.0), 0.7, 18.0],
				[Vector3(fx, 9.0, 48.0), 0.6, 16.0]]:
			var o := Geo.omni(self, f[0], FILL_LIGHT, f[1], f[2])
			o.light_specular = 0.0
			o.light_volumetric_fog_energy = 0.0
			z.add_light(o)
	# each pair of escalators, lit from above along its run so the way down reads from the staff doors
	for xc: float in ESC_X:
		var dl := Geo.spot(self, Vector3(xc, HALL_H - 0.3, ESC_FOOT_Z - 6.3), Vector3(xc, 2.0, ESC_FOOT_Z - 2.8), ZONE_LIGHT,
				4.5, 16.0, 42.0)
		dl.light_volumetric_fog_energy = 0.3
		z.add_light(dl)
	# and one over the staff doors in the 2F's north wall
	var door_light := Geo.spot(self, Vector3(DECK_DOOR.x - 1.0, HALL_H - 0.3, DECK_DOOR.z + 3.0),
			Vector3(DECK_DOOR.x - 1.5, MEZZ_Y, DECK_DOOR.z + 2.6), ZONE_LIGHT, 4.5, 15.0, 55.0)
	door_light.light_volumetric_fog_energy = 0.3
	z.add_light(door_light)
	# two spots in the soffit left on over where the airliner came to rest: its nose and its wing in the light
	for s: Array in [[Vector3(8.0, roof_y(37.0) - 0.4, 37.0), _wreck_point(Vector3(0, 2.0, 24.0))],
			[Vector3(26.0, roof_y(40.0) - 0.4, 40.0), _wreck_point(Vector3(-12.0, 3.0, 4.0))]]:
		var sp := Geo.spot(self, s[0], s[1], ZONE_LIGHT, 7.0, 32.0, 32.0)
		sp.light_volumetric_fog_energy = 0.6
		z.add_light(sp)
	# a faint wash up the soffit so the high slope reads against the night outside
	for wx: float in [-14.0, -2.0, 10.0, 22.0, 34.0]:
		for wz: float in [31.0, 45.0]:
			var w := Geo.omni(self, Vector3(wx, roof_y(wz) - 1.3, wz), FILL_LIGHT, 1.0, 12.0)
			w.light_specular = 0.0
			w.light_volumetric_fog_energy = 0.0
			z.add_light(w)
	for sx: float in [-6.0, 0.0, 6.0]:
		z.add_panel(Vector3(sx, STRIP_H - 0.08, -5.5), Vector2(0.5, 2.4), sx == 0.0, 1.4, 10.0)
	for h: Vector3 in [Vector3(4, 7, 7), Vector3(30, 7, 7), Vector3(4, 8, 30), Vector3(30, 8, 30)]:
		z.add_hum(h, -19.0)
	z.add_hum(Vector3(0, 3.2, -5.5), -20.0)


## The sloped soffit from the south column row (HALL_H) up to the head of the glass (HALL_ROOF), the full length of
## the lounge; its low edge runs into the beam.
func _soffit() -> void:
	var run := HALL_S - ROOF_Z
	var rise := HALL_ROOF - HALL_H
	var a := atan2(rise, run)
	var mi := Geo.box(self, Vector3.ZERO, Vector3(HALL_E + 20.0, 0.2, sqrt(run * run + rise * rise) + 0.3),
			Mats.get_mat("ceiling_lounge"), false)
	mi.rotation.x = -a
	mi.position = Vector3((HALL_E - 20.0) * 0.5, (HALL_H + HALL_ROOF) * 0.5, (ROOF_Z + HALL_S) * 0.5) \
			+ Vector3(0, cos(a), -sin(a)) * 0.103


## Triangle of end wall under the soffit at `x` (the wall below it stops at the flat ceiling height).
func _gable(x: float, mat: Material) -> void:
	var tri := [Vector2(ROOF_Z - 0.4, HALL_H - 0.05), Vector2(HALL_S, HALL_H - 0.05), Vector2(HALL_S, HALL_ROOF + 0.3)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		var n := Vector3(s, 0, 0)
		var v: Array = tri.map(func(p: Vector2): return Vector3(x + s * 0.2, p.y, p.x))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(n) > 0.0:     # front faces wind clockwise
			v = [v[0], v[2], v[1]]
		for p: Vector3 in v:
			st.set_normal(n)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## The lounge's columns (floor points): the edge of the grid (COL_X x COL_Z), the middle left open.
static func lounge_columns() -> Array:
	var out := []
	for cx: float in COL_X:
		for i in COL_Z.size():
			if cx == COL_X[0] or cx == COL_X[-1] or i == 0 or i == COL_Z.size() - 1:
				out.append(Vector3(cx, 0, COL_Z[i]))
	return out


## A graphite column of the lounge grid on a steel base: up to the 2F's floor where the 2F is over it or on its edge
## (no column stands on the 2F), else up to the ceiling (into the soffit on its high side); a digital ad screen on its
## east face (what you see down the hall from the east end) and one on the face toward the aisle beside it (`side` +1:
## the +Z face, -1: the -Z face).
func _lounge_column(p: Vector3, side: float) -> void:
	var s := 1.3
	var h := MEZZ_Y - 0.005 if p.z <= ATRIUM.position.y + 0.1 else roof_y(p.z + s * 0.5)
	Geo.box(self, p + Vector3(0, h * 0.5, 0), Vector3(s, h, s), Mats.get_mat("column"))
	Geo.box(self, p + Vector3(0, 0.07, 0), Vector3(s + 0.04, 0.14, s + 0.04), Mats.get_mat("metal_dark"), false)
	_ad_screen(p + Vector3(s * 0.5, 0, 0), 90.0)
	_ad_screen(p + Vector3(0, 0, s * 0.5 * side), 0.0 if side > 0.0 else 180.0)


## Portrait digital ad screen (1.0 x 1.9 m, bottom at 0.6 m) in a dark bezel on a column face: `at` = the face at
## floor level, `facing` = the way the screen looks (deg). Its blue light spills onto the floor in front of it.
func _ad_screen(at: Vector3, facing: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.rotation.y = deg_to_rad(facing)
	Geo.box(root, Vector3(0, 1.55, 0.03), Vector3(1.1, 2.06, 0.06), Mats.get_mat("plastic_dark"), false)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.9)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = Mats.get_mat("ad_screen")
	root.add_child(mi)
	mi.position = Vector3(0, 1.55, 0.062)
	mi.set_instance_shader_parameter("seed", fposmod(at.x * 0.37 + at.z * 1.13 + facing * 0.011, 10.0))
	var l := Geo.omni(root, Vector3(0, 1.0, 0.9), Color(0.35, 0.55, 1.0), 0.45, 4.5)
	l.light_specular = 0.0
	l.light_volumetric_fog_energy = 0.3


## Broadcast desk: a solid-surface counter (worktop 1.0 m, the PA console on it) between two raised returns
## (1.18 m), open to the south where the operator stands: dark recessed plinth, blue accent line on the public face,
## quartz tops overhanging 3 cm, a drawer pedestal and a knee space under the worktop. Built from closed rounded
## volumes (the stretched Tripo desk showed open, paper-thin panels).
static func info_desk(parent: Node3D) -> void:
	var body := Mats.std(Color(0.88, 0.88, 0.86), 0.35)
	var top := Mats.std(Color(0.74, 0.75, 0.74), 0.22, 0.05)
	var blue := Mats.std(Color(0.07, 0.25, 0.56), 0.4)
	var dark := Mats.std(Color(0.09, 0.095, 0.1), 0.6)
	var kick := CarouselMesh.mat("kick")
	var x0 := -0.75                         # worktop between the returns
	var x1 := 1.15
	var z_front := 5.3                      # public face (north)
	var z_back := 6.2                       # operator side (south) of the worktop
	var parts: Array = [
		# [centre-bottom, size, corner radius, material, closed base]
		[Vector3((x0 + x1) * 0.5, 0.0, z_front + 0.05), Vector3(x1 - x0, 0.1, 0.06), 0.01, kick, false],
		[Vector3((x0 + x1) * 0.5, 0.1, z_front + 0.04), Vector3(x1 - x0, 0.86, 0.08), 0.01, body, false],      # modesty panel
		[Vector3((x0 + x1) * 0.5, 0.96, (z_front + z_back) * 0.5), Vector3(x1 - x0 + 0.04, 0.04, z_back - z_front + 0.06), 0.015, top, true],
		[Vector3(x1 - 0.26, 0.0, 5.76), Vector3(0.46, 0.96, 0.82), 0.015, body, false],                        # drawer pedestal (floor to worktop)
	]
	for rx in [-1.0, 1.4]:
		parts.append([Vector3(rx, 0.0, 6.05), Vector3(0.42, 0.1, 1.42), 0.03, kick, false])
		parts.append([Vector3(rx, 0.1, 6.05), Vector3(0.5, 1.04, 1.5), 0.04, body, false])
		parts.append([Vector3(rx, 1.14, 6.05), Vector3(0.56, 0.04, 1.56), 0.04, top, true])
	for pt in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.rounded_prism(pt[1], pt[2], pt[4])
		mi.material_override = pt[3]
		parent.add_child(mi)
		mi.position = pt[0]
	# knee space: a dark back under the worktop between the modesty panel and the pedestal
	Geo.box(parent, Vector3((x0 + x1 - 0.52) * 0.5, 0.53, z_front + 0.085), Vector3(x1 - x0 - 0.52, 0.86, 0.01), dark, false)
	# blue accent line wrapping the public face and the returns' outer faces
	Geo.box(parent, Vector3((x0 + x1) * 0.5, 0.82, z_front - 0.003), Vector3(x1 - x0, 0.035, 0.008), blue, false)
	for rx in [-1.0, 1.4]:
		Geo.box(parent, Vector3(rx, 0.82, 5.3 - 0.003), Vector3(0.42, 0.035, 0.008), blue, false)
	# drawer fronts: dark seams and finger pulls on the pedestal's operator face
	for i in 3:
		var dy := 0.24 + i * 0.25
		Geo.box(parent, Vector3(x1 - 0.26, dy + 0.11, 6.172), Vector3(0.4, 0.006, 0.006), dark, false)
		Geo.box(parent, Vector3(x1 - 0.26, dy + 0.06, 6.175), Vector3(0.14, 0.012, 0.012), CarouselMesh.mat("steel"), false)
	# colliders
	Geo.blocker(parent, Vector3((x0 + x1) * 0.5, 0.5, (z_front + z_back) * 0.5), Vector3(x1 - x0, 1.0, z_back - z_front))
	for rx in [-1.0, 1.4]:
		Geo.blocker(parent, Vector3(rx, 0.59, 6.05), Vector3(0.5, 1.18, 1.5))


## Self check-in kiosk: an off-white cabinet on a dark plinth with a blue band, a service door, boarding-pass and
## bag-tag printer slots, a reader ledge (passport glass, card reader) and a portrait touch screen tilted back on a
## steel neck. `facing` = direction the screen looks (deg). Built once, then copied (shared meshes and materials).
static func build_kiosk() -> Node3D:
	var k := Node3D.new()
	var body := Mats.std(Color(0.84, 0.85, 0.84), 0.35)
	var dark := Mats.std(Color(0.14, 0.15, 0.17), 0.45, 0.2)
	var blue := Mats.std(Color(0.07, 0.25, 0.56), 0.4)
	var steel := CarouselMesh.mat("steel")
	# [size, corner radius, position, material, closed base]
	for part in [
		[Vector3(0.46, 0.06, 0.38), 0.03, Vector3(0, 0, 0), CarouselMesh.mat("kick"), false],
		[Vector3(0.5, 1.0, 0.42), 0.05, Vector3(0, 0.06, 0), body, true],
		[Vector3(0.508, 0.04, 0.428), 0.054, Vector3(0, 0.94, 0), blue, false],      # band, 4 mm proud
		[Vector3(0.51, 0.03, 0.2), 0.03, Vector3(0, 1.035, 0.16), body, true],        # reader ledge, 5 mm over the top
		[Vector3(0.14, 0.14, 0.08), 0.02, Vector3(0, 1.06, -0.04), steel, false],     # neck
	]:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.rounded_prism(part[0], part[1], part[4])
		mi.material_override = part[3]
		k.add_child(mi)
		mi.position = part[2]
	# service door: a dark seam around a panel standing 3 mm proud of it
	Geo.box(k, Vector3(0, 0.45, 0.2115), Vector3(0.372, 0.612, 0.004), dark, false)
	Geo.box(k, Vector3(0, 0.45, 0.2145), Vector3(0.36, 0.6, 0.004), body, false)
	Geo.box(k, Vector3(0.14, 0.45, 0.218), Vector3(0.02, 0.06, 0.002), steel, false)    # key lock
	# printer slots: boarding pass above, bag tag below, each in a dark bezel
	for sy in [0.87, 0.81]:
		Geo.box(k, Vector3(0, sy, 0.2125), Vector3(0.24, 0.036, 0.005), dark, false)
		Geo.box(k, Vector3(0, sy, 0.215), Vector3(0.19, 0.006, 0.002), Mats.get_mat("black"), false)
	# ledge: passport reader glass (left), card reader with its slot (right)
	Geo.box(k, Vector3(-0.1, 1.067, 0.17), Vector3(0.17, 0.003, 0.12), Mats.std(Color(0.04, 0.05, 0.06), 0.1, 0.0), false)
	Geo.box(k, Vector3(0.15, 1.09, 0.18), Vector3(0.09, 0.05, 0.08), dark, false)
	Geo.box(k, Vector3(0.15, 1.1, 0.2205), Vector3(0.06, 0.004, 0.002), Mats.get_mat("black"), false)
	# portrait screen head: dark rounded bezel tilted back, the welcome screen set into it
	var head := Node3D.new()
	k.add_child(head)
	head.position = Vector3(0, 1.16, -0.02)
	head.rotation.x = -0.26
	var bezel := MeshInstance3D.new()
	bezel.mesh = CarouselMesh.rounded_prism(Vector3(0.46, 0.06, 0.6), 0.03, true)
	bezel.material_override = dark
	head.add_child(bezel)
	bezel.rotation.x = PI / 2          # prism top = the screen face (+Z), its body behind
	bezel.position = Vector3(0, 0.3, -0.03)
	var scr := LevelKit.decal(head, "kiosk_screen", Vector3(0, 0.31, 0.032), 0.0, Vector2(0.38, 0.5), 0.7)
	scr.name = "KioskScreen"
	Geo.blocker(k, Vector3(0, 0.87, 0), Vector3(0.5, 1.74, 0.42))
	return k


## Two pairs of stopped escalators from the 2F's edge down into the atrium, toward the airliner (Escalator, rising
## north): in each pair an up and a down side by side, the up one belted off at its foot (the clutter on its outer side).
func _escalator() -> void:
	for u: Array in escalator_units():
		var foot: Vector3 = u[0]
		var outward := signf(foot.x - DECK_DOOR.x)
		Escalator.build(self, foot, MEZZ_Y, PI / 2, not u[1], 0.0 if u[1] else -outward)


## The lounge's 2F (MEZZ_Y), an empty floor for what comes later: a gallery of one width on three sides (UPPER) — the
## north side the length of the hall, the east and west sides down to the glass — polished floor plates, the lounge's
## ceiling under them, glass balustrades (they stop you) along the atrium, open where the escalators come up, a steel
## band on the slab edges; the lounge's north wall on up to the ceiling with the staff doors from the service corridor
## (DECK_DOOR) in it, an exit sign over them and a dim green light. Lit by the hall zone.
func _build_upper_floor() -> void:
	var under := Mats.get_mat("ceiling_lounge")
	var floor_m := Mats.get_mat("floor_lounge")
	for r: Array in UPPER:
		var c := Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5)
		var size := Vector2(r[2] - r[0], r[3] - r[1])
		Geo.box(self, Vector3(c.x, MEZZ_Y - SLAB * 0.5 - 0.01, c.z), Vector3(size.x, SLAB - 0.02, size.y), under, false)
		Geo.box(self, Vector3(c.x, MEZZ_Y - 0.01, c.z), Vector3(size.x, 0.02, size.y), floor_m)
		_ceilings.append([Rect2(r[0], r[1], size.x, size.y), MEZZ_Y - SLAB])
	# [from, to, toward the void]: round the atrium; along its north edge the glass stops where the escalators come up
	# (the slab's steel band runs on under them)
	var a := ATRIUM
	_balustrade(Vector2(a.position.x, a.position.y), Vector2(a.position.x, a.end.y), Vector2(1, 0))
	_balustrade(Vector2(a.end.x, a.position.y), Vector2(a.end.x, a.end.y), Vector2(-1, 0))
	_balustrade(Vector2(a.position.x, a.position.y), Vector2(a.end.x, a.position.y), Vector2(0, 1), false)
	var cur := a.position.x
	for xc: float in ESC_X:
		var half := ESC_GAP * 0.5 + 0.82 + 0.04
		_balustrade(Vector2(cur, a.position.y), Vector2(xc - half, a.position.y), Vector2(0, 1), true, false)
		cur = xc + half
	_balustrade(Vector2(cur, a.position.y), Vector2(a.end.x, a.position.y), Vector2(0, 1), true, false)
	# the lounge's north wall on up to the ceiling from where the lounge floor's stops (in the slab), the staff double
	# doors in it at the 2F's level with a sill under them; locked from this side (the service corridor's far doors come
	# out here; ch1), dark behind them (out of a portal's view)
	var wm := Mats.get_mat("wall")
	var base := MEZZ_Y - 0.1
	var dw := ServiceHall.FAR_W * 0.5 + 0.08
	var dtop := MEZZ_Y + ServiceHall.FAR_H + 0.08
	Geo.wall(self, Vector2(-20, -2.5), Vector2(HALL_E, -2.5), HALL_H - base, wm, 0.4,
			[[DECK_DOOR.x - dw + 20.0, DECK_DOOR.x + dw + 20.0, dtop - base]] + Shops.openings("n"), base)
	# the end walls on up from the slab too; the shop units behind all three walls, their openings cut into them (Shops)
	Geo.wall(self, Vector2(-20, -2.5), Vector2(-20, HALL_S), HALL_H - base, wm, 0.4, Shops.openings("w"), base)
	Geo.wall(self, Vector2(HALL_E, -2.5), Vector2(HALL_E, HALL_S), HALL_H - base, wm, 0.4, Shops.openings("e"), base)
	Shops.build(self)
	Geo.box(self, Vector3(DECK_DOOR.x, MEZZ_Y - 0.05, DECK_DOOR.z), Vector3(dw * 2.0, 0.1, 0.4), wm)
	lounge_door = ServiceHall.double_door(self, Transform3D(Basis(), DECK_DOOR))
	(lounge_door.use as Interactable).callback = func(): rattle(lounge_door)
	Geo.box(self, DECK_DOOR + Vector3(0, 1.3, -1.7), Vector3(2.4, 2.6, 2.4), Mats.get_mat("void")).layers = Geo.VIS_PORTAL_HIDDEN
	LevelKit.plate(self, "plate_staffonly", DECK_DOOR + Vector3(1.4, 1.6, 0.21), 0.0, Vector2(0.5, 0.33))
	var glow := Geo.omni(self, DECK_DOOR + Vector3(-1.0, 2.6, 2.4), Color(0.3, 0.9, 0.5), 0.25, 8.0)
	glow.light_volumetric_fog_energy = 0.4
	zones.hall.add_light(glow)
	Props.exit_sign(self, DECK_DOOR + Vector3(0, ServiceHall.FAR_H + 0.42, 0.24), 0.0, "비상구  EXIT")


## A glass balustrade on a 2F slab edge from `a` to `b` (axis-aligned; `out` = toward the void): glass, rail, shoe and
## a collider set 6 cm back on the slab (no column stands on the 2F to break it); a steel band on the slab's edge.
## Either part can be left out (`rail`, `band`) where an edge is broken up.
func _balustrade(a: Vector2, b: Vector2, out: Vector2, rail := true, band := true) -> void:
	var along_x := absf(b.x - a.x) > 0.01
	var line := (a.y - out.y * 0.06) if along_x else (a.x - out.x * 0.06)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var glass := Mats.get_mat("glass")
	var steel := CarouselMesh.mat("steel")
	var mid := (lo + hi) * 0.5
	var l := hi - lo
	var p := Vector3(mid, 0, line) if along_x else Vector3(line, 0, mid)
	var dims := func(thick: float, h: float) -> Vector3: return Vector3(l, h, thick) if along_x else Vector3(thick, h, l)
	if rail:
		Geo.box(self, p + Vector3(0, MEZZ_Y + 0.56, 0), dims.call(0.02, 0.98), glass, false)
		Geo.box(self, p + Vector3(0, MEZZ_Y + 1.08, 0), dims.call(0.07, 0.05), steel, false)
		Geo.box(self, p + Vector3(0, MEZZ_Y + 0.04, 0), dims.call(0.06, 0.08), steel, false)
		Geo.blocker(self, p + Vector3(0, MEZZ_Y + 0.7, 0), dims.call(0.12, 1.4))
	if not band:
		return
	var edge := (a.y + out.y * 0.006) if along_x else (a.x + out.x * 0.006)
	Geo.box(self, Vector3(mid, MEZZ_Y - SLAB * 0.5, edge) if along_x else Vector3(edge, MEZZ_Y - SLAB * 0.5, mid),
			Vector3(hi - lo, SLAB + 0.02, 0.012) if along_x else Vector3(0.012, SLAB + 0.02, hi - lo), steel, false)

func _glass_facade(a: Vector2, b: Vector2, height: float, gaps: Array, mullion_x := 0.0, step := 4.0,
		transoms := [0.1, 4.6], breaks := {}) -> void:
	# glass wall along X at z = a.y. gaps: [[x0, x1, top], ...] (door openings); mullions every `step` from
	# `mullion_x` (none inside a door opening), horizontal bars at `transoms` and the head. breaks: bay -> height
	# (bay k runs from mullion_x + k * step): the glass there is smashed out up to that height, the bars below it are
	# gone and the mullions beside it torn off there, jagged teeth of glass left in the frames. The blockers stay
	# whole (you cannot climb out through the breach).
	var z := a.y
	var x := mullion_x - step * ceilf((mullion_x - a.x) / step)
	var frame := Mats.get_mat("steel_frame")
	var glass := Mats.get_mat("glass")
	var brk := func(k: int) -> float: return breaks.get(k, 0.0)
	var segs := []
	var cursor := a.x
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	for g in sorted:
		segs.append([cursor, g[0]])
		cursor = g[1]
	segs.append([cursor, b.x])
	for s in segs:
		var w: float = s[1] - s[0]
		if w <= 0.01:
			continue
		for r: Array in _bay_runs(s[0], s[1], mullion_x, step, brk):
			if r[2] < height:
				Geo.box(self, Vector3((r[0] + r[1]) * 0.5, (r[2] + height) * 0.5, z), Vector3(r[1] - r[0], height - r[2], 0.04), glass, false)
		Geo.blocker(self, Vector3((s[0] + s[1]) * 0.5, height * 0.5, z), Vector3(w, height, 0.4))
	for g in sorted:
		var w2: float = g[1] - g[0]
		var top: float = g[2]
		Geo.box(self, Vector3((g[0] + g[1]) * 0.5, (height + top) * 0.5, z), Vector3(w2, height - top, 0.04), glass, false)
		Geo.box(self, Vector3((g[0] + g[1]) * 0.5, top + 0.1, z), Vector3(w2 + 0.2, 0.2, 0.25), frame, false)
		Geo.blocker(self, Vector3((g[0] + g[1]) * 0.5, (height + top) * 0.5, z), Vector3(w2, height - top, 0.4))
	while x <= b.x + 0.01:
		var in_gap := false
		for g in sorted:
			if x > g[0] - 0.1 and x < g[1] + 0.1:
				in_gap = true
		if x >= a.x - 0.01 and not in_gap:
			var k := int(roundf((x - mullion_x) / step))      # the mullion between bay k - 1 and bay k
			var cut := maxf(brk.call(k - 1), brk.call(k))
			if cut <= 0.0:
				Geo.box(self, Vector3(x, height * 0.5, z), Vector3(0.14, height, 0.22), frame, false)
			elif cut < height:
				Geo.box(self, Vector3(x, (cut + height) * 0.5, z), Vector3(0.14, height - cut, 0.22), frame, false)
				var stub := Geo.box(self, Vector3(x, cut - 0.42, z - 0.22), Vector3(0.14, 0.9, 0.22), frame, false)
				stub.rotation.x = 0.5 + 0.3 * sin(x)          # the torn end bent in by the impact
		x += step
	for y in transoms + [height - 0.1]:
		for s in segs:
			if s[1] - s[0] <= 0.01:
				continue
			for r: Array in _bay_runs(s[0], s[1], mullion_x, step, func(k: int) -> bool: return y > brk.call(k)):
				if r[2]:
					Geo.box(self, Vector3((r[0] + r[1]) * 0.5, y, z), Vector3(r[1] - r[0], 0.12, 0.18), frame, false)
	if breaks.is_empty():
		return
	# jagged glass left round the breach: teeth hanging from the panes that stayed, and sticking out of a broken
	# pane's edge where the bay beside it stayed whole lower down
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in breaks:
		var bx: float = mullion_x + k * step
		var top: float = breaks[k]
		var px := bx + 0.08
		while top < height - 0.2 and px < bx + step - 0.25:
			var px2 := minf(px + rng.randf_range(0.2, 0.7), bx + step - 0.08)
			_shard_tri(st, Vector3(px, top, z), Vector3(px2, top, z),
					Vector3(rng.randf_range(px, px2), top - rng.randf_range(0.25, 1.5), z + rng.randf_range(-0.03, 0.03)))
			px = px2
		for side: int in [-1, 1]:
			var low: float = brk.call(k + side)
			var ex := bx + (0.0 if side < 0 else step)
			var py := low
			while low < top and py < top - 0.2:
				var py2 := minf(py + rng.randf_range(0.3, 0.9), top)
				_shard_tri(st, Vector3(ex, py, z), Vector3(ex, py2, z),
						Vector3(ex - side * rng.randf_range(0.2, 1.0), rng.randf_range(py, py2), z + rng.randf_range(-0.03, 0.03)))
				py = py2
	var teeth := MeshInstance3D.new()
	teeth.mesh = st.commit()
	teeth.material_override = _shard_mat()
	add_child(teeth)


## Pieces of [x0, x1] cut at a facade's mullion lines, merged where `value` (of the bay index) is the same:
## [[from, to, value], ...].
static func _bay_runs(x0: float, x1: float, mullion_x: float, step: float, value: Callable) -> Array:
	var runs := []
	var px := x0
	while px < x1 - 0.01:
		var k := int(floor((px + 0.001 - mullion_x) / step))
		var px1 := minf(x1, mullion_x + (k + 1) * step)
		var v: Variant = value.call(k)
		if not runs.is_empty() and runs[-1][2] == v:
			runs[-1][1] = px1
		else:
			runs.append([px, px1, v])
		px = px1
	return runs


static func _shard_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(p)


## Broken glass: clearer than the panes' tint so the edges and the bits on the floor catch the light.
static func _shard_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.82, 0.88, 0.32)
	m.roughness = 0.04
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --------------------------------------------------------------------------------------------
## Baggage claim (baggage sketch): carousels out of the west wall with number towers, B-03 the working loop,
## the staff passage from the strip arriving at its north-east corner, the corridor opening in its east wall.
func _build_baggage() -> void:
	var r := Rect2(-36, -64, 26, 24.4)
	_floor(r, "floor")
	_ceiling(r, BAG_H)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-36, -39.6), Vector2(-12.4, -39.6), BAG_H + 0.2, wm)
	Geo.wall(self, Vector2(-36, -64), Vector2(-36, -39.6), BAG_H + 0.2, wm, 0.4, [[13.0, 15.0, 2.4]])
	Geo.wall(self, Vector2(-36, -64), Vector2(-10, -64), BAG_H + 0.2, wm)
	# staff passage (strip -> hall), part of the baggage zone
	var pr := Rect2(-12.4, -39.6, 2.4, 31.1)
	_floor(pr, "floor_service")
	_ceiling(pr, 3.0, "ceiling_dark")
	# a doorway at z -16.5..-15.5: the security office's door (_build_security_office)
	Geo.wall(self, Vector2(-12.4, -39.6), Vector2(-12.4, -8.5), 3.0, Mats.get_mat("wall_service"), 0.3, [[23.1, 24.1, 2.15]])
	# beams across the hall every 6 m, pilasters on the west wall under them
	for zz in [-45.6, -51.6, -57.6]:
		Geo.box(self, Vector3(-23, BAG_H - 0.175, zz), Vector3(26, 0.35, 0.5), wm, false)
		Geo.box(self, Vector3(-35.72, BAG_H * 0.5, zz), Vector3(0.16, BAG_H, 0.46), wm)      # a hair thinner than the beam
	var z: LightZone = zones.baggage
	var k := 0
	for x in [-31.0, -24.0, -17.0]:
		for zz in [-42.6, -48.6, -54.6, -60.6]:
			z.add_panel(Vector3(x, BAG_H - 0.04, zz), Vector2(1.6, 0.16), k % 3 != 1, 1.5, 10.0)
			k += 1
	for x in [-27.5, -20.5, -13.5]:
		for zz in [-45.6, -57.6]:
			if TripoProps.exists("common", "CMN_ACCassette"):
				LevelKit.ceiling_prop(self, "CMN_ACCassette", Vector3(x, 0, zz + 3.0), BAG_H, 0.0, 0.045)
	for zz in [-14.0, -22.0, -30.0, -37.0]:
		z.add_panel(Vector3(-11.2, 2.96, zz), Vector2(0.3, 1.2), true, 0.6, 6.0)
	z.add_hum(Vector3(-23, 3.2, -52), -18.0)
	# decorative carousels B-01 / B-02 fed through the west wall
	var bays := [[-45.2, 1], [-52.0, 2]]
	for b in bays:
		var cz: float = b[0]
		var car := Node3D.new()
		add_child(car)
		car.position = Vector3(-30.4, 0, cz)
		car.add_child(CarouselMesh.hull(3.4, 1.25))
		car.add_child(CarouselMesh.plates_static(3.4, 1.25))
		Geo.blocker(car, Vector3(0, 0.45, 0), Vector3(10.7, 0.9, 3.9))
		var cap := Geo.label(car, tr("B-%02d  운영 준비 중") % b[1], Vector3(0.6, CarouselMesh.ISLAND_Y + 0.004, 0), 0.0, 40, Color(0.25, 0.27, 0.3), 0.005, false, "print")
		cap.rotation.x = -PI / 2
		Geo.fit(cap, 5.0, 1.1)
		cap.set_meta("no_fit", true)
		LevelKit.number_pillar(self, Vector3(-33.7, 0, cz), b[1], 90.0)
		if TripoProps.exists("baggage", "BAG_FeedPortal"):
			LevelKit.mount(self, "baggage", "BAG_FeedPortal", Vector3(-35.8, 0.35, cz - 1.4), 90.0)
	LevelKit.number_pillar(self, Vector3(-33.6, 0, BELT_POS.z - 1.6), 3, 90.0)
	signs["baggage_main"] = Props.hanging_sign(self, Vector3(-25.5, 2.5, -55.4), 0.0, Vector2(4.4, 0.8), [
		["수하물 수취대  B-03", 52, Color(1, 1, 1), Vector2(0, 0)],
	], BAG_H)
	LevelKit.hanging_sign(self, Vector3(-20.0, BAG_H, -42.4), 0.0, "수하물 수취\nBaggage Claim")
	# waiting seats along the east side, bins, and the (locked) arrivals exit in the far (north) wall
	for zz in [-55.0, -57.2, -59.4, -61.6]:
		LevelKit.prop(self, "baggage", "BAG_RowSeating", Vector3(-11.6, 0, zz), -90.0)
	for p in [Vector3(-11.6, 0, -53.6), Vector3(-11.6, 0, -63.2), Vector3(-34.9, 0, -41.0)]:
		LevelKit.prop(self, "baggage", "BAG_TrashBin", p)
	LevelKit.double_door(self, Vector3(-18.0, 0, -63.8), 0.0, "출구  EXIT")
	LevelKit.wall_sign(self, Vector3(-24.0, 2.3, -63.78), 0.0, "도착 출구  ARRIVALS EXIT", Vector2(2.4, 0.45), "icon_arrow")
	# maintenance door (keypad) in the west wall
	doors["maint"] = SlidingDoor.create(self, Vector3(-36, 0, -50), PI / 2, 1.8, 2.4, false, false)
	LevelKit.plate(self, "plate_maint", Vector3(-35.8, 1.72, -48.55), 90.0, Vector2(0.6, 0.4), 0.3)
	LevelKit.plate(self, "plate_staffonly", Vector3(-35.8, 1.24, -48.55), 90.0, Vector2(0.42, 0.28), 0.15)
	# on the face of the pilaster south of the door (on the wall beside it, it sat half inside the pilaster, which
	# caught the [E] ray)
	var kp := Props.panel_box(self, Vector3(-35.64, 1.3, -51.6), PI / 2, Vector2(0.2, 0.28), "")
	for i in 9:
		Geo.box(kp, Vector3(-0.05 + (i % 3) * 0.05, 0.05 - (i / 3) * 0.05, 0.006), Vector3(0.035, 0.035, 0.01), Mats.get_mat("plastic_white"), false)
	Geo.box(kp, Vector3(0, 0.11, 0.006), Vector3(0.14, 0.03, 0.01), Mats.get_mat("lamp_red"), false)
	keypad = Interactable.create(kp, Vector3(0, 0, 0.05), Vector3(0.25, 0.32, 0.1), "도어락 비밀번호 입력", Callable())
	keypad.press_sound = "keypad_beep"
	# the staff passage is closed until DAY 2 (zones open one per day)
	shutters["baggage"] = Shutter.create(self, Vector3(-11.2, 0, -8.5), 0.0, 1.5, 2.4, "점검 구역 외 · 통제")


## The security office (보안실), off the staff passage's west wall: where the night shift starts (the prologue opens
## here) and the door the chase comes back to. Laid out from the user's sketch (seen from the south end), packed like
## the old police-office reference and with a CCTV room like the Evil Within one (_cctv_room): nothing stands alone,
## every desk and cabinet top is loaded. In the north-west corner the CCTV room behind a wired-glass partition (its
## doorway on the south); in the middle an island of four desks pushed together (two face two over a low divider:
## old PCs, a typewriter, phones, papers, binders, the guard's desk with the key card drawer); by the west wall south
## of the west door a desk with an old PC and in front of it another; staff lockers on the south and east walls, a
## bookshelf, a tall document cabinet, lateral and filing cabinets under the window (its roller blind down), a glass
## cabinet, a key box, notice boards, a whiteboard, a wall calendar, a wall fan, a ceiling fan turning, vents, a duct,
## a water cooler, a coat rack, the armchair, cartons and bins. Three doors you cannot go through rattle (rattle()):
## the west door (sec_entry; past it a dark vestibule — the main story comes in that way), the store room in the north
## wall (sec_closet) and the night-duty room in the west wall (숙직실). The passage door (sec_door, east) is the way
## out. Drawers that open ([E], Drawer; sec_drawers): the CRT desk's, the guard's, the filing and lateral cabinets.
func _build_security_office() -> void:
	var r: Rect2 = ZONE_RECTS.secoffice
	_floor(r, "floor_office")
	_ceiling(r, 2.85)
	var wm := Mats.get_mat("wall_office")
	Geo.wall(self, Vector2(-20, -21), Vector2(-20, -11), 3.0, wm, 0.3, [[5.925, 6.875, 2.13], [8.775, 9.725, 2.13]])
	Geo.wall(self, Vector2(-20, -21), Vector2(-12.4, -21), 3.0, wm, 0.3, [[6.225, 7.175, 2.13]])
	Geo.wall(self, Vector2(-20, -11), Vector2(-12.4, -11), 3.0, wm, 0.3)
	# the passage wall's room side, lined like the rest of the room (round the doorway)
	for seg in [[-20.85, -16.55], [-15.45, -11.15]]:
		Geo.box(self, Vector3(-12.56, 1.425, (seg[0] + seg[1]) * 0.5), Vector3(0.02, 2.85, seg[1] - seg[0]), wm, false)
	Geo.box(self, Vector3(-12.56, 2.5, -16.0), Vector3(0.02, 0.7, 1.1), wm, false)
	# light: linear fittings over the desks and the south end; the CCTV room's own fitting is dead (the screens light it)
	var z: LightZone = zones.secoffice
	var tube := Color(1.0, 0.96, 0.9)
	z.add_panel(Vector3(-15.65, 2.82, -18.5), Vector2(0.22, 3.0), true, 0.9, 7.5, tube, true)
	z.add_panel(Vector3(-17.95, 2.82, -13.3), Vector2(0.2, 2.6), true, 0.8, 7.0, tube)
	z.add_panel(Vector3(-14.0, 2.82, -13.3), Vector2(0.2, 2.6), true, 0.8, 7.0, tube)
	z.add_hum(Vector3(-15.8, 2.6, -15.5), -26.0)
	Geo.box(self, Vector3(-18.3, 2.82, -18.4), Vector3(0.22, 0.06, 1.6), Mats.std(Color(0.72, 0.72, 0.7), 0.5, 0.3), false)
	Geo.box(self, Vector3(-18.3, 2.785, -18.4), Vector3(0.12, 0.02, 1.5), Mats.std(Color(0.3, 0.3, 0.29), 0.4), false)
	# overhead: a ceiling fan turning over the middle, a duct along the north wall with its grilles, ceiling and wall
	# vents, a smoke detector, the team's plate hung over the island
	OfficeKit.ceiling_fan(self, Vector3(-15.6, 0, -14.9), 2.85)
	var duct := Mats.std(Color(0.7, 0.71, 0.72), 0.45, 0.6)
	Geo.cyl(self, Vector3(-15.6, 2.64, -20.6), 0.12, 3.2, duct).rotation.z = PI / 2
	for dx in [-17.2, -14.0]:
		Geo.cyl(self, Vector3(dx, 2.76, -20.6), 0.125, 0.2, duct)
	for gx in [-16.1, -14.7]:
		OfficeKit.vent_grille(self, Vector3(gx, 2.64, -20.475), 0.0, Vector2(0.2, 0.13))
	OfficeKit.vent_grille(self, Vector3(-13.4, 2.845, -19.0), 0.0, Vector2(0.5, 0.5), PI / 2)
	OfficeKit.vent_grille(self, Vector3(-19.0, 2.845, -12.3), 0.0, Vector2(0.5, 0.5), PI / 2)
	OfficeKit.vent_grille(self, Vector3(-17.8, 2.45, -11.155), PI, Vector2(0.55, 0.25))
	Geo.cyl(self, Vector3(-16.6, 2.83, -13.0), 0.06, 0.03, Mats.get_mat("plastic_white"))
	var team := Node3D.new()
	add_child(team)
	team.position = Vector3(-15.65, 2.48, -17.4)
	Geo.box(team, Vector3.ZERO, Vector3(0.8, 0.2, 0.025), Mats.std(Color(0.9, 0.89, 0.84), 0.6), false)
	for side in [0.0, PI]:
		var l := Geo.label(team, "보안관리팀", Vector3(0, 0, 0.0135 * cos(side)), side, 48, Color(0.1, 0.12, 0.3), 0.003, false, "print")
		Geo.fit(l, 0.68, 0.14)
	for sx in [-0.3, 0.3]:
		Geo.cyl(team, Vector3(sx, 0.235, 0), 0.004, 0.27, Mats.get_mat("metal"))
	# north wall: the window (roller blind most of the way down) with the clock beside it, the tall document cabinet,
	# lateral cabinets under the window, the filing cabinet, the store-room door
	OfficeKit.roller_window(self, Vector3(-15.25, 1.7, -20.84), 0.0, Vector2(1.5, 1.25), 0.85)
	var clock := Node3D.new()
	add_child(clock)
	clock.position = Vector3(-16.78, 2.3, -20.82)
	Geo.cyl(clock, Vector3.ZERO, 0.18, 0.04, Mats.get_mat("plastic_white")).rotation.x = PI / 2
	Geo.label(clock, "2:17", Vector3(0, 0, 0.03), 0.0, 32, Color(0.1, 0.1, 0.1), 0.003, true, "lcd")
	OfficeKit.steel_cabinet(self, Vector3(-16.68, 0, -20.6), 0.0, Vector3(1.1, 1.8, 0.45),
			["보안문서 85–90", "출입 기록", "근무 일지", "CCTV 녹화 대장"])
	OfficeKit.carton(self, Vector3(-16.95, 1.8, -20.6), Vector3(0.4, 0.22, 0.34), 0.06)
	OfficeKit.bundle(self, Vector3(-16.45, 1.8, -20.62), 0.1)
	OfficeKit.bundle(self, Vector3(-16.43, 1.88, -20.6), -0.15)
	OfficeKit.carton(self, Vector3(-17.0, 0, -20.12), Vector3(0.38, 0.3, 0.32), 0.1)
	OfficeKit.carton(self, Vector3(-16.98, 0.3, -20.12), Vector3(0.34, 0.24, 0.3), -0.2)
	Geo.blocker(self, Vector3(-17.0, 0.27, -20.12), Vector3(0.4, 0.54, 0.36))
	var lat: Array = []
	lat.append_array(OfficeKit.lateral_cabinet(self, Vector3(-15.6, 0, -20.61), 0.0))
	lat.append_array(OfficeKit.lateral_cabinet(self, Vector3(-14.775, 0, -20.61), 0.0, 0.65))
	OfficeKit.binders(self, Vector3(-16.0, 0.74, -20.55), 0.0, 6, 31)
	OfficeKit.trays(self, Vector3(-15.35, 0.74, -20.6), 0.0, 2)
	OfficeKit.paper_stack(self, Vector3(-14.9, 0.74, -20.6), 9, 0.1)
	OfficeKit.radio_base(self, Vector3(-14.65, 0.74, -20.5), 0.0)
	sec_closet = OfficeKit.door(self, Vector3(-13.3, 0, -21.0), -PI / 2)
	LevelKit.plate(self, "plate_storage", Vector3(-13.3, 2.42, -20.84), 0.0, Vector2(0.45, 0.3), 0.0)
	# west wall: the CCTV room (north of the west door), the west door, a notice board, the CRT desk, the night-duty
	# room's door at the south end
	sec_entry = OfficeKit.door(self, Vector3(-20.0, 0, -14.6), 0.0)
	LevelKit.plate(self, "plate_staffonly", Vector3(-19.84, 2.42, -14.6), 90.0, Vector2(0.42, 0.28), 0.0)
	var dorm := OfficeKit.door(self, Vector3(-20.0, 0, -11.75), 0.0, "숙직실")
	OfficeKit.notice_board(self, Vector3(-19.85, 1.55, -15.6), PI / 2, Vector2(0.42, 0.52), 23)
	Geo.cyl(self, Vector3(-19.72, 0.3, -15.55), 0.075, 0.5, Mats.std(Color(0.75, 0.08, 0.06), 0.35, 0.2))
	Geo.box(self, Vector3(-19.72, 0.6, -15.55), Vector3(0.05, 0.08, 0.05), Mats.get_mat("metal_dark"), false)
	OfficeKit.notice_board(self, Vector3(-19.85, 1.68, -13.2), PI / 2, Vector2(1.2, 0.72), 17)
	_cctv_room()
	# the desks: the CRT desk on the west wall, one in front of it, the island of four in the middle
	var desk := Vector3(1.5, OfficeKit.DESK_H, 0.75)
	var sets := {
		"a": OfficeKit.desk(self, Vector3(-19.43, 0, -13.2), PI / 2, Vector3(1.6, OfficeKit.DESK_H, 0.75), -1.0),
		"c": OfficeKit.desk(self, Vector3(-14.9, 0, -17.775), PI, desk, -1.0),
		"f": OfficeKit.filing_cabinet(self, Vector3(-14.2, 0, -20.53), 0.0),
		"l": lat,
	}
	OfficeKit.desk(self, Vector3(-17.3, 0, -13.25), 0.0, Vector3(1.4, OfficeKit.DESK_H, 0.7), 1.0, false)
	OfficeKit.desk(self, Vector3(-16.4, 0, -17.025), 0.0, desk, -1.0, false)
	OfficeKit.desk(self, Vector3(-14.9, 0, -17.025), 0.0, desk, 1.0, false)
	OfficeKit.desk(self, Vector3(-16.4, 0, -17.775), PI, desk, 1.0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2170
	for k: String in sets:
		var arr: Array = sets[k]
		for i in arr.size():
			var dr: Drawer = arr[i]
			sec_drawers["%s%d" % [k, i + 1]] = dr
			OfficeKit.clutter(dr.inside, rng, dr.size.x, dr.size.z)
	var top := Vector2(desk.x, desk.z)
	OfficeKit.dress(self, Vector3(-19.43, 0, -13.2), PI / 2, Vector2(1.6, 0.75), [["blotter", -0.1, 0.15], ["pc", 0.3, -0.25],
			["phone_beige", -0.6, -0.3, 0.3], ["pile", -0.7, 0.45, 0.2], ["trays", 0.85, -0.35], ["pens", -0.25, -0.65],
			["mug", 0.85, 0.55]], 3)
	OfficeKit.dress(self, Vector3(-17.3, 0, -13.25), 0.0, Vector2(1.4, 0.7), [["blotter", 0.0, 0.2], ["pc_form", -0.4, -0.2],
			["binders", 0.2, -0.62], ["phone", 0.75, 0.2, -0.3], ["pile", 0.3, 0.45, 0.15], ["ashtray", -0.85, 0.55],
			["pens", -0.85, -0.2]], 5)
	OfficeKit.dress(self, Vector3(-16.4, 0, -17.025), 0.0, top, [["blotter", 0.15, 0.2], ["typewriter", 0.1, 0.0],
			["bundle", 0.7, -0.45, 0.15], ["bundle", 0.68, -0.45, -0.1, 0.08], ["phone", -0.75, -0.35, 0.4],
			["pile", 0.7, 0.4, -0.2], ["ashtray", -0.4, 0.55], ["pens", -0.85, 0.15]], 7)
	OfficeKit.dress(self, Vector3(-14.9, 0, -17.025), 0.0, top, [["blotter", 0.1, 0.2], ["pc", -0.3, -0.25],
			["phone_beige", 0.2, -0.45, -0.2], ["trays", 0.55, -0.4], ["pens", 0.85, 0.25], ["pile", 0.3, 0.45, 0.15],
			["mug", -0.85, 0.45]], 9)
	OfficeKit.dress(self, Vector3(-16.4, 0, -17.775), PI, top, [["blotter", 0.0, 0.2], ["books", -0.55, -0.35, 0.2],
			["binders", -0.2, -0.62], ["phone_beige", 0.7, -0.3, -0.3], ["fan", -0.8, 0.45, 0.5], ["mug", 0.45, 0.5],
			["pile", 0.1, 0.35, -0.15]], 11)
	OfficeKit.dress(self, Vector3(-14.9, 0, -17.775), PI, top, [["blotter", 0.05, 0.2], ["lamp", 0.75, -0.5, -0.5],
			["radio", -0.5, -0.35], ["phone", 0.25, -0.4, 0.15], ["ledger", -0.05, 0.4, 0.08], ["pile", 0.6, 0.35, 0.3],
			["mug", -0.82, 0.5], ["bundle", -0.15, -0.5, 0.1]], 13)
	# the island's low divider, notes pinned on it
	Geo.box(self, Vector3(-15.65, OfficeKit.DESK_H + 0.15, -17.4), Vector3(3.0, 0.3, 0.02), Mats.std(Color(0.42, 0.44, 0.42), 0.6), false)
	for i in 6:
		var note := Geo.box(self, Vector3(-16.9 + i * 0.5, OfficeKit.DESK_H + 0.2 + 0.03 * (i % 2), -17.4 + (0.0115 if i % 2 == 0 else -0.0115)),
				Vector3(0.1, 0.12, 0.001), Mats.std(Color(0.95, 0.9, 0.6), 0.9) if i % 3 == 0 else Mats.get_mat("paper"), false)
		note.rotation.z = (i % 3 - 1) * 0.08
	for c in [[Vector3(-18.65, 0, -13.55), -PI / 2], [Vector3(-14.9, 0, -16.25), PI - 0.2], [Vector3(-15.3, 0, -18.62), -0.25]]:
		if TripoProps.exists("security", "SEC_OfficeChair"):
			TripoProps.spawn(self, "security", "SEC_OfficeChair", c[0], c[1], true)
		else:
			Geo.box(self, c[0] + Vector3(0, 0.45, 0), Vector3(0.5, 0.08, 0.5), Mats.get_mat("seat"))
	OfficeKit.steel_chair(self, Vector3(-17.4, 0, -12.5), PI)
	OfficeKit.steel_chair(self, Vector3(-16.25, 0, -16.2), PI + 0.15)
	OfficeKit.steel_chair(self, Vector3(-16.55, 0, -18.6), 0.1)
	# east wall: the bookshelf and the staff lockers (a wall fan over them) north of the reader, the key box and the
	# extinguisher by the passage door, the radio chargers over a low cabinet with the calendar above, the glass cabinet
	OfficeKit.bookshelf(self, Vector3(-12.74, 0, -19.27), -PI / 2)
	OfficeKit.lockers(self, Vector3(-12.8, 0, -18.07), -PI / 2, 3, ["김민호", "이재훈", "박상철"], 1, 1)
	OfficeKit.carton(self, Vector3(-12.85, 1.8, -18.3), Vector3(0.4, 0.26, 0.36), 0.1)
	OfficeKit.fan(self, Vector3(-12.86, 2.35, -17.7), -PI / 2)
	OfficeKit.key_box(self, Vector3(-12.55, 1.55, -14.85), -PI / 2)
	Geo.cyl(self, Vector3(-12.68, 0.3, -15.2), 0.075, 0.5, Mats.std(Color(0.75, 0.08, 0.06), 0.35, 0.2))
	Geo.box(self, Vector3(-12.68, 0.6, -15.2), Vector3(0.05, 0.08, 0.05), Mats.get_mat("metal_dark"), false)
	OfficeKit.low_cabinet(self, Vector3(-12.76, 0, -13.2), -PI / 2, Vector3(1.3, 0.85, 0.42))
	OfficeKit.mug(self, Vector3(-12.78, 0.85, -12.75))
	OfficeKit.paper_stack(self, Vector3(-12.78, 0.85, -13.55), 5, 0.3)
	Geo.box(self, Vector3(-12.74, 1.0, -13.2), Vector3(0.34, 0.04, 1.3), Mats.get_mat("steel_frame"), false)
	for i in 4:
		var rz := -13.65 + i * 0.3
		Geo.box(self, Vector3(-12.72, 1.06, rz), Vector3(0.14, 0.08, 0.16), Mats.get_mat("plastic_dark"), false)
		Geo.box(self, Vector3(-12.72, 1.2, rz), Vector3(0.035, 0.2, 0.06), Mats.get_mat("plastic_grey"), false)
		Geo.cyl(self, Vector3(-12.72, 1.38, rz + 0.02), 0.006, 0.16, Mats.get_mat("plastic_dark"))
		Geo.box(self, Vector3(-12.647, 1.06, rz + 0.05), Vector3(0.004, 0.015, 0.015), Mats.get_mat("lamp_green"), false)
	OfficeKit.wall_calendar(self, Vector3(-12.555, 1.88, -13.2), -PI / 2)
	OfficeKit.glass_cabinet(self, Vector3(-12.76, 0, -11.72), -PI / 2)
	sec_reader = CardReader.create(self, Vector3(-12.575, 1.2, -16.85), -PI / 2)
	sec_reader.interactable.enabled = false
	# south wall: lockers, the whiteboard, a notice board over the table of cartons, the water cooler; the coat rack,
	# the armchair, bins
	OfficeKit.lockers(self, Vector3(-17.8, 0, -11.4), PI, 5, ["최영식", "한동수", "", "오세진", "윤기철"], 3, 4)
	OfficeKit.carton(self, Vector3(-18.4, 1.8, -11.42), Vector3(0.44, 0.3, 0.4), -0.1)
	OfficeKit.carton(self, Vector3(-17.5, 1.8, -11.4), Vector3(0.36, 0.22, 0.34), 0.2)
	var wb := Node3D.new()
	add_child(wb)
	wb.position = Vector3(-15.75, 1.55, -11.165)
	wb.rotation.y = PI
	Geo.box(wb, Vector3.ZERO, Vector3(1.6, 1.0, 0.03), Mats.get_mat("plastic_white"), false)
	Geo.box(wb, Vector3(0, -0.52, 0.03), Vector3(1.5, 0.03, 0.06), Mats.get_mat("metal"), false)
	Geo.fit(Geo.label(wb, "야간 점검  02:00 – 05:00\n수하물 구역 — 출입 통제\n직원 통로 소등 유지\n이상 시 즉시 무전 보고", Vector3(-0.08, 0.04, 0.02),
			0.0, 30, Color(0.1, 0.2, 0.6), 0.0035, false, "hand"), 1.4).rotation.z = 0.02
	OfficeKit.notice_board(self, Vector3(-14.2, 1.62, -11.15), PI, Vector2(1.0, 0.68), 11)
	Geo.box(self, Vector3(-14.2, 0.72, -11.5), Vector3(1.1, 0.04, 0.58), Mats.get_mat("wood"), false)
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(-14.2 + sx * 0.52, 0.35, -11.5), Vector3(0.04, 0.7, 0.54), Mats.get_mat("metal_dark"), false)
	Geo.blocker(self, Vector3(-14.2, 0.37, -11.5), Vector3(1.1, 0.74, 0.58))
	OfficeKit.carton(self, Vector3(-14.4, 0.74, -11.5), Vector3(0.44, 0.3, 0.36), -0.1)
	OfficeKit.carton(self, Vector3(-13.85, 0.74, -11.45), Vector3(0.3, 0.22, 0.3), 0.2)
	OfficeKit.carton(self, Vector3(-14.35, 1.04, -11.48), Vector3(0.32, 0.18, 0.3), 0.3)
	OfficeKit.carton(self, Vector3(-14.3, 0, -11.5), Vector3(0.5, 0.36, 0.4), 0.05)
	OfficeKit.water_cooler(self, Vector3(-13.35, 0, -11.42), PI)
	OfficeKit.trash_can(self, Vector3(-15.3, 0, -11.38))
	OfficeKit.trash_can(self, Vector3(-17.05, 0, -16.35), Color(0.55, 0.56, 0.55))
	OfficeKit.coat_rack(self, Vector3(-14.85, 0, -12.2), 0.4)
	# the floor between the start and the desks: the AV cart turned to the room, a pile of cartons by the south desk
	OfficeKit.av_cart(self, Vector3(-14.35, 0, -13.5), -0.8, 6.0)
	OfficeKit.carton(self, Vector3(-16.3, 0, -13.1), Vector3(0.42, 0.34, 0.38), 0.2)
	OfficeKit.carton(self, Vector3(-16.28, 0.34, -13.12), Vector3(0.36, 0.26, 0.32), -0.15)
	OfficeKit.bundle(self, Vector3(-16.3, 0.6, -13.1), 0.4)
	Geo.blocker(self, Vector3(-16.3, 0.34, -13.1), Vector3(0.45, 0.68, 0.42))
	OfficeKit.armchair(self, Vector3(-13.65, 0, -12.75), -2.4)
	# outside the west door: a short dark vestibule (black, no light), its far wall where the way in arrives
	var black := Mats.get_mat("black")
	Geo.box(self, Vector3(-21.25, -0.05, -14.6), Vector3(2.3, 0.1, 2.9), black)
	Geo.box(self, Vector3(-21.25, 2.55, -14.6), Vector3(2.3, 0.1, 2.9), black, false)
	for sz in [-1.0, 1.0]:
		Geo.box(self, Vector3(-21.25, 1.3, -14.6 + sz * 1.4), Vector3(2.3, 2.6, 0.1), black)
	sec_vestibule_end = Geo.box(self, Vector3(-22.35, 1.3, -14.6), Vector3(0.1, 2.6, 2.9), black)
	_security_door()
	for dd: Dictionary in [sec_entry, sec_closet, dorm]:
		var d := dd
		(d.use as Interactable).callback = func(): rattle(d)


## The CCTV room (CCTV 관제실) in the security office's north-west corner, behind a wired-glass partition with its
## doorway on the south (the Evil Within reference): an L of console along the west and north walls — built-in CRTs,
## control panels, a reel deck, open under the worktop where the operator sits — under a bank of two rows of CRT
## monitors (cameras, static, dead ones), a rack of VCRs, a folding chair, a side table with an ashtray and a keyboard,
## cartons, cables over the floor, its fitting dead: the screens' green glow lights it.
func _cctv_room() -> void:
	OfficeKit.partition(self, Vector2(-17.3, -20.85), Vector2(-17.3, -15.96), 2.85)
	OfficeKit.partition(self, Vector2(-19.85, -16.0), Vector2(-17.34, -16.0), 2.85, [[1.25, 2.15]])
	OfficeKit.tag(self, Vector3(-18.15, 2.48, -15.958), 0.0, "CCTV 관제실", Vector2(0.62, 0.16))
	OfficeKit.tag(self, Vector3(-19.05, 1.45, -15.955), 0.0, "관계자 외 출입금지", Vector2(0.34, 0.08), Color(0.95, 0.85, 0.8))
	for p in [Vector3(-19.4, 1.7, -15.954), Vector3(-17.55, 1.35, -15.954), Vector3(-17.256, 1.6, -18.2)]:
		var sheet := Geo.box(self, p, Vector3(0.21, 0.29, 0.001) if p.x < -17.3 else Vector3(0.001, 0.29, 0.21), Mats.get_mat("paper"), false)
		sheet.rotation.z = 0.04
	# the console: the west run in three (closed, open under the operator, closed) and the north run
	var cells := [[-20.05, 1.6, ["panel", "snow", "crt"], false], [-18.55, 1.4, ["crt", "crt"], true], [-17.325, 1.05, ["off", "panel"], false]]
	for i in cells.size():
		var c: Array = cells[i]
		OfficeKit.console(self, Vector3(-19.85, 0, c[0]), PI / 2, c[1], c[2], 41 + i, c[3])
	OfficeKit.console(self, Vector3(-18.26, 0, -20.85), 0.0, 1.62, ["off", "deck", "panel"], 47)
	Geo.box(self, Vector3(-19.29, 1.07, -20.68), Vector3(0.44, 0.58, 0.34), Mats.std(Color(0.2, 0.22, 0.22), 0.55, 0.45), false)
	OfficeKit.phone(self, Vector3(-19.3, 1.36, -20.66), 0.6, true)
	# on the worktop: the log, a keyboard, a mug, papers, an ashtray
	OfficeKit.paper_stack(self, Vector3(-19.3, 0.778, -18.95), 5, 0.3)
	Geo.box(self, Vector3(-19.24, 0.79, -18.45), Vector3(0.15, 0.022, 0.44), Mats.get_mat("plastic_dark"), false, 0.08)
	OfficeKit.mug(self, Vector3(-19.28, 0.778, -17.95))
	OfficeKit.bundle(self, Vector3(-19.3, 0.778, -17.3), 0.2)
	OfficeKit.paper_stack(self, Vector3(-18.0, 0.778, -20.3), 6, 0.2)
	OfficeKit.ashtray(self, Vector3(-17.7, 0.778, -20.32))
	# the bank of monitors over it, top row first
	OfficeKit.crt_bank(self, Vector3(-19.85, 0, -18.825), PI / 2, 4.05,
			["crt", "snow", "crt", "off", "crt", "crt", "snow", "crt", "off", "crt", "crt", "crt", "snow", "crt", "off", "crt"], 3)
	OfficeKit.crt_bank(self, Vector3(-18.42, 0, -20.85), 0.0, 1.94, ["crt", "snow", "off", "crt", "crt", "crt", "snow", "off"], 4)
	OfficeKit.vcr_rack(self, Vector3(-17.58, 0, -19.4), -PI / 2)
	OfficeKit.folding_chair(self, Vector3(-18.25, 0, -18.55), -PI / 2 + 0.25)
	# the side table by the doorway: ashtray, a keyboard, papers
	var tbl := Mats.std(Color(0.3, 0.31, 0.3), 0.4, 0.6)
	Geo.box(self, Vector3(-17.58, 0.7, -17.55), Vector3(0.36, 0.03, 0.42), Mats.std(Color(0.5, 0.5, 0.48), 0.5, 0.4), false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.cyl(self, Vector3(-17.58 + sx * 0.15, 0.35, -17.55 + sz * 0.18), 0.012, 0.7, tbl)
	Geo.blocker(self, Vector3(-17.58, 0.36, -17.55), Vector3(0.36, 0.72, 0.42))
	OfficeKit.ashtray(self, Vector3(-17.6, 0.715, -17.68))
	Geo.box(self, Vector3(-17.55, 0.727, -17.42), Vector3(0.14, 0.022, 0.36), Mats.get_mat("plastic_dark"), false, 0.1)
	OfficeKit.paper_stack(self, Vector3(-17.6, 0.715, -17.6), 4, 0.6)
	# cartons in the corner and under the console, cables over the floor
	OfficeKit.carton(self, Vector3(-19.45, 0, -16.42), Vector3(0.5, 0.4, 0.4), 0.1)
	OfficeKit.carton(self, Vector3(-19.42, 0.4, -16.45), Vector3(0.4, 0.28, 0.34), -0.2)
	OfficeKit.carton(self, Vector3(-18.95, 0, -16.4), Vector3(0.36, 0.3, 0.32), 0.3)
	Geo.blocker(self, Vector3(-19.2, 0.34, -16.42), Vector3(0.95, 0.68, 0.45))
	OfficeKit.carton(self, Vector3(-19.5, 0, -18.9), Vector3(0.4, 0.32, 0.35), 0.2)
	OfficeKit.carton(self, Vector3(-19.45, 0, -18.25), Vector3(0.34, 0.26, 0.3), -0.3)
	var cable := Mats.std(Color(0.05, 0.05, 0.055), 0.6)
	for cb in [[Vector3(-18.9, 0.006, -18.0), 1.3, 0.5], [Vector3(-18.7, 0.006, -17.2), 1.1, -0.35], [Vector3(-18.4, 0.006, -19.4), 1.2, 1.2]]:
		Geo.box(self, cb[0], Vector3(cb[1], 0.012, 0.012), cable, false, cb[2])
	var glow := Geo.omni(self, Vector3(-18.6, 1.7, -18.7), Color(0.5, 0.82, 0.74), 0.75, 4.5)
	glow.light_specular = 0.3
	glow.light_volumetric_fog_energy = 0.2


## The security office's door: a steel leaf with a narrow wired-glass light, a push plate on the passage side and a
## pull handle in the room, hung on the south jamb; it opens into the room. Shut and dead to [E] until the story
## gives it a prompt and a callback.
func _security_door() -> void:
	sec_passage = steel_door(self, Vector3(-12.4, 0.0, -16.0))     # on the wall's centre line; local +X = the passage
	sec_door = sec_passage.root
	sec_door.name = "SecurityDoor"
	sec_leaf = sec_passage.leaf
	sec_block = sec_passage.block
	sec_use = sec_passage.use
	sec_use.enabled = false
	# its plate beside it on the passage side, and the way to it hung over the passage
	var plate := Node3D.new()
	add_child(plate)
	plate.position = Vector3(-12.238, 1.55, -15.05)
	plate.rotation.y = PI / 2
	Geo.box(plate, Vector3.ZERO, Vector3(0.5, 0.2, 0.012), Mats.std(Color(0.16, 0.17, 0.19), 0.45, 0.3), false)
	Geo.fit(Geo.label(plate, "보안실  SECURITY OFFICE", Vector3(0, 0, 0.008), 0.0, 40, Color(0.95, 0.95, 0.92), 0.003), 0.44, 0.15).set_meta("no_fit", true)
	sec_signs = [plate, LevelKit.hanging_sign(self, Vector3(-11.25, 3.0, -25.5), 0.0, "SECURITY OFFICE  →\n보안실", 1.9, "")]


## A steel door in a wall along local Z (its centre line at local x 0, `pos`; local +X = the side with the push plate):
## a narrow wired-glass light, a pull handle on the -X side, hung on its +Z jamb; it opens toward -X (rotation.y > 0).
## Returns {root, leaf, block, use}; the use is "문 열기" with no callback. The security office's passage door, and the
## same door seen from the far side of it at the service corridor's entrance (ServiceHall).
static func steel_door(parent: Node3D, pos: Vector3, rot_y := 0.0) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	var frame := Mats.std(Color(0.3, 0.32, 0.35), 0.4, 0.6)
	for side in [1.0, -1.0]:
		for sz in [-1.0, 1.0]:
			Geo.box(root, Vector3(side * 0.17, 1.07, sz * 0.53), Vector3(0.07, 2.14, 0.07), frame, false)
		Geo.box(root, Vector3(side * 0.17, 2.18, 0), Vector3(0.07, 0.07, 1.13), frame, false)
	var leaf := Node3D.new()
	root.add_child(leaf)
	leaf.position = Vector3(0.1, 0, 0.49)
	var steel := Mats.std(Color(0.42, 0.45, 0.5), 0.5, 0.45)
	var metal := Mats.get_mat("metal")
	var wired := Mats.std(Color(0.05, 0.06, 0.07), 0.15, 0.3)
	Geo.box(leaf, Vector3(0, 1.05, -0.485), Vector3(0.045, 2.08, 0.96), steel, false)
	for side in [1.0, -1.0]:
		Geo.box(leaf, Vector3(side * 0.024, 1.5, -0.75), Vector3(0.006, 0.5, 0.13), wired, false)
		Geo.box(leaf, Vector3(side * 0.025, 0.14, -0.485), Vector3(0.004, 0.24, 0.9), metal, false)
	Geo.box(leaf, Vector3(0.027, 1.08, -0.84), Vector3(0.008, 0.32, 0.1), metal, false)      # push plate
	Geo.box(leaf, Vector3(-0.07, 1.05, -0.84), Vector3(0.028, 0.32, 0.028), metal, false)    # pull handle
	for hy in [0.92, 1.18]:
		Geo.box(leaf, Vector3(-0.045, hy, -0.84), Vector3(0.05, 0.025, 0.025), metal, false)
	var block := Geo.blocker(root, Vector3(0.0, 1.07, 0), Vector3(0.3, 2.14, 1.0))
	var use := Interactable.create(root, Vector3(0.0, 1.1, 0.0), Vector3(1.0, 2.1, 1.1), "문 열기", Callable())
	use.press_sound = ""
	return {"root": root, "leaf": leaf, "block": block, "use": use}


## The chase: the security office's door is gone. The doorway is plain passage wall again (the same world-space
## material, so no seam), and its plate and the sign to it go with it.
func remove_security_door() -> void:
	if not sec_door.visible:
		return
	sec_door.visible = false
	sec_block.collision_layer = 0
	sec_use.enabled = false
	for n in sec_signs:
		n.visible = false
	Geo.box(self, Vector3(-12.4, 1.075, -16.0), Vector3(0.3, 2.15, 1.0), Mats.get_mat("wall_service"))


## A locked door tried ({root, leaf, block, use}): it rattles in its frame (door_rattle) and the leaf jiggles.
func rattle(door: Dictionary) -> void:
	var leaf: Node3D = door.leaf
	if leaf.has_meta("rattling"):
		return
	leaf.set_meta("rattling", true)
	Snd.play_at(Snd.variant("door_rattle"), (door.root as Node3D).global_position + Vector3(0, 1.0, 0), -3.0, randf_range(0.95, 1.08), 5.0)
	var tw := leaf.create_tween()
	for k in 3:
		tw.tween_property(leaf, "rotation:y", deg_to_rad(randf_range(0.8, 1.5)), 0.05)
		tw.tween_property(leaf, "rotation:y", 0.0, 0.07)
		tw.tween_interval(randf_range(0.1, 0.16))
	tw.tween_callback(func(): leaf.remove_meta("rattling"))


## Swings a door ({root, leaf, block, use}) to `deg` into the room (0 = shut) over `time` s; its collider goes with it.
func swing_door(door: Dictionary, deg: float, time: float) -> Tween:
	(door.block as StaticBody3D).collision_layer = 0 if deg > 1.0 else Geo.LAYER_WORLD
	var leaf: Node3D = door.leaf
	var tw := leaf.create_tween()
	tw.tween_property(leaf, "rotation:y", deg_to_rad(deg), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if deg > 1.0 else Tween.EASE_IN)
	return tw


## Swings the security office's door: `deg` into the room (0 = shut) over `time` s; its collider goes with it.
func swing_sec_door(deg: float, time: float) -> Tween:
	sec_block.collision_layer = 0 if deg > 1.0 else Geo.LAYER_WORLD
	var tw := sec_leaf.create_tween()
	tw.tween_property(sec_leaf, "rotation:y", deg_to_rad(deg), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


# --------------------------------------------------------------------------------------------
func _build_security() -> void:
	var r: Rect2 = ZONE_RECTS.security
	_floor(r, "floor")
	_ceiling(r, SEC_H)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-10, -27.3), Vector2(-10, -8.5), SEC_H + 0.2, wm)
	Geo.wall(self, Vector2(10, -27.3), Vector2(10, -8.5), SEC_H + 0.2, wm)
	Geo.wall(self, Vector2(-10, -27.3), Vector2(10, -27.3), SEC_H + 0.2, wm, 0.4, [[6.0, 14.0, 3.4]])
	shutters["security"] = Shutter.create(self, Vector3(0, 0, -8.5), 0.0, 12.0, SEC_H, "점검 구역 외 · 통제")
	shutters["corridor"] = Shutter.create(self, Vector3(0, 0, -27.3), 0.0, 8.0, 3.4, "점검 구역 외 · 통제")
	# coffered ceiling: beams on a 3 m grid, a troffer in every coffer (some lit)
	var bm := Mats.std(Color(0.8, 0.8, 0.78), 0.8)
	for zz in [-11.5, -14.5, -17.5, -20.5, -23.5]:
		Geo.box(self, Vector3(0, SEC_H - 0.225, zz), Vector3(20, 0.45, 0.4), bm, false)
	for x in [-7.0, -4.0, -1.0, 2.0, 5.0, 8.0]:     # 1 cm shallower than the cross beams so the crossings never fight
		Geo.box(self, Vector3(x, SEC_H - 0.22, -17.9), Vector3(0.38, 0.44, 18.8), bm, false)
	var z: LightZone = zones.security
	for x in [-8.5, -5.5, -2.5, 0.5, 3.5, 6.5, 9.0]:
		for zz in [-10.0, -13.0, -16.0, -19.0, -22.0, -25.4]:
			var lit: bool = x in [-5.5, 0.5, 6.5] and zz in [-10.0, -16.0, -22.0]
			z.add_panel(Vector3(x, SEC_H - 0.04, zz), Vector2(1.1, 0.5), lit, 1.3, 9.0)
	z.add_hum(Vector3(0, 3.8, -18), -20.0)
	for x: float in LANE_X:
		LevelKit.metal_detector(self, Vector3(x + MD_DX, 0, LANE_Z))
		# queue line beside the detector approach
		LevelKit.stanchions(self, [Vector3(x + MD_DX + 0.8, 0, -12.6), Vector3(x + MD_DX + 0.8, 0, -14.4), Vector3(x + MD_DX + 0.8, 0, -16.2)])
	for i in LANE_X.size():
		LevelKit.hanging_sign(self, Vector3(LANE_X[i] + 1.2, SEC_H, -13.0), 0.0, tr("수하물 검색 %d\nBAGGAGE INSPECTION %d") % [i + 1, i + 1])
	# repacking benches along both side walls
	for zz in [-14.85, -16.95, -19.05, -21.15]:
		LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(-9.45, 0, zz), 90.0)
		LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(9.45, 0, zz), -90.0)
	signs["security_main"] = Props.hanging_sign(self, Vector3(0, 2.55, -26.0), 0.0, Vector2(6.0, 0.9), [
		["@icon_departures", 0.62, Color(1, 1, 1), Vector2(-2.45, 0.0)],
		["↑  탑승동  GATES 01 — 04", 52, Color(1, 1, 1), Vector2(0.35, 0.12)],
		["무빙워크 MW-1", 34, Color(0.8, 0.85, 0.95), Vector2(0.35, -0.24)],
	], SEC_H)
	Props.lightbox(self, Vector3(-9.78, 2.2, -11.2), PI / 2, Vector2(2.6, 1.2), "액체류 100ml 제한", "LIQUIDS LIMIT 100ml")
	Props.lightbox(self, Vector3(9.78, 2.2, -11.2), -PI / 2, Vector2(2.6, 1.2), "보안검색  SECURITY", "탑승권을 준비해 주세요")
	# tray stack at the lane entry
	LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(-7.6, 0, -10.4), 0.0)
	for i in 5:
		Geo.box(self, Vector3(-7.6, 0.82 + i * 0.07, -10.4), Vector3(0.6, 0.06, 0.45), Mats.std(Color(0.3, 0.32, 0.36), 0.5), false)


# --------------------------------------------------------------------------------------------
func _build_corridor() -> void:
	var r: Rect2 = ZONE_RECTS.corridor
	_floor(r, "floor")
	_ceiling(r, COR_H)
	var wm := Mats.get_mat("wall")
	# west: glazed white tile, the public opening into baggage claim (opens with the corridor)
	Geo.wall(self, Vector2(-10, -76), Vector2(-10, -27.3), COR_H, Mats.get_mat("wall_tile"), 0.4, [[24.0, 30.0, 3.0]])
	var bs := Shutter.create(self, Vector3(-10, 0, -49), PI / 2, 6.0, 3.0, "점검 구역 외 · 통제")
	shutters["corridor_baggage"] = bs
	# east windows onto the apron
	var frame := Mats.get_mat("steel_frame")
	var len_z := 48.7
	var cz := -51.65
	Geo.box(self, Vector3(10, 0.4, cz), Vector3(0.4, 0.8, len_z), wm)
	Geo.box(self, Vector3(10, 4.25, cz), Vector3(0.4, 0.5, len_z), wm, false)
	Geo.box(self, Vector3(10, 2.4, cz), Vector3(0.04, 3.2, len_z), Mats.get_mat("glass"), false)
	Geo.blocker(self, Vector3(10, 2.25, cz), Vector3(0.4, 4.5, len_z))
	var zz := -27.3
	while zz >= -76.0:
		Geo.box(self, Vector3(10, 2.4, zz), Vector3(0.22, 3.2, 0.14), frame, false)
		zz -= 4.0
	Geo.box(self, Vector3(9.7, 0.82, cz), Vector3(0.3, 0.05, len_z), frame, false)
	var z: LightZone = zones.corridor
	var lz := -31.0
	var k := 0
	while lz >= -73.0:
		z.add_panel(Vector3(-3.6, COR_H - 0.06, lz), Vector2(0.5, 4.0), true, 1.2, 9.0)
		z.add_panel(Vector3(5.0, COR_H - 0.06, lz - 3.0), Vector2(0.5, 4.0), k % 2 == 0, 1.0, 8.0)
		lz -= 6.0
		k += 1
	z.add_hum(Vector3(0, 4, -40), -22.0)
	z.add_hum(Vector3(0, 4, -64), -22.0)
	# lightbox ads on the west wall
	var ads := [
		["서해국제공항", "바다 위의 첫 관문  SEOHAE INT'L AIRPORT", -31.4],
		["집으로 가는 가장 빠른 길", "The fastest way HOME", -36.2],
		["GRAND OPENING", "2026. 10. 23", -67.0],
		["어디로 떠나시나요?", "Where are you going?", -71.8],
	]
	for a in ads:
		var lb := Props.lightbox(self, Vector3(-9.78, 2.1, a[2]), PI / 2, Vector2(3.2, 1.6), a[0], a[1])
		zones.corridor.add_light(Geo.omni(lb, Vector3(0, 0, 1.0), Color(0.8, 0.88, 1.0), 0.4, 4.0))
	LevelKit.wall_sign(self, Vector3(-9.78, 3.6, -49.0), 90.0, "◀  수하물 수취  BAGGAGE CLAIM", Vector2(3.2, 0.55), "icon_luggage")
	signs["corridor_mid"] = Props.hanging_sign(self, Vector3(-3.0, 3.3, -54.0), 0.0, Vector2(4.6, 0.8), [
		["@icon_departures", 0.56, Color(1, 1, 1), Vector2(-1.75, 0.0)],
		["↑  GATES 01 — 04", 56, Color(1, 1, 1), Vector2(0.35, 0)],
	], COR_H)
	# second walkway (MW-2) beside MW-1, not commissioned yet
	var mw2 := Vector3(6.7, 0, -31.3)
	var run := LevelKit.walkway_run(self, mw2, 8)
	var plate := LevelKit.sign_body(self, mw2 + Vector3(0, 1.25, 0.4), 0.0, Vector2(1.2, 0.42))
	Geo.fit(Geo.label(plate, "MW-2  운행 준비 중\nNOT IN SERVICE", Vector3(0, 0, plate.get_meta("face_z") + 0.004), 0.0, 44, LevelKit.INK, 0.004), 1.1, 0.36).set_meta("no_fit", true)
	Geo.box(self, mw2 + Vector3(0, 0.6, 0.4), Vector3(0.05, 1.2, 0.05), frame, false)
	Geo.blocker(self, mw2 + Vector3(0, 0.6, -run * 0.5), Vector3(1.6, 1.2, run))
	shutters["gates"] = Shutter.create(self, Vector3(0, 0, -76.0), 0.0, 20.0, 4.5, "점검 구역 외 · 통제")
	shutters.corridor.linked.append(bs)


# --------------------------------------------------------------------------------------------
func _build_gates() -> void:
	var r: Rect2 = ZONE_RECTS.gates
	_floor(r, "carpet")
	Geo.box(self, Vector3(0, 0.003, -88), Vector3(6.0, 0.01, 24.0), Mats.get_mat("floor"), false)
	_ceiling(r, 5.5)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-26, -76), Vector2(26, -76), 5.5, wm, 0.4, [[16.0, 36.0, 4.5]])
	Geo.wall(self, Vector2(-26, -100), Vector2(-26, -76), 5.5, wm, 0.4, [[4.7, 7.3, 3.0], [16.7, 19.3, 3.0]])
	Geo.wall(self, Vector2(26, -100), Vector2(26, -76), 5.5, wm, 0.4, [[4.7, 7.3, 3.0], [16.7, 19.3, 3.0]])
	# north window wall (Gate 0 hides in the centre section)
	var frame := Mats.get_mat("steel_frame")
	Geo.box(self, Vector3(-24, 2.75, -100), Vector3(4.0, 5.5, 0.4), wm)
	Geo.box(self, Vector3(24, 2.75, -100), Vector3(4.0, 5.5, 0.4), wm)
	for s in [[-22.0, -1.5], [1.5, 22.0]]:
		var cx: float = (s[0] + s[1]) * 0.5
		var w: float = s[1] - s[0]
		Geo.box(self, Vector3(cx, 0.25, -100), Vector3(w, 0.5, 0.4), wm)
		Geo.box(self, Vector3(cx, 2.75, -100), Vector3(w, 4.5, 0.04), Mats.get_mat("glass"), false)
		Geo.blocker(self, Vector3(cx, 2.75, -100), Vector3(w, 5.5, 0.4))
		Geo.box(self, Vector3(cx, 5.25, -100), Vector3(w, 0.5, 0.4), wm, false)
		var mx: float = s[0]
		while mx <= s[1] + 0.01:
			Geo.box(self, Vector3(mx, 2.75, -100), Vector3(0.14, 4.5, 0.22), frame, false)
			mx += 3.0
	gate0_wall = Node3D.new()
	add_child(gate0_wall)
	Geo.box(gate0_wall, Vector3(0, 2.75, -100), Vector3(3.0, 5.5, 0.6), wm)
	var plaque := Geo.label(gate0_wall, "", Vector3(0, 1.6, -99.68), 0.0, 30, Color(0.4, 0.4, 0.4), 0.004, false, "engrave")
	plaque.name = "Gate0Hint"
	# lights
	var z: LightZone = zones.gates
	# continuous linear slot lights, as in a real gate lounge
	for x in [-18.0, -6.0, 6.0, 18.0]:
		for zz in [-81.0, -88.0, -95.0]:
			z.add_panel(Vector3(x, 5.42, zz), Vector2(10.0, 0.35), true, 2.0, 14.0)
	z.add_hum(Vector3(0, 5, -88), -20.0)
	# central seating facing the windows
	for x in [-9.0, 9.0]:
		for zz in [-85.0, -87.2, -91.5, -93.7]:
			warp.gate_seats.append(Props.seat_row(self, Vector3(x, 0, zz), 8, PI))
	signs["gates_main"] = Props.hanging_sign(self, Vector3(0, 4.2, -79.0), 0.0, Vector2(9.0, 0.9), [
		["◀  GATE 01 · 02", 52, Color(1, 1, 1), Vector2(-2.3, 0)],
		["@icon_departures", 0.62, Color(1, 1, 1), Vector2(0, 0)],
		["GATE 03 · 04  ▶", 52, Color(1, 1, 1), Vector2(2.3, 0)],
	], 5.5)
	for p in [Vector3(-20, 0, -76.5), Vector3(20, 0, -76.5)]:     # against the gate hall's north wall
		Props.trash_bin(self, p)
	for p in [Vector3(-24.5, 0, -98.5), Vector3(24.5, 0, -98.5)]:
		Props.planter(self, p)
	# gate ID wall plates near the corridor
	Props.exit_sign(self, Vector3(-25.75, 2.8, -88), PI / 2, "비상구  EXIT")


# --------------------------------------------------------------------------------------------
func _build_service_rooms() -> void:
	var sm := Mats.get_mat("wall_service")
	# storage room east of the strip (자재창고)
	var sr: Rect2 = ZONE_RECTS.storage
	_floor(sr, "floor_service")
	_ceiling(sr, 3.2, "ceiling_dark")
	Geo.wall(self, Vector2(12, -8.5), Vector2(22, -8.5), 3.2, sm)
	Geo.wall(self, Vector2(22, -8.5), Vector2(22, -2.5), 3.2, sm)
	Geo.wall(self, Vector2(12, -2.5), Vector2(22, -2.5), 3.2, sm)
	var svc: LightZone = zones.service
	svc.add_panel(Vector3(17, 3.15, -5.5), Vector2(1.2, 0.3), true, 0.6, 7.0, Color(1.0, 0.92, 0.75), true)
	for i in 4:
		Geo.box(self, Vector3(16.0, 0.4 + i * 0.6, -8.0), Vector3(6.0, 0.05, 0.6), Mats.get_mat("metal_dark"), false)
	Geo.blocker(self, Vector3(16.0, 1.2, -8.0), Vector3(6.0, 2.4, 0.7))
	for p in [Vector3(14.0, 0.65, -8.0), Vector3(17.0, 1.25, -8.0), Vector3(18.0, 0.65, -8.0)]:
		Geo.box(self, p, Vector3(0.7, 0.4, 0.5), Mats.std(Color(0.45, 0.35, 0.22), 0.8), false)
	for p in [Vector3(20.5, 0.4, -4.0), Vector3(21.0, 0.4, -3.2), Vector3(20.7, 1.1, -3.7)]:
		Geo.box(self, p, Vector3(0.8, 0.8, 0.8), Mats.std(Color(0.5, 0.4, 0.26), 0.85))
	doors["storage"] = SlidingDoor.create(self, Vector3(12, 0, -5.5), PI / 2, 1.8, 2.4, false, true)
	LevelKit.plate(self, "plate_storage", Vector3(11.8, 1.72, -4.05), -90.0, Vector2(0.6, 0.4), 0.3)
	# maintenance passage west of baggage claim
	var mr: Rect2 = ZONE_RECTS.maint
	_floor(mr, "floor_service")
	_ceiling(mr, 3.0, "ceiling_dark")
	Geo.wall(self, Vector2(-48, -53), Vector2(-36, -53), 3.0, sm)
	Geo.wall(self, Vector2(-48, -47), Vector2(-36, -47), 3.0, sm)
	Geo.wall(self, Vector2(-48, -53), Vector2(-48, -47), 3.0, sm)
	svc.add_panel(Vector3(-42, 2.95, -50), Vector2(1.2, 0.3), true, 0.5, 7.0, Color(1.0, 0.92, 0.75))
	for i in 4:
		Geo.cyl(self, Vector3(-46.5 + i * 3.0, 2.6, -47.4), 0.08, 0.1, Mats.get_mat("metal"))
	Geo.box(self, Vector3(-42, 2.6, -47.35), Vector3(12, 0.12, 0.12), Mats.get_mat("metal_dark"), false)
	# main power lever (west end)
	main_power = Equipment.main_power(self, Vector3(-47.78, 1.4, -50), PI / 2)
	# system log terminal (north wall)
	var term := Node3D.new()
	add_child(term)
	term.position = Vector3(-42, 0, -52.5)
	if TripoProps.exists("terminal", "TRM_InfoDesk"):
		TripoProps.spawn(term, "terminal", "TRM_InfoDesk", Vector3.ZERO, PI, false, null, Vector3(1.2, 0.9, 0.6))
		Geo.blocker(term, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6))
	else:
		Geo.box(term, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), Mats.get_mat("metal_dark"))
	var scr := Props.monitor(term, Vector3(0, 0.95, 0.05), 0.0, Vector2(0.5, 0.32))
	scr.material_override = Mats.emissive(Color(0.25, 0.9, 0.4), 0.7)
	syslog_terminal = Interactable.create(term, Vector3(0, 1.0, 0.3), Vector3(0.8, 0.6, 0.4), "시스템 로그 확인", Callable())


# --------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------
func _build_outside() -> void:
	# the airfield's tarmac, open over the aircraft hall (its floor lies a floor down)
	var hole := AirHall.RECT
	var ground := Rect2(-250, -300, 500, 480)
	for r: Rect2 in [Rect2(ground.position.x, ground.position.y, ground.size.x, hole.position.y - ground.position.y),
			Rect2(ground.position.x, hole.end.y, ground.size.x, ground.end.y - hole.end.y),
			Rect2(ground.position.x, hole.position.y, hole.position.x - ground.position.x, hole.size.y),
			Rect2(hole.end.x, hole.position.y, ground.end.x - hole.end.x, hole.size.y)]:
		var c := r.get_center()
		Geo.box(self, Vector3(c.x, -0.2, c.y), Vector3(r.size.x, 0.2, r.size.y), Mats.get_mat("asphalt"), false)
		Geo.blocker(self, Vector3(c.x, -0.15, c.y), Vector3(r.size.x, 0.1, r.size.y))
	var paint := Mats.get_mat("yellow_paint")
	# apron markings (east of the corridor, and south of the lobby glass)
	for i in 12:
		Geo.box(self, Vector3(30.0, -0.09, -40.0 - i * 5.0), Vector3(0.25, 0.01, 3.0), paint, false)
	Geo.box(self, Vector3(0, -0.09, -150), Vector3(0.3, 0.01, 60), paint, false)
	for i in 16:
		if not hole.grow(2.0).has_point(Vector2(-60.0 + i * 6.0, 46.0)):
			Geo.box(self, Vector3(-60.0 + i * 6.0, -0.09, 46.0), Vector3(3.0, 0.01, 0.25), paint, false)
	Geo.box(self, Vector3(-14.0, -0.09, 98.0), Vector3(120.0, 0.01, 0.3), paint, false)
	# taxiway / runway lights
	var amber := Mats.get_mat("runway_light")
	var blue := Mats.get_mat("runway_blue")
	for i in 60:
		var x := -150.0 + i * 5.0
		Geo.box(self, Vector3(x, 0.0, -190.0), Vector3(0.25, 0.15, 0.25), amber, false)
		Geo.box(self, Vector3(x, 0.0, -230.0), Vector3(0.25, 0.15, 0.25), amber, false)
		Geo.box(self, Vector3(x, 0.0, 160.0), Vector3(0.25, 0.15, 0.25), amber, false)
		if i % 2 == 0:
			Geo.box(self, Vector3(x, 0.0, -170.0), Vector3(0.2, 0.12, 0.2), blue, false)
			Geo.box(self, Vector3(x, 0.0, 130.0), Vector3(0.2, 0.12, 0.2), blue, false)
	for i in 20:
		Geo.box(self, Vector3(60.0, 0.0, -20.0 - i * 8.0), Vector3(0.2, 0.12, 0.2), blue, false)
	# apron floodlight masts (east of the corridor, north at the gates, south in front of the lobby)
	for p in [Vector3(40, 0, -45), Vector3(40, 0, -70), Vector3(-30, 0, -130), Vector3(30, 0, -130),
			Vector3(-46, 0, 62), Vector3(26, 0, 92)]:
		Geo.cyl(self, p + Vector3(0, 12, 0), 0.25, 24, Mats.get_mat("steel_frame"))
		Geo.box(self, p + Vector3(0, 24, 0), Vector3(2.0, 0.6, 0.6), Mats.get_mat("lamp_white"), false)
		var sl := Geo.spot(self, p + Vector3(0, 23.5, 0), p + Vector3(-6, 0, 0), Color(1.0, 0.85, 0.6), 6.0, 60.0, 50.0)
		sl.spot_attenuation = 1.0
		sl.light_volumetric_fog_energy = 0.3
		outside_lights.append(sl)
	# control tower far out on the airfield, seen through the lobby glass
	var tower := Node3D.new()
	add_child(tower)
	tower.position = Vector3(48, 0, 260)
	Geo.cyl(tower, Vector3(0, 22, 0), 2.2, 44, Mats.get_mat("concrete"), false, 16)
	Geo.cyl(tower, Vector3(0, 46.5, 0), 5.2, 5.0, Mats.get_mat("glass"), false, 8)
	Geo.cyl(tower, Vector3(0, 49.5, 0), 5.8, 1.0, Mats.get_mat("steel_frame"), false, 8)
	Geo.cyl(tower, Vector3(0, 44.0, 0), 4.6, 0.6, Mats.get_mat("steel_frame"), false, 8)
	var cab := Geo.omni(tower, Vector3(0, 46.5, 0), Color(0.55, 0.85, 0.7), 1.5, 14.0)
	cab.light_volumetric_fog_energy = 0.6
	outside_lights.append(cab)
	Geo.box(tower, Vector3(0, 51.0, 0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_red"), false)
	warp.tower = tower
	# parked aircraft: one off the corridor windows, one on the apron south-west of the lounge (the crashed one is
	# built with the lounge, _wreck)
	warp.aircraft.append(Props.aircraft(self, Vector3(45, 0, -58), PI, false))
	warp.aircraft.append(Props.aircraft(self, Vector3(-40, 0, 112), PI / 2, false))
	# the impossible aircraft at Gate 0 (finale only)
	final_plane = Props.aircraft(self, Vector3(0, 0, -168), 0.0, true)
	final_plane.visible = false
	_skyline()


## The airliner that came down on the apron and slid into the lounge (the lounge reference, asked to break in): down on
## its belly, heading north-west and rolled onto its right wing, its nose through the glass and on the lounge floor,
## the right wing with its engine slicing in through the facade further east. Its hull collides (trimesh). A fill on
## the side facing the glass, aimed out over the apron (no light comes in from outside). `wreck` holds it.
func _wreck() -> void:
	wreck = Node3D.new()
	wreck.name = "Wreck"
	add_child(wreck)
	var plane := Props.aircraft(wreck, Vector3.ZERO, 0.0, false, WRECK_LEN, false)
	plane.name = "Airliner"
	var b := Basis(Vector3.UP, WRECK_YAW) * Basis(Vector3.BACK, WRECK_ROLL) * Basis(Vector3.RIGHT, WRECK_PITCH)
	plane.transform = Transform3D(b * Basis.from_scale(Vector3.ONE * WRECK_LEN / 61.0), WRECK_AT)
	# grimed and scorched: a darker, rougher copy of the apron atlas (the parked airliners keep theirs)
	var grime: StandardMaterial3D = null
	if TripoProps.exists("apron", "APR_Aircraft"):
		grime = TripoProps.atlas("apron").duplicate() as StandardMaterial3D
		grime.albedo_color = Color(0.74, 0.74, 0.76)
		grime.roughness_texture = null
		grime.roughness = 0.62
	for mi: MeshInstance3D in plane.find_children("*", "MeshInstance3D", true, false):
		if grime:
			mi.material_override = grime
		mi.create_trimesh_collision()
		for body in mi.get_children():
			if body is StaticBody3D:
				body.collision_layer = Geo.LAYER_WORLD
				body.collision_mask = 0
	var fill := Geo.spot(wreck, Vector3(30.0, 21.0, HALL_S + 1.5), Vector3(30.0, 2.0, 68.0), Color(0.6, 0.7, 0.92), 7.0, 40.0, 40.0)
	fill.light_volumetric_fog_energy = 0.2
	fill.light_specular = 0.3
	outside_lights.append(fill)


## A point of the airliner given in its own frame (Props.aircraft at 61 m: nose +Z, its right wing on -X), in the
## terminal's space.
func _wreck_point(p: Vector3) -> Vector3:
	return (wreck.get_node("Airliner") as Node3D).transform * p


## Every hull triangle of the airliner in the terminal's space, three points at a time.
func _wreck_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var inv := global_transform.affine_inverse()
	for mi: MeshInstance3D in wreck.find_children("*", "MeshInstance3D", true, false):
		var xf := inv * mi.global_transform
		for v in mi.mesh.get_faces():
			out.append(xf * v)
	return out


## How high the airliner broke the facade in each bay (bay k from x -19.4 + 3k): the highest point where its hull
## crosses the glass line in that bay, taken up past the next transom; the bays beside lose their lower panes too.
func _facade_breaks() -> Dictionary:
	var hits := {}
	var f := _wreck_faces()
	for t in range(0, f.size(), 3):
		for e in 3:
			var p := f[t + e]
			var q := f[t + (e + 1) % 3]
			if (p.z - HALL_S) * (q.z - HALL_S) > 0.0 or absf(p.z - q.z) < 1e-4:
				continue
			var c := p.lerp(q, (HALL_S - p.z) / (q.z - p.z))
			if c.y > 0.0:
				var k := int(floor((c.x + 19.4) / 3.0))
				hits[k] = maxf(hits.get(k, 0.0), c.y)
	var breaks := {}
	for k: int in hits:
		var top := HALL_ROOF
		for y: float in [3.3, 6.5, 9.7, 12.9, 16.1]:
			if y > hits[k] + 0.6:
				top = y
				break
		breaks[k] = top
	for k: int in breaks.keys():
		for nb: int in [k - 1, k + 1]:
			if not breaks.has(nb) and breaks[k] > 6.0:
				breaks[nb] = breaks[k] - 3.2
	return breaks


## The 1 m floor cells (Vector2i(x, z)) inside the lounge the airliner covers below `max_y`: no seat stands there.
func _wreck_cells(max_y: float) -> Dictionary:
	var cells := {}
	var f := _wreck_faces()
	for t in range(0, f.size(), 3):
		var a := f[t]
		var ab := f[t + 1] - a
		var ac := f[t + 2] - a
		var n := clampi(int(ceil(maxf(ab.length(), ac.length()) / 0.7)), 1, 40)
		for i in n + 1:
			for j in n + 1 - i:
				var p := a + ab * (float(i) / n) + ac * (float(j) / n)
				if p.y < max_y and p.z < HALL_S + 0.5:
					cells[Vector2i(floori(p.x), floori(p.z))] = true
	return cells


## What the airliner brought in with it: the glass of the smashed panes strewn into the lounge (some out on the
## apron), bent mullions, slab and floor-tile chunks round the nose and the engine, seat rows thrown over by the
## nose, tarmac and concrete heaved up outside along its belly, and dust hanging at the breach.
func _crash_debris(breaks: Dictionary) -> void:
	if breaks.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var shards: Array[Transform3D] = []
	var bent: Array[Transform3D] = []
	var bx0 := INF
	var bx1 := -INF
	for k: int in breaks:
		var x0 := -19.4 + k * 3.0
		bx0 = minf(bx0, x0)
		bx1 = maxf(bx1, x0 + 3.0)
		var top: float = breaks[k]
		for i in int(top * 10.0):
			var inside := rng.randf() < 0.8
			var d := absf(rng.randfn(0.0, 3.2 if inside else 2.0)) + 0.3
			var s := Vector3(rng.randf_range(0.06, 0.4), 0.008, rng.randf_range(0.04, 0.3))
			shards.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU,
					rng.randf_range(-0.12, 0.12))) * Basis.from_scale(s),
					Vector3(x0 + rng.randf() * 3.0, 0.006, HALL_S - d if inside else HALL_S + d)))
		if top >= 6.0:
			bent.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU,
					rng.randf_range(-0.15, 0.15))) * Basis.from_scale(Vector3(rng.randf_range(1.5, 3.2), 0.14, 0.22)),
					Vector3(x0 + rng.randf() * 3.0, 0.1, HALL_S - rng.randf_range(0.8, 4.0))))
	# chunks: [centre, spread, count, size range]
	var nose := _wreck_point(Vector3(0, 1.0, 29.5))
	var engine := _wreck_point(Vector3(-11.3, 0.7, 8.5))
	var belly: Array = []
	for t in range(-24, 12, 4):
		belly.append([_wreck_point(Vector3(0, 0, t)) * Vector3(1, 0, 1), 4.5, 10, Vector2(0.3, 1.8)])
	var piles: Array = [[nose * Vector3(1, 0, 1), 4.0, 90, Vector2(0.15, 1.1)],
		[_wreck_point(Vector3(0, 0, 22.0)) * Vector3(1, 0, 1), 5.0, 50, Vector2(0.15, 0.9)],
		[engine * Vector3(1, 0, 1), 3.5, 60, Vector2(0.15, 1.1)],
		[Vector3((bx0 + bx1) * 0.5, 0, HALL_S - 0.8), (bx1 - bx0) * 0.5, 90, Vector2(0.1, 0.7)]] + belly
	var concrete: Array[Transform3D] = []
	var tiles: Array[Transform3D] = []
	for pile: Array in piles:
		var c: Vector3 = pile[0]
		var sizes: Vector2 = pile[3]
		for i in int(pile[2]):
			var s := rng.randf_range(sizes.x, sizes.y)
			var size := Vector3(s * rng.randf_range(0.6, 1.6), s * rng.randf_range(0.2, 0.6), s * rng.randf_range(0.6, 1.4))
			var p := Vector3(c.x + rng.randfn(0.0, pile[1] * 0.5), size.y * 0.25, c.z + rng.randfn(0.0, pile[1] * 0.5))
			var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU,
					rng.randf_range(-0.5, 0.5))) * Basis.from_scale(size), p)
			if p.z < HALL_S and rng.randf() < 0.5:
				tiles.append(xf)          # the lounge's own floor, broken up
			else:
				concrete.append(xf)
	var cube := BoxMesh.new()
	_multi(cube, _shard_mat(), shards, Vector3.ZERO)
	_multi(cube, Mats.get_mat("steel_frame"), bent, Vector3.ZERO)
	_multi(cube, Mats.get_mat("concrete"), concrete, Vector3.ZERO)
	_multi(cube, Mats.std(Color(0.55, 0.54, 0.51), 0.2), tiles, Vector3.ZERO)
	# seat rows the nose pushed ahead of it and threw over
	var fwd := Basis(Vector3.UP, WRECK_YAW) * Vector3.BACK
	var right := Basis(Vector3.UP, WRECK_YAW) * Vector3.LEFT
	for t: Array in [[3.0, 4.2, 0.6, 1.45], [-1.0, -4.6, 2.1, -1.5], [5.5, -2.8, -0.5, 1.5]]:
		var at: Vector3 = nose * Vector3(1, 0, 1) + fwd * t[0] + right * t[1]
		if at.z < HALL_S - 1.0:
			var row := Props.seat_row(self, at + Vector3(0, 0.32, 0), 5, WRECK_YAW + t[2])
			row.rotate_object_local(Vector3.RIGHT, t[3])
	# dust hanging at the breach
	var fog := FogVolume.new()
	fog.size = Vector3(bx1 - bx0 + 8.0, 8.0, 16.0)
	var fm := FogMaterial.new()
	fm.density = 0.03
	fm.albedo = Color(0.72, 0.75, 0.82)
	fm.edge_fade = 0.6
	fog.material = fm
	add_child(fog)
	fog.position = Vector3((bx0 + bx1) * 0.5, 3.5, HALL_S - 5.0)


## A far shore of lights beyond the airfield (the city past the apron at night): lit windows in blocks.
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var warm: Array[Transform3D] = []
	var cool: Array[Transform3D] = []
	var x := -320.0
	while x < 320.0:
		var w := rng.randf_range(8.0, 30.0)
		var h := rng.randf_range(4.0, 40.0) if rng.randf() < 0.6 else rng.randf_range(1.0, 6.0)
		var zc := 240.0 + rng.randf_range(0.0, 40.0)
		for i in int(w * h / 16.0) + 2:
			var p := Vector3(x + rng.randf() * w, rng.randf() * h, zc + rng.randf_range(-3.0, 3.0))
			(warm if rng.randf() < 0.65 else cool).append(Transform3D(Basis.from_scale(Vector3(1.4, 0.9, 1.4)), p))
		x += w + rng.randf_range(2.0, 25.0)
	var cube := BoxMesh.new()
	_multi(cube, Mats.emissive(Color(1.0, 0.72, 0.42), 3.0), warm, Vector3.ZERO)
	_multi(cube, Mats.emissive(Color(0.7, 0.85, 1.0), 2.4), cool, Vector3.ZERO)
	# the city's glow on the low sky behind it (added over the night sky, fading out upward)
	var g := Gradient.new()
	g.set_color(0, Color(0.17, 0.23, 0.38))
	g.set_color(1, Color(0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = gt
	m.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2(900.0, 90.0)
	var glow := MeshInstance3D.new()
	glow.mesh = q
	glow.material_override = m
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow.position = Vector3(0, 30.0, 300.0)
	glow.rotation.y = PI          # facing the terminal (north)


# --------------------------------------------------------------------------------------------
func _build_facility_systems() -> void:
	# lighting panels
	lights_panel = LightPanel.new()
	lights_panel.id = "lights"
	lights_panel.title = "조명 분전반"
	lights_panel.short_name = "LP-1"
	lights_panel.zone = "hall"
	add_child(lights_panel)
	lights_panel.position = spot("look_lights")
	lights_panel.rotation.y = PI / 2
	lights_panel.build(zones, ["hall", "baggage", "security", "corridor", "gates"])
	facilities["lights"] = lights_panel
	lights_panel_gates = LightPanel.new()
	lights_panel_gates.id = "lights_gates"
	lights_panel_gates.title = "게이트 조명 스위치"
	lights_panel_gates.zone = "gates"
	add_child(lights_panel_gates)
	lights_panel_gates.position = Vector3(-11.5, 1.45, -76.22)
	lights_panel_gates.rotation.y = PI
	lights_panel_gates.build(zones, ["corridor", "gates"], "구역 조명  LIGHTING")
	for zn in lights_panel.switches.keys():
		lights_panel.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	for zn in lights_panel_gates.switches.keys():
		lights_panel_gates.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	# departures board on the 2F's north wall (face z -2.3), the RESET box on the wall to its left at hand height
	var fids := FidsBoard.new()
	fids.id = "fids"
	fids.title = "FIDS 출발 전광판"
	fids.short_name = "FIDS-01"
	fids.zone = "hall"
	add_child(fids)
	fids.position = Vector3(0.0, MEZZ_Y + 3.6, -2.07)
	fids.build(4.4, 2.05, true)
	fids.control_box.position = Vector3(-5.95, MEZZ_Y + 1.45, -2.23) - fids.position
	facilities["fids"] = fids
	# arrivals board hung from the ceiling over the 2F's edge west of the escalators, turned to the atrium: seen from
	# the lounge floor and from the 2F, and not in the way of the view from the staff doors
	arrivals = FidsBoard.new()
	arrivals.id = "fids_arr"
	arrivals.zone = "hall"
	add_child(arrivals)
	arrivals.position = Vector3(-3.0, 7.6, ATRIUM.position.y + 0.45)     # west of the escalators, out of the view from the staff doors
	arrivals.rotation.y = deg_to_rad(20.0)
	arrivals.build(4.4, 2.05, false)
	arrivals.screen.title = "도착  ARRIVALS"
	arrivals.screen.icon = load("res://assets/textures/level/icon_arrivals.png")
	var rod := roof_y(arrivals.position.z) - arrivals.position.y - 1.175
	for rx: float in [-1.6, 1.6]:
		Geo.cyl(arrivals, Vector3(rx, 1.175 + rod * 0.5, -0.12), 0.025, rod, Mats.get_mat("steel_frame"))
	# PA console on the broadcast desk
	var pa := PaConsole.new()
	pa.id = "pa"
	pa.title = "안내방송 콘솔"
	pa.short_name = "PA-01"
	pa.zone = "hall"
	add_child(pa)
	pa.transform = desk_xform() * Transform3D(Basis(), Vector3(0.2, 1.0, 5.85))
	pa.build()
	facilities["pa"] = pa
	# baggage
	var belt := BaggageBelt.new()
	belt.id = "baggage"
	belt.title = "수하물 수취대 B-03"
	belt.short_name = "B-03"
	belt.zone = "baggage"
	add_child(belt)
	belt.position = BELT_POS
	belt.build()
	facilities["baggage"] = belt
	var bp := Props.pedestal(self, Vector3(-33.6, 0, -57.4), -PI / 2, "B-03 제어")
	Props.button(bp, Vector3(-0.18, -0.03, 0), 0.0, "button_green", "가동", "벨트 가동", belt.press_start)
	Props.button(bp, Vector3(0.0, -0.03, 0), 0.0, "button_white", "정지", "벨트 정지", belt.press_stop)
	Props.button(bp, Vector3(0.18, -0.03, 0), 0.0, "button_red", "비상정지", "벨트 비상정지", belt.press_estop, 0.06)
	# moving walkway
	var mw := MovingWalkway.new()
	mw.id = "walkway"
	mw.title = "무빙워크 MW-1"
	mw.short_name = "MW-1"
	mw.zone = "corridor"
	add_child(mw)
	mw.position = Vector3(3.4, 0, -31.3)
	mw.build(40.0)
	facilities["walkway"] = mw
	var wp := Props.pedestal(self, Vector3(1.2, 0, -29.6), 0.0, "MW-1 제어")
	Props.button(wp, Vector3(-0.18, -0.03, 0), 0.0, "button_green", "가동", "무빙워크 가동", mw.press_start)
	Props.button(wp, Vector3(0.0, -0.03, 0), 0.0, "button_white", "정지", "무빙워크 정지", mw.press_stop)
	Props.button(wp, Vector3(0.18, -0.03, 0), 0.0, "button_red", "비상정지", "무빙워크 비상정지", mw.press_estop, 0.06)
	# X-ray lanes
	var xr := XrayMachine.new()
	xr.id = "xray"
	xr.title = "보안검색 X-ray 1번"
	xr.short_name = "X-1"
	xr.zone = "security"
	add_child(xr)
	xr.position = Vector3(LANE_X[0], 0, LANE_Z)
	xr.build()
	facilities["xray"] = xr
	var xr2 := XrayMachine.new()
	xr2.id = "xray2"
	xr2.zone = "security"
	add_child(xr2)
	xr2.position = Vector3(LANE_X[1], 0, LANE_Z)
	xr2.build()
	# boarding gates
	var gate_defs := [["01", Vector3(-26, 0, -82), PI / 2], ["02", Vector3(-26, 0, -94), PI / 2],
		["03", Vector3(26, 0, -82), -PI / 2], ["04", Vector3(26, 0, -94), -PI / 2]]
	for g in gate_defs:
		var gate := BoardingGate.new()
		gate.id = "gate" + g[0]
		gate.title = tr("탑승구 GATE ") + g[0]
		gate.short_name = "GATE " + g[0]
		gate.zone = "gates"
		add_child(gate)
		gate.position = g[1]
		gate.rotation.y = g[2]
		gate.build(g[0])
		facilities[gate.id] = gate
		gates[g[0]] = gate
		var gp: Vector3 = g[1] + Basis(Vector3.UP, g[2]) * Vector3(0, 0, 3.5)
		zones.gates.add_panel(Vector3(gp.x, 5.42, gp.z), Vector2(1.2, 1.2), true, 1.6, 10.0, Color(1.0, 0.93, 0.8))
	# breaker panel in the office
	breaker = BreakerPanel.new()
	add_child(breaker)
	breaker.position = Vector3(-13.3, 1.5, -2.28)
	breaker.build([
		["fids", "FIDS", [fids]],
		["pa", "PA", [pa]],
		["baggage", "B-03", [belt]],
		["walkway", "MW-1", [mw]],
		["xray", "X-RAY", [xr]],
		["gates", "GATES", [gates["01"], gates["02"], gates["03"], gates["04"]]],
	])
	# emergency lighting (only after main power is cut)
	emergency_light_root = Node3D.new()
	add_child(emergency_light_root)
	emergency_light_root.visible = false
	for p in [Vector3(-17, 2.4, HALL_S - 1.5), Vector3(-2, 3, 6), Vector3(26, 3, 9), Vector3(10, 3, 30), Vector3(-24, 3, -50), Vector3(-42, 2.5, -50)]:
		var el := Geo.omni(emergency_light_root, p, Color(0.2, 1.0, 0.35), 0.6, 9.0)
		el.light_volumetric_fog_energy = 1.5


func _build_gate0() -> void:
	gate0_parts = Node3D.new()
	add_child(gate0_parts)
	var g0 := BoardingGate.new()
	g0.id = "gate0"
	g0.title = "GATE 0"
	g0.short_name = "GATE 0"
	g0.zone = "gates"
	gate0_parts.add_child(g0)
	g0.position = Vector3(0, 0, -100)
	g0.build("0", false, false)
	gates["0"] = g0
	facilities["gate0"] = g0
	# long jet bridge to the impossible aircraft
	var br := Node3D.new()
	gate0_parts.add_child(br)
	var carpet := Mats.get_mat("carpet_red")
	var wallm := Mats.get_mat("wall_service")
	Geo.box(br, Vector3(0, -0.05, -120), Vector3(2.6, 0.1, 32), carpet, true)
	Geo.box(br, Vector3(0, 2.75, -120), Vector3(2.6, 0.1, 32), Mats.get_mat("ceiling_dark"), false)
	for sx in [-1.35, 1.35]:
		Geo.box(br, Vector3(sx, 1.35, -120), Vector3(0.1, 2.7, 32), wallm, true)
	for i in 6:
		var l := Geo.omni(br, Vector3(0, 2.4, -106 - i * 5.0), Color(1.0, 0.85, 0.6), 0.5, 4.5)
		l.light_volumetric_fog_energy = 1.5
		Geo.box(br, Vector3(0, 2.69, -106 - i * 5.0), Vector3(0.8, 0.02, 0.3), Mats.get_mat("lamp_white"), false)
	# aircraft door at the end of the bridge
	var door := Node3D.new()
	br.add_child(door)
	door.position = Vector3(0, 0, -135.6)
	Geo.box(door, Vector3(0, 1.35, -0.1), Vector3(2.6, 2.7, 0.2), Mats.get_mat("plane_body"), true)
	Geo.box(door, Vector3(0, 1.05, 0.01), Vector3(0.9, 1.9, 0.04), Mats.get_mat("plane_dark"), false)
	Geo.label(door, "HOME", Vector3(0, 2.2, 0.04), 0.0, 40, Color(0.9, 0.9, 0.9), 0.005, false, "print")
	Geo.blocker(br, Vector3(0, 1.35, -136), Vector3(2.6, 2.7, 0.4))
	triggers["board_door"] = Geo.area(br, Vector3(0, 1.0, -134.5), Vector3(2.4, 2.0, 1.6))
	Props.exit_sign(gate0_parts, Vector3(0, 4.3, -99.6), 0.0, "GATE 0  탑승")
	Geo.fit_labels(gate0_parts)


func _sync_switch(zone_name: String, on: bool) -> void:
	for panel in [lights_panel, lights_panel_gates]:
		if panel.switches.has(zone_name):
			panel.switches[zone_name].set_on(on)


func set_zone_light(zone_name: String, on: bool, instant := false) -> void:
	if zones.has(zone_name):
		zones[zone_name].set_on(on, instant)
	_sync_switch(zone_name, on)


func reveal_gate0() -> void:
	if gate0_parts != null:
		return
	_build_gate0()
	gate0_wall.visible = false
	for c in gate0_wall.get_children():
		if c is MeshInstance3D:
			for b in c.get_children():
				if b is StaticBody3D:
					b.collision_layer = 0
	gate0_parts.visible = true
	final_plane.visible = true


# --------------------------------------------------------------------------------------------
## Box-projected interior reflection probes so brushed steel (carousels, X-ray tunnels, stanchions, rails) and
## the glossy floors reflect the halls instead of nothing. Captured once with every zone lit; each probe then
## fades with its zone's lights so a dark hall does not keep shining.
func _build_probes() -> void:
	var defs := {
		"hall": [Vector3(12, HALL_ROOF * 0.5, (HALL_S - 2.5) * 0.5), Vector3(64, HALL_ROOF, HALL_S + 2.5)],
		"security": [Vector3(0, SEC_H * 0.5, -17.9), Vector3(20, SEC_H, 18.8)],
		"corridor": [Vector3(0, 2.25, -51.6), Vector3(20, 4.5, 48.7)],
		"baggage": [Vector3(-23, 1.8, -51.8), Vector3(26, 3.6, 24.4)],
		"gates": [Vector3(0, 2.75, -88), Vector3(52, 5.5, 24)],
		"airhall": [Vector3(AirHall.RECT.get_center().x, (AirHall.PIT_Y + AirHall.ROOF_W) * 0.5, AirHall.RECT.get_center().y),
				Vector3(AirHall.RECT.size.x, AirHall.ROOF_W - AirHall.PIT_Y, AirHall.RECT.size.y)],
	}
	for zn in defs:
		var probe := ReflectionProbe.new()
		probe.size = defs[zn][1]
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.max_distance = 60.0
		probe.position = defs[zn][0]
		probe.intensity = 0.0
		_probes[zn] = probe
	# capture once the zones' lights have come up
	get_tree().create_timer(0.8).timeout.connect(func():
		for zn in _probes:
			add_child(_probes[zn]))


func _process(delta: float) -> void:
	if air_haze:
		var hz: LightZone = zones.airhall
		air_haze.emission = AirHall.HAZE_GLOW * (hz.panel_mat.emission_energy_multiplier / hz.panel_energy)
	for zn in _probes:
		var z: LightZone = zones[zn]
		var want := 0.7 if z.is_on and z.powered else 0.0
		var p: ReflectionProbe = _probes[zn]
		if p.is_inside_tree():
			p.intensity = move_toward(p.intensity, want, delta * 2.0)


## Reverb zones: every 3D sound (doors, machines, the colleague's voice) sends into the hall or room reverb of
## the zone it is played in, so the big halls ring and the small rooms stay dry. Rooms inside a hall win (priority).
func _build_reverb() -> void:
	var defs := {
		"hall": ["RevHall", 0.32, HALL_H], "security": ["RevMid", 0.28, SEC_H], "corridor": ["RevLong", 0.32, COR_H],
		"baggage": ["RevMid", 0.28, BAG_H], "gates": ["RevLong", 0.3, 5.5],
		"office": ["RevRoom", 0.22, 3.2], "storage": ["RevRoom", 0.24, 3.2], "maint": ["RevRoom", 0.26, 3.0],
		"bridge0": ["RevTight", 0.3, 2.8],
	}
	for zn in defs:
		var d: Array = defs[zn]
		for r: Rect2 in zone_rects(zn):
			_reverb_box(zn, d[0], d[1], AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, d[2], r.size.y)))
	# the 2F's shops are small rooms off the lounge
	for r: Rect2 in Shops.rects():
		_reverb_box("shop", "RevRoom", 0.24, AABB(Vector3(r.position.x, MEZZ_Y, r.position.y), Vector3(r.size.x, Shops.H, r.size.y)))
	# the aircraft hall (down to its floor, far below), the cabin that leads there and its section on the landing
	# (tight, they win)
	var ar := AirHall.RECT
	_reverb_box("airhall", "RevHall", 0.34, AABB(Vector3(ar.position.x, AirHall.PIT_Y, ar.position.y),
			Vector3(ar.size.x, AirHall.ROOF_W - AirHall.PIT_Y, ar.size.y)))
	for r: Rect2 in [CabinWay.cabin_rect(), CabinWay.stub_rect()]:
		_reverb_box("cabin", "RevTight", 0.3, AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, Airliner.CEIL_H, r.size.y)))


func _reverb_box(zn: String, bus: String, amount: float, box: AABB) -> void:
	var a := Area3D.new()
	a.name = "Reverb_" + zn
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = bus
	a.reverb_bus_amount = amount
	a.reverb_bus_uniformity = 0.4
	a.priority = 1 if bus in ["RevRoom", "RevTight"] else 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	a.add_child(cs)
	add_child(a)
	a.position = box.get_center()


# --------------------------------------------------------------------------------------------
func _define_spawns() -> void:
	spawns["office"] = Transform3D(Basis(Vector3.UP, PI), Vector3(-15.8, 0.05, 2.2))
	spawns["corridor_south"] = Transform3D(Basis(), Vector3(-1.5, 0.05, -29.0))
	spawns["corridor_mid"] = Transform3D(Basis(), Vector3(-1.5, 0.05, -50.0))
	spawns["gates_entry"] = Transform3D(Basis(), Vector3(0, 0.05, -78.5))
	spawns["hall"] = Transform3D(Basis(Vector3.UP, PI), Vector3(0.2, 0.05, 7.6))
	spawns["hall_entrance"] = Transform3D(Basis(), Vector3(-7.8, 0.05, HALL_S - 2.0))
	spawns["baggage"] = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-14.0, 0.05, -44.0))
	triggers["entrance_out"] = Geo.area(self, Vector3(-7.8, 1.0, HALL_S + 2.2), Vector3(4.0, 2.0, 1.6))
	triggers["emergency_out"] = Geo.area(self, Vector3(-17, 1.0, HALL_S + 2.0), Vector3(1.6, 2.0, 1.6))


func zone_at(p: Vector3) -> String:
	# up on the lounge's 2F it is the lounge, whatever room is under you, and so are its shops
	if p.y > MEZZ_Y - 0.6 and p.y < HALL_H:
		if Rect2(-20, -2.5, HALL_E + 20, HALL_S + 2.5).has_point(Vector2(p.x, p.z)):
			return "hall"
		for r: Rect2 in Shops.rects():
			if r.has_point(Vector2(p.x, p.z)):
				return "hall"
	for zn in ZONE_RECTS.keys():
		for r: Rect2 in zone_rects(zn):
			if r.has_point(Vector2(p.x, p.z)):
				return zn
	return "outside"


func facility(id_text: String) -> Facility:
	return facilities.get(id_text)
