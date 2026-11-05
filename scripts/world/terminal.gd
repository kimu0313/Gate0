class_name Terminal
extends Node3D
## Procedurally builds the SEOHAE International Airport terminal and exposes its systems.
##
## Layout from the level plan (Downloads/image (9).png, 2 m grid, drawn with the airside at the bottom); the hall
## is the main lounge of the lounge reference (SKETCH_SHOTS ref_lounge). Metres, Y up, -Z = north/airside, +X = east:
##   HALL (main lounge) x[-20,17] z[-2.5,29.5] (a third of its first floor area, user: "라운지만 3분의 1 규모로";
##                12 m over its north part; over the glass side, z 9.5..29.5, no roof: the walls (over the glass facade
##                on the apron to the south too) go on up into the dark with nothing between them, LoungeShaft; four
##                rows of columns with ad screens, an airliner's nose through the glass) + its north strip
##                x[-12.2,12] z[-8.5,-2.5]
##   2F       the lounge's upper floor (MEZZ_Y): a gallery of one width on three sides round its atrium (UPPER), the
##            staff doors in its north wall, a pair of escalators from its edge down into the atrium; the shops
##            behind its three walls (Shops: eight empty units of different sizes, the biggest facing the escalators)
##   OFFICE   x[-20,-12.2] z[-2.5,7.6]    STORAGE x[12,22] z[-8.5,-2.5]
##   SECURITY OFFICE (보안실) an L: x[-22.4,-12.4] z[-26,-15] + x[-30.4,-12.4] z[-34,-26], its door on the staff
##            passage's west wall at z -16
##   SECURITY x[-10,10] z[-27.3,-8.5]     CORRIDOR x[-10,10] z[-76,-27.3] (walkways on its east side)
##   BAGGAGE  x[-36,-10] z[-64,-39.6] + staff passage x[-12.4,-10] z[-39.6,-8.5] from the strip (open from DAY 2,
##            before security; the public opening from the corridor opens with the corridor)
##   MAINT    x[-48,-36] z[-53,-47]       GATES x[-26,26] z[-100,-76]       GATE 0 bridge x[-1.3,1.3] z[-128,-100]
##   AIRCRAFT HALL x[-74,-26] z[-24,62] (AirHall: a floor below the lounge, an airliner parked in it, decks along
##            its east side) — the way in is CABIN WAY (CabinWay) x[-23.7,-20.3] z[25.9,51.5] behind the lounge's 1F west
##            wall, its door at z 27.5; through its haze you come out of a cabin section on the hall's deck at z -24..-20

const HALL_H := 12.0         # main lounge: flat ceiling over its north half (over the 2F)
const HALL_ROOF := 21.0      # the glass facade's own frame up to here; LoungeShaft's wall on up
## The lounge was 64 x 54.5 m (x -20..44, z -2.5..52); the user had it cut to a third of that floor area, its height
## kept ("라운지만 3분의 1 규모로", "높이는 그대로"): 37 x 32 m. (It was narrowed once more, to 28 m, and the user had
## that undone: "조금 더 줄여달라고 했던 가로도 원래로 되돌려줘".) Its north wall (the strip, security, the office, the
## staff doors) and its west wall (the cabin's door, the aircraft hall) stay where they were; the east wall and the
## glass came in.
const HALL_E := 17.0         # the lounge's east end wall
const HALL_S := 29.5         # glass facade on the apron (south)
const ROOF_Z := 9.5          # where the flat ceiling stops and the endless shaft over the glass side begins (LoungeShaft)
## The lounge's columns (1.3 m square): two lines (x) on three rows (z) — the row at z 1 under the 2F, the rows at 6 and
## 9.5 standing in the atrium a few metres in from its sides, clear of the escalators and of the view from the staff
## doors. Nothing stands over the glass side (user: "가운데 기둥 4개 다 빼줘" — the row that rose into the dark there is
## gone).
const COL_X := [-11.0, 8.5]
const COL_Z := [1.0, 6.0, 9.5]
const AISLES := [3.8, 13.0]  # the two aisles along the hall (z): under the 2F's edge, and the one from the cabin's door
const MEZZ_Y := 4.2          # the lounge's 2F floor
const SLAB := 0.35           # its thickness (the lounge's ceiling under it at MEZZ_Y - SLAB)
## The 2F over the lounge, an empty floor for what comes later: plates [x0, z0, x1, z1] round the ATRIUM (open from
## the lounge floor to the ceiling over the middle, and on up into the dark over the glass side, where the airliner
## lies: LoungeShaft). The 2F wraps the lounge
## like a ㄷ, a gallery 5 m wide from the walls on all three sides: the north side the length of the hall, the east
## and west sides down to the glass. No column stands on the 2F.
const UPPER := [[-19.9, -2.4, 16.9, 2.5], [-19.9, 2.5, -15.0, 29.35], [12.0, 2.5, 16.9, 29.35]]
const ATRIUM := Rect2(-15.0, 2.5, 27.0, 26.85)
## A pair of escalators (an up and a down side by side, ESC_GAP apart) from the 2F's edge down into the atrium,
## toward the airliner (south): the pairs' centres and the lower working points' z. The down one of each pair is the
## one nearer the staff doors.
const ESC_X := [-7.0]
const ESC_FOOT_Z := 10.8
const ESC_GAP := 1.66
## The terminal's light at night (the abandoned-hall reference): a cold, slightly cyan white. Every zone's panels and
## the lights that take the zone's colour (LightZone) are this; screens and signs keep their own. FILL_LIGHT is the
## colour of the dim omnis that stand in for bounce light: the teal the haze turns everything.
const ZONE_LIGHT := Color(0.84, 0.95, 1.0)
const FILL_LIGHT := Color(0.62, 0.86, 0.92)
## The security office's fluorescent fittings: a plain warm white (the concept art's), against the terminal's cold night.
const SEC_LIGHT := Color(1.0, 0.85, 0.62)        # the office's tubes: warm (the dark old-office reference)
const SEC_SHADE := Color(0.5, 0.72, 0.7)         # the faint teal fill between their pools
const DESK_AT := Vector3(-10.5, 0, 3.5)    # the broadcast desk's middle, at the far (west) end of the north aisle
const DECK_DOOR := Vector3(-2.0, 4.2, -2.5)   # the staff double doors in the 2F's north wall (MEZZ_Y), facing the
                                              # atrium; the service corridor comes out here in the main story
## The lift and the stair lobby's door in the lounge's 1F east wall (z): the way down from the corridors round the
## security office, which are on the 4th floor (_build_vertical; user: "보안실은 4층이고 공항 라운지는 1층").
const LIFT_Z := 4.0
const STAIR_Z := 7.0
## The airliner that came down on the apron and slid into the lounge (Props.aircraft frame: nose +Z): its length, the
## frame's origin, heading (a little west of north, 20° off square to the glass) and roll onto its right wing: its nose
## has broken through the facade and lies 9 m into the lounge; the wing with its engine lies out on the apron by the
## glass (since the lounge was cut down there is no room for the wing to come in with it).
const WRECK_LEN := 50.0
const WRECK_AT := Vector3(5.1, -1.9, 43.3)
const WRECK_YAW := -2.8
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
## The security office (보안실, _build_security_office): an L (ㄱ) — its south arm along the staff passage (x -22.4..-12.4,
## z -26..-15, both doors in it, you start at its south end) and its north arm turning west at the far end (x
## -27.5..-12.4, z -31.8..-26), the CCTV room (SEC_CCTV) in the elbow's far corner (the rest of that corner block is
## outside the building: sec_floor_rects); a plaster ceiling SEC_CEIL
## up on steel beams over pilasters (SEC_BEAMS_Z across the south arm, SEC_BEAMS_X across the north one).
const SEC_LEG := Rect2(-22.4, -26.0, 10.0, 11.0)
const SEC_BAR := Rect2(-27.5, -31.8, 15.1, 5.8)       # (was x -30.4.., z -34..-26: cut down, user 2026-11-05)
const SEC_CCTV := Rect2(-17.2, -28.5, 3.4, 5.9)      # a third of the corner block it once filled; the rest is outside the building
const SEC_DESK_W := 1.5            # every desk in the office the same (user: "책상마다 크기 간격 다 같게")
## A computer on every island desk (user: "모든 책상에 컴퓨터 다 놔줘"), set forward of the desk's middle so its tube
## clears the screen between the facing desks and its keyboard the desk's front edge (old_pc runs 0.33 back, 0.35 forward),
## to one side (L / R) so the partitions at the desk's ends clear it too.
const _ISLAND_PC_L := ["pc", -0.4, 0.04]
const _ISLAND_PC_R := ["pc", 0.4, 0.04]
const SEC_CEIL := 3.6               # floor to ceiling (was 4.5; user: "층고만 낮춰줘" — the windows and the ceiling's fittings as they were)
const SEC_BEAMS_Z := [-17.6, -21.8, -25.7]
const SEC_BEAMS_X := [-22.4, -26.4]
const SEC_ENTRY_Z := -16.25      # the west door (sec_entry: the key card door) in the south arm's west wall
const SEC_DORM_X := -21.35       # the night-duty room's door in its south wall
## The floor point at the far end of the dark vestibule outside the security office's west door, the way in: the
## main story's boarding-bridge gate door lands here (Chapter1's portal; +X = on into the office).
const SEC_ENTRY_PLANE := Vector3(-24.4, 0, SEC_ENTRY_Z)
## The render layer the security office stands on (office_layers): its lights light only this layer.
const VIS_OFFICE := 1 << 17
## The office's big windows (user: "이쪽 벽에 큰 창문들 달아줘"): two in the south arm's west wall (centres z), one in
## the north arm's south wall (centres x), all SEC_VIEW_SIZE with their middle at SEC_VIEW_Y — real holes in the
## walls. What they look out on is the service corridor's maze round the office (ServiceHall, far below: sec_view),
## and from the maze you look in through them (sec_inview). (Behind those walls here stands the aircraft hall.)
const SEC_VIEW_W := [-19.7, -23.75]
const SEC_VIEW_N := [-24.4]       # (a second at -28.45 went with the north arm's west end)
const SEC_VIEW_SIZE := Vector2(3.2, 2.0)
const SEC_VIEW_Y := 2.05

## Zone footprints (one Rect2 or an Array of them). Checked in this order by zone_at, so rooms inside the hall's
## rect (the office) come first.
const ZONE_RECTS := {
	"office": Rect2(-20, -2.5, 7.8, 10.1),
	"secoffice": [SEC_LEG, SEC_BAR],
	"hall": [Rect2(-20, -2.5, 37, 32), Rect2(-12.2, -8.5, 24.2, 6)],
	"storage": Rect2(12, -8.5, 10, 6),
	"security": Rect2(-10, -27.3, 20, 18.8),
	"corridor": Rect2(-10, -76, 20, 48.7),
	"baggage": [Rect2(-36, -64, 26, 24.4), Rect2(-12.4, -39.6, 2.4, 31.1)],
	"maint": Rect2(-48, -53, 12, 6),
	"gates": Rect2(-26, -100, 52, 24),
	"bridge0": Rect2(-1.5, -130, 3, 30),
	# the aircraft hall west of the lounge (AirHall.RECT) and the cabin that is the way in: behind the lounge's west wall
	# (CabinWay.cabin_rect, out to the wall's middle) and its section on the hall's landing (CabinWay.stub_rect)
	"cabin": [Rect2(-23.75, 11.4, 3.75, 17.6), Rect2(-31.45, -24.0, 3.5, 4.0)],
	"airhall": Rect2(-74, -24, 48, 86),
}
const ZONE_NAMES := {
	"office": "시설관리실", "hall": "메인 라운지", "baggage": "수하물 수취", "storage": "자재창고",
	"servicehall": "관리동 복도",
	"maint": "정비 통로", "security": "보안검색", "corridor": "탑승동 통로", "gates": "탑승 게이트",
	"bridge0": "0번 탑승교", "outside": "외부", "jetbridge": "위치 불명", "warped": "위치 불명", "secoffice": "보안실",
	"airhall": "항공기 전시홀", "cabin": "기내", "lift": "엘리베이터", "stairs": "비상계단",
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
	"view_pa": Vector3(-11.45, 0.05, 3.5), "look_pa": Vector3(-10.3, 1.0, 3.5),
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
	"entrance_out": Vector3(-7.8, 0, 32.3),
	"cut_arrivals": Vector3(12.0, 0.05, 5.0),
	"boarding_hold": Vector3(-1.5, 0.05, -62.0), "boarding_look": Vector3(-1.5, 1.6, -40.0),
	"exit_inside": Vector3(-17.0, 0.05, 27.0), "exit_look": Vector3(-17.0, 1.5, 29.5),
	"exit_outside": Vector3(-17.0, 0.05, 31.5), "exit_out_look": Vector3(-17.0, 1.5, 35.5),
	"lounge_start": Vector3(15.8, 0.05, 13.0),    # `--lounge`: the east end of the south aisle, looking west
	# the night-duty room (_build_dorm): before its door in the office, and just inside it (the shift colleague's way out)
	"dorm_front": Vector3(-21.35, 0.05, -15.7), "dorm_in": Vector3(-21.3, 0.05, -14.35),
	"airhall_start": Vector3(-29.35, 0.05, -18.5), # `--airhall`: the aircraft hall's deck by its escalator's foot
	"cabinway_front": Vector3(-16.5, 0.05, 13.0), # `--cabinway`: the lounge's south aisle before the cabin's door
}
## Views matching the sketches: [name, eye, yaw (deg, 0 = -Z), vanishing point (fraction of the image), vertical fov]
## (debug/level_shots.gd, `-- --level-shots <dir>` on the game scene; render at the sketch's aspect). ref_lounge is
## the main lounge reference (dark hall seen from its east end down the aisle; render 1536x1024).
const SKETCH_SHOTS := [
	["ref_lounge", Vector3(16.2, 1.65, 14.5), 90.0, Vector2(0.495, 0.59), 77.0],
	["lounge_north", Vector3(16.2, 1.65, 4.2), 90.0, Vector2(0.495, 0.59), 77.0],
	["lounge_crash", Vector3(12.0, 1.65, 13.0), 117.0, Vector2(0.5, 0.56), 74.0],
	["lounge_nose", Vector3(-6.0, 1.65, 14.0), 205.0, Vector2(0.5, 0.55), 72.0],
	["lounge_west", Vector3(-14.0, 1.65, 13.0), -90.0, Vector2(0.5, 0.55), 72.0],
	# looking up from the lounge floor (a 6th value = pitch, deg): toward the glass, straight up, up the glass
	["lounge_up", Vector3(-4.0, 1.65, 18.0), 180.0, Vector2(0.5, 0.5), 75.0, 55.0],
	["lounge_zenith", Vector3(-10.0, 1.65, 20.0), 180.0, Vector2(0.5, 0.5), 75.0, 86.0],
	["lounge_glass_up", Vector3(-8.0, 1.65, 25.0), 160.0, Vector2(0.5, 0.5), 75.0, 40.0],
	["lounge_up_aisle", Vector3(14.0, 1.65, 13.0), 120.0, Vector2(0.5, 0.5), 75.0, 35.0],
	["lounge_up_mid", Vector3(-3.0, 1.65, 12.0), 180.0, Vector2(0.5, 0.5), 75.0, 62.0],     # the user's look up over the middle
	["lounge_up_2f", Vector3(-17.5, 5.85, 22.0), 120.0, Vector2(0.5, 0.5), 75.0, 50.0],
	# the service corridors round the office (ServiceHall: its own coordinates = these less ServiceHall.ORIGIN (-160, -320, 0))
	["maze_e", Vector3(-171.4, -318.4, -16.6), 180.0, Vector2(0.5, 0.52), 72.0],      # out of the passage door, down E
	["maze_s", Vector3(-172.0, -318.4, -11.75), 90.0, Vector2(0.5, 0.52), 72.0],     # round the first corner, west along S
	["maze_w", Vector3(-183.65, -318.4, -11.2), 0.0, Vector2(0.5, 0.52), 72.0],      # north up W, the office's windows right
	["maze_w_win", Vector3(-184.3, -318.4, -17.6), -40.0, Vector2(0.5, 0.52), 72.0], # looking in at the office
	["maze_n", Vector3(-183.4, -318.4, -24.9), 90.0, Vector2(0.5, 0.52), 72.0],      # west along N
	["maze_v", Vector3(-196.1, -318.4, -24.75), 180.0, Vector2(0.5, 0.52), 66.0],    # the last run to the far doors
	["maze_b", Vector3(-183.9, -318.4, -19.4), 90.0, Vector2(0.5, 0.52), 72.0],      # down B, the branch west off W
	# the way down (Lift, StairCore): the lift at the run's end, the stairs' door at its north end, the stairwell (4F
	# landing, a half landing, the 1F door), the stair lobby, the lounge's side, inside the car
	["maze_door", Vector3(-171.6, -318.45, -16.0), -90.0, Vector2(0.5, 0.52), 64.0],      # a corridor door close up (E's 회의실)
	["archive_door", Vector3(-171.15, -318.4, -16.5), 0.0, Vector2(0.5, 0.52), 66.0],      # E's end: the records room's door
	["archive_in", Vector3(-171.235, -318.4, -21.95), 0.0, Vector2(0.5, 0.52), 70.0],     # in by its door, up the first aisle (the photo)
	["archive_aisle", Vector3(-169.225, -318.4, -22.7), 4.0, Vector2(0.5, 0.52), 70.0],   # the second aisle
	["archive_cross", Vector3(-171.6, -318.4, -22.4), -90.0, Vector2(0.5, 0.52), 74.0],   # across the row ends by the door
	["archive_back", Vector3(-165.1, -318.4, -32.4), 165.0, Vector2(0.5, 0.52), 74.0],    # from the far corner, back toward the door
	["maze_lift", Vector3(-196.1, -318.4, -10.5), 180.0, Vector2(0.5, 0.52), 66.0],
	["maze_stairs", Vector3(-183.65, -318.4, -15.0), 180.0, Vector2(0.5, 0.52), 70.0],         # up the last run onto the open stair hall
	["stair_landing", Vector3(-183.65, -318.4, -10.05), 185.0, Vector2(0.5, 0.5), 74.0, -14.0],   # on the 4F landing: the flight down, the parapet
	["stair_4f", Vector3(-187.8, -318.4, -9.95), -160.0, Vector2(0.5, 0.5), 74.0, -38.0],
	["stair_mid", Vector3(-185.3, -320.5, -3.97), 0.0, Vector2(0.5, 0.5), 74.0, -18.0],
	["stair_1f", Vector3(-186.3, -331.0, -8.95), 0.0, Vector2(0.5, 0.5), 74.0, -5.0],
	["stair_up", Vector3(-183.6, -331.0, -9.85), 180.0, Vector2(0.5, 0.5), 74.0, 32.0],
	["lobby_in", Vector3(17.6, 1.6, 7.0), -90.0, Vector2(0.5, 0.52), 74.0],
	["lounge_lift", Vector3(11.5, 1.6, 5.5), -90.0, Vector2(0.5, 0.52), 70.0],
	["lift_in", Vector3(18.6, 1.6, 4.0), 90.0, Vector2(0.5, 0.52), 76.0],
	["dorm_door", Vector3(-21.35, 1.6, -17.6), 180.0, Vector2(0.5, 0.52), 70.0],
	["dorm_in", Vector3(-21.75, 1.5, -14.45), -105.0, Vector2(0.5, 0.52), 78.0],
	["deck_arrive", Vector3(-2.0, 5.85, -0.9), 180.0, Vector2(0.5, 0.66), 74.0],
	["upper_back", Vector3(-7.0, 5.85, 2.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["upper_ring", Vector3(15.0, 5.85, 28.0), 25.0, Vector2(0.5, 0.55), 74.0],
	["escalators_1f", Vector3(-7.0, 1.65, 18.0), 0.0, Vector2(0.5, 0.55), 72.0],
	["upper_north", Vector3(16.0, 5.85, 0.0), 90.0, Vector2(0.5, 0.55), 74.0],
	["upper_west", Vector3(-17.5, 5.85, 27.5), 0.0, Vector2(0.5, 0.55), 74.0],
	["atrium_from_2f", Vector3(-16.0, 5.85, 14.0), -110.0, Vector2(0.5, 0.62), 74.0],
	["escalator_down", Vector3(-6.17, 5.85, 1.6), 180.0, Vector2(0.5, 0.62), 72.0],
	# the 2F's empty shop units (Shops): down the west and east galleries, then each unit from its opening (n2, the big
	# one, from the escalators' tops and inside)
	["shops_west", Vector3(-16.5, 5.85, 27.5), 0.0, Vector2(0.5, 0.55), 74.0],
	["shops_east", Vector3(14.5, 5.85, 27.5), 0.0, Vector2(0.5, 0.55), 74.0],
	["unit_n1", Vector3(-17.5, 5.85, 2.0), 0.0, Vector2(0.5, 0.55), 72.0],
	["unit_n2", Vector3(-7.0, 5.85, 2.2), 0.0, Vector2(0.5, 0.58), 74.0],
	["unit_n2_in", Vector3(-7.0, 5.85, -3.5), 0.0, Vector2(0.5, 0.56), 74.0],
	["unit_n3", Vector3(5.0, 5.85, 2.0), 0.0, Vector2(0.5, 0.55), 74.0],
	["unit_w1", Vector3(-15.8, 5.85, 3.1), 90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e1", Vector3(13.0, 5.85, 5.0), -90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e2", Vector3(13.0, 5.85, 15.25), -90.0, Vector2(0.5, 0.55), 72.0],
	["unit_e3_in", Vector3(19.0, 5.85, 26.0), -90.0, Vector2(0.5, 0.55), 74.0],
	# the way in (CabinWay): its door from the lounge's south aisle, the cabin from the door looking forward (the cabin
	# reference), deeper into the haze, at the join (all haze); out of it in the hall's section (all haze), stepping
	# out of its cut end, and the section from the deck
	["cabinway_door", Vector3(-12.0, 1.65, 13.0), 90.0, Vector2(0.5, 0.55), 70.0],
	["cabinway_ref", Vector3(-21.65, 1.65, 13.9), 180.0, Vector2(0.49, 0.28), 70.0],
	["cabinway_loop", Vector3(-21.65, 1.65, 17.5), 180.0, Vector2(0.5, 0.45), 70.0],    # the endless aisle (PartFog)
	["cabinway_deep", Vector3(-21.65, 1.65, 23.0), 180.0, Vector2(0.5, 0.4), 70.0],
	["cabinway_join", Vector3(-21.65, 1.65, 26.8), 180.0, Vector2(0.5, 0.5), 70.0],
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
	# the security office (run with --prologue): from the start up the south arm, the concept art's kind of view across
	# it, the corner into the north arm, the CCTV room from outside and from its chair, back along the north arm, the
	# south arm from its north end, the first island from the east
	["sec_start", Vector3(-17.4, 1.6, -15.9), 0.0, Vector2(0.5, 0.52), 70.0],
	["sec_west_door", Vector3(-18.3, 1.6, -16.3), 90.0, Vector2(0.5, 0.52), 70.0],      # the key card door (west)
	["sec_east_door", Vector3(-16.0, 1.6, -16.0), -90.0, Vector2(0.5, 0.52), 70.0],     # the east wall (its door removed)
	["sec_board", Vector3(-18.9, 1.65, -29.4), -90.0, Vector2(0.5, 0.52), 60.0],        # the cork notice board
	["sec_change_lockers", Vector3(-19.6, 1.6, -29.4), 0.0, Vector2(0.5, 0.52), 64.0],        # the changing lockers (where the print and cabinet were)
	["sec_ref", Vector3(-17.4, 1.55, -15.6), 4.0, Vector2(0.5, 0.5), 76.0, 4.0],
	["sec_corner", Vector3(-18.6, 1.6, -25.0), 70.0, Vector2(0.5, 0.52), 72.0],
	["sec_booth", Vector3(-19.6, 1.6, -27.0), -55.0, Vector2(0.5, 0.52), 74.0],
	["sec_cctv_chair", Vector3(-16.4, 1.25, -24.3), -38.0, Vector2(0.5, 0.42), 72.0],
	["sec_back", Vector3(-26.6, 1.6, -29.6), -100.0, Vector2(0.5, 0.52), 72.0],
	["sec_south", Vector3(-17.4, 1.6, -25.2), 180.0, Vector2(0.5, 0.52), 72.0],
	["sec_island", Vector3(-13.6, 1.6, -21.2), 70.0, Vector2(0.5, 0.55), 70.0],
	["sec_window", Vector3(-24.8, 1.6, -30.5), 168.0, Vector2(0.5, 0.5), 72.0],      # out of the north arm's south windows
	["sec_window_w", Vector3(-18.2, 1.6, -21.7), 92.0, Vector2(0.5, 0.5), 72.0],    # out of the south arm's west ones
	["sec_fitting", Vector3(-17.15, 1.95, -18.35), 0.0, Vector2(0.5, 0.5), 60.0, 38.0],  # up at a light fitting over the island
	["sec_desk", Vector3(-17.2, 1.35, -18.25), 0.0, Vector2(0.5, 0.5), 62.0, -24.0],    # a desk, its computer and partitions
	["sec_lockers", Vector3(-25.3, 1.45, -27.1), 88.0, Vector2(0.5, 0.5), 64.0, -6.0],  # the north arm's lockers and cabinets
	["sec_up", Vector3(-21.6, 1.6, -22.4), -35.0, Vector2(0.5, 0.5), 75.0, 48.0],       # up at the ceiling by the way into the north arm
]
const SHOTS := []
## Walk graph for people crossing the terminal (straight segments clear of counters, pillars and carousels).
const NAV := {
	"office": [Vector3(-16.0, 0, 2.5), ["office_door_in"]],
	"office_door_in": [Vector3(-18.2, 0, 6.2), ["office", "office_door_out"]],
	"office_door_out": [Vector3(-18.2, 0, 9.2), ["office_door_in", "hall_sw"]],
	"hall_sw": [Vector3(-11.0, 0, 10.0), ["office_door_out", "entrance_in", "hall_s"]],
	"entrance_in": [Vector3(-7.8, 0, 27.9), ["hall_sw"]],
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

## The player went down to the lounge (true) or back up to the 4th floor's corridors (false) by the lift or the stairs.
signal crossed(to_lounge: bool)

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
var sec_door: Node3D              # the door on the staff passage at the office's east wall (_security_door): seen from
                                  # the passage only — the office's side is plain wall (its door removed — user); the
                                  # prologue comes out of it (through the west door, Prologue's portal)
var sec_signs: Array[Node3D] = [] # its plate beside it and the SECURITY OFFICE sign over the passage
var sec_passage: Dictionary        # the same door as {root, leaf, block, use} (rattle / swing_door)
var sec_entry: Dictionary          # the office's west door: the steel key card door (steel_door, sec_reader beside it),
                                   # locked; past it a dark vestibule (sec_vestibule)
var sec_locked: Array = []          # the office's doors that only rattle: west, store room, night-duty room
var sec_root: Node3D               # the office's own node (everything on VIS_OFFICE)
var sec_view_panes: Array[MeshInstance3D] = []   # the backings of its big windows (SEC_VIEW_*)
var sec_view: PortalView           # what they show, the maze (_update_sec_view): live while your eye is in the office
var sec_inview: PortalView         # the maze's side of those windows: the office, live while your eye is near them
var service_hall: ServiceHall      # the maze of corridors round the office, far below (ServiceHall.ORIGIN)
var lift: Lift                     # 4F (the corridors' far end) <-> 1F (the lounge's east wall)
var stairs: StairCore              # the stair lobby's two copies and the 4F door (the stairwell itself is ServiceHall's)
var sec_dorm: Dictionary           # the night-duty room's door in the office's south wall (opens: open_dorm)
var dorm_bed: Node3D               # the night-duty room's bed (its local y 0.54 = the blanket's top, its head toward +X)
var sec_locker: Dictionary         # changing locker 04 on the north arm's north wall (OfficeKit.lockers hollow): {holder, door, hang, front, use, open}; open_locker
signal locker_toggled(open: bool)
var sec_reader: CardReader         # by the west door (sec_entry), room side; off until the story wants it
var sec_drawers := {}              # a1..a3 CRT desk, c1..c3 the guard's desk, f1..f4 filing, l1..l4 lateral
var sec_vestibule_end: MeshInstance3D   # the far wall of the dark vestibule outside the west door
var sec_vestibule: Array[MeshInstance3D] = []   # all of that vestibule's black boxes (ch1 lines them with the maze's view)
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
	_build_vertical()
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
		if l.light_cull_mask != Geo.VIS_SEALED:      # nor into the lift cars, the stair lobbies, the night-duty room
			l.light_cull_mask &= ~Geo.VIS_SEALED
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
		["secoffice", "보안실", 5.0, SEC_LIGHT],
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
## Main lounge (the lounge reference, SKETCH_SHOTS ref_lounge from its east end): a 37 x 32 m hall, the glass facade
## on the apron to the south and over its glass side no roof, only walls going on up into black air (LoungeShaft:
## the free-standing column row with them; SKETCH_SHOTS lounge_up / lounge_zenith), four rows of graphite columns carrying digital ad screens,
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
	# the airliner first: where it came through decides which panes are gone and where no seat can stand
	_wreck()
	var breaks := _facade_breaks()
	var crushed := _wreck_cells(3.0)
	# facade on the apron (south): mullions every 3 m, transoms every 3.2 m up to HALL_ROOF (LoungeShaft's wall on
	# up above it), smashed where the airliner came through; the main entrance and the emergency exit at the west end
	_glass_facade(Vector2(-20, HALL_S), Vector2(HALL_E, HALL_S), HALL_ROOF, [[-9.7, -5.9, 2.7], [-17.8, -16.2, 2.4]],
			-19.4, 3.0, [0.1, 3.3, 6.5, 9.7, 12.9, 16.1, 19.3], breaks)
	# no roof over the glass side: its walls (and one over the facade) go on up into the black (LoungeShaft)
	LoungeShaft.build(self)
	# end walls up into the 2F's slab (the 2F's own, with the shops' fronts in them, go on up to the ceiling, and the
	# shaft's on from there)
	Geo.wall(self, Vector2(-20, 7.6), Vector2(-20, HALL_S), MEZZ_Y - 0.1, wm, 0.4,
			[[CabinWay.DOOR_Z - 7.6 - Airliner.DOOR_W * 0.5 - 0.02, CabinWay.DOOR_Z - 7.6 + Airliner.DOOR_W * 0.5 + 0.02,
			Airliner.DOOR_H + 0.02]])      # the cabin's door (CabinWay: its lining runs through)
	# the east wall: the lift and the stair lobby's door (the way down from the 4th floor's corridors: _build_vertical)
	Geo.wall(self, Vector2(HALL_E, -2.5), Vector2(HALL_E, HALL_S), MEZZ_Y - 0.1, wm, 0.4,
			[[LIFT_Z + 2.5 - Lift.OPEN_W * 0.5, LIFT_Z + 2.5 + Lift.OPEN_W * 0.5, Lift.OPEN_H],
			[STAIR_Z + 2.5 - StairCore.DOOR_W * 0.5, STAIR_Z + 2.5 + StairCore.DOOR_W * 0.5, StairCore.DOOR_H]])
	# north: the lounge floor's back wall, up into the 2F's slab (the 2F's north wall stands on it): the opening into
	# the strip, then the storage room's own wall (x 12..22, on past the lounge's east end) with this one on top
	var top := MEZZ_Y - 0.1
	Geo.wall(self, Vector2(-12.2, -2.5), Vector2(12, -2.5), top, wm, 0.4, [[7.2, 17.2, STRIP_H]])
	Geo.wall(self, Vector2(12, -2.5), Vector2(HALL_E, -2.5), top - 3.2, wm, 0.4, [], 3.2)
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
	# structure: a beam on each column row across the ceiling (none over the glass side, where there is no ceiling),
	# columns with ad screens facing east and onto the aisle beside them round the edge of the grid only (the middle of
	# the lounge is open)
	for cz: float in COL_Z:
		if cz > ROOF_Z:
			continue
		Geo.box(self, Vector3((HALL_E - 20.0) * 0.5, HALL_H - 0.4, cz), Vector3(HALL_E + 20.0, 1.0, 0.7), Mats.get_mat("column"), false)
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
	# seat rows: back-to-back pairs in blocks (walk through the gaps) in the two seating bands (between the column rows
	# at 6 and 9.5, and from the cabin's aisle to the glass), a row facing the glass at the front; none in front of the
	# office's wall, the entrance or the emergency exit, none where the airliner lies or under the escalators. One row
	# on the north side, under the 2F.
	for band: Array in [[8.3, [-2.0, 4.5, 13.0]], [20.3, [-15.5, -8.5, -1.5, 5.0, 11.5]], [24.3, [-15.5, -8.5, -1.5, 5.0, 11.5]]]:
		var zz: float = band[0]
		var n := 6
		for x0: float in band[1]:
			var under := false
			for r: Rect2 in escalator_rects(0.3):
				under = under or r.intersects(Rect2(x0 - n * 0.31, zz - 1.1, n * 0.62, 1.6))
			if under:
				continue
			_seat_row(Vector3(x0, 0, zz), n, 0.0, crushed)
			_seat_row(Vector3(x0, 0, zz - 0.58), n, PI, crushed)
	for x0: float in [-1.5, 5.0, 11.5]:
		_seat_row(Vector3(x0, 0, 27.4), 6, 0.0, crushed)
	for x0: float in [-7.6, 10.0]:                          # (clear of the strip's opening, x -5..5)
		_seat_row(Vector3(x0, 0, -1.4), 6, 0.0, crushed)
	# bins at the ends of the seat blocks and against the walls, planters in the facade corners
	for p: Vector3 in [Vector3(10.1, 0, 8.0), Vector3(-12.0, 0, 22.3), Vector3(-5.0, 0, 22.3), Vector3(8.3, 0, 22.3),
			Vector3(1.75, 0, 22.3), Vector3(-5.6, 0, -1.95), Vector3(16.4, 0, 1.0)]:
		if not _crushed_at(crushed, p) and not _under_escalator(p, 0.6):
			Props.trash_bin(self, p)
	for p in [Vector3(-19.2, 0, HALL_S - 0.8), Vector3(-11.6, 0, HALL_S - 0.8), Vector3(HALL_E - 0.9, 0, HALL_S - 0.9)]:
		Props.planter(self, p)
	# signage: Departures / Arrivals across the north aisle seen from the east end (from column to column, below the
	# 2F's level so it does not stand in the view from the staff doors), exit and lounge under the 2F in the north-east
	# corner, security over the atrium west of the escalators (hung from the ceiling, edge-on to the staff doors), the
	# staff sign by the office at the far end
	var under := MEZZ_Y - SLAB                   # the ceiling under the 2F
	Props.wayfinding_sign(self, Vector3(COL_X[-1] + 0.5, 2.95, (COL_Z[0] + COL_Z[1]) * 0.5), PI / 2, Vector2(5.0, 1.15), [
		["arrow", 90.0, 0.42, Vector2(-1.55, 0)],
		["text", "출발", 50, Vector2(-0.78, 0.2)],
		["text", "Departures", 34, Vector2(-0.78, -0.22)],
		["rule", Vector2(0, 0)],
		["text", "도착", 50, Vector2(0.78, 0.2)],
		["text", "Arrivals", 34, Vector2(0.78, -0.22)],
		["arrow", 0.0, 0.42, Vector2(1.55, 0)],
	])
	Props.wayfinding_sign(self, Vector3(HALL_E - 1.5, 3.0, 0.0), PI / 2, Vector2(4.6, 0.95), [
		["arrow", 180.0, 0.46, Vector2(-1.9, 0)],
		["text", "출구 · 교통센터", 44, Vector2(-0.88, 0.17)],
		["text", "Exit · Transport", 32, Vector2(-0.88, -0.2)],
		["rule", Vector2(0.23, 0)],
		["text", "2층 라운지", 44, Vector2(1.2, 0.17)],
		["text", "Lounge 2F", 32, Vector2(1.2, -0.2)],
		["arrow", 90.0, 0.46, Vector2(1.98, 0)],
	], under)
	Props.wayfinding_sign(self, Vector3(-13.0, 6.0, 6.0), PI / 2, Vector2(6.4, 1.0), [
		["tile", "icon_departures", 0.68, Vector2(-2.65, 0)],
		["text", "출국 · 보안검색", 54, Vector2(-0.2, 0.18)],
		["text", "Departures · Security", 38, Vector2(-0.2, -0.2)],
		["arrow", 0.0, 0.55, Vector2(2.65, 0)],
	], HALL_H)
	# (the south aisle has no sign now: over the glass side there is nothing to hang one from, and no column to span)
	signs["hall_departures"] = Props.hanging_sign(self, Vector3(0, 3.0, -5.0), 0.0, Vector2(6.0, 0.9), [
		["↑  출국 · 보안검색", 60, Color(1, 1, 1), Vector2(-0.6, 0.18)],
		["DEPARTURES · SECURITY", 40, Color(0.85, 0.88, 0.95), Vector2(-0.6, -0.24)],
		["@icon_departures", 0.66, Color(1, 1, 1), Vector2(2.3, 0.0)],     # airport departures pictogram
	], STRIP_H)
	signs["hall_baggage"] = Props.hanging_sign(self, Vector3(-7.4, 3.05, -6.2), 0.0, Vector2(4.6, 0.8), [
		["◀  수하물 수취  BAGGAGE CLAIM", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], STRIP_H)
	signs["hall_staff"] = Props.hanging_sign(self, Vector3(-16.2, 3.1, 10.2), PI / 2, Vector2(4.4, 0.8), [
		["◀  시설관리실  STAFF ONLY", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], under)
	LevelKit.wall_sign(self, Vector3(-11.05, 2.95, -8.28), 0.0, "직원 통로 · 수하물 수취\nSTAFF · BAGGAGE CLAIM", Vector2(1.7, 0.5))   # clear of the west wall
	_crash_debris(breaks)
	_lounge_smoke()


## A thin smoke hanging in the whole lounge, thicker in slow drifts (a noise density), so the light shows in the air
## (the night-airport reference; on top of the world's own faint fog).
func _lounge_smoke() -> void:
	_smoke(AABB(Vector3(-20, 0, -2.5), Vector3(HALL_E + 20.0, LoungeShaft.CLEAR_FROM, HALL_S + 2.5)), 21)


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


## The lounge's lights: a grid of small square downlights in the dark ceiling (along the aisles every other one throws
## light down, elsewhere fewer), over the glass side lights up in the dark with no fixture and washes up its walls
## (LoungeShaft.lights), dim fills that stand in for the bounce, the strip's troffers. All on the hall zone.
func _hall_lights() -> void:
	var z: LightZone = zones.hall
	# under the 2F: the lounge floor's low ceiling and the galleries' undersides, a downlight every 5 m, every other
	# one throwing light
	var low := MEZZ_Y - SLAB - 0.02
	var k := 0
	for rz: float in [-0.9, 1.4]:
		var x := -10.0
		while x < HALL_E - 1.0:
			z.add_downlight(Vector3(x, low, rz), 0.36, k % 2 == 0, 4.2, 7.5, 50.0)
			k += 1
			x += 5.0
	for gx: float in [-18.5, -16.5, HALL_E - 3.5, HALL_E - 1.5]:
		var gz := ATRIUM.position.y + 2.5
		while gz < HALL_S - 1.0:
			z.add_downlight(Vector3(gx, low, gz), 0.36, k % 2 == 0, 4.2, 7.5, 50.0)
			k += 1
			gz += 5.0
	# the 2F's ceiling and the atrium's (over the glass side there is none: LoungeShaft.lights): [z, every nth one lit,
	# spot energy]
	var rows := [[0.0, 2, 6.5], [4.0, 2, 7.0], [8.0, 3, 7.5]]
	for r in rows.size():
		var rz: float = rows[r][0]
		var x := -16.0
		var i := r
		while x < HALL_E - 1.0:
			z.add_downlight(Vector3(x, HALL_H - 0.02, rz), 0.42, i % rows[r][1] == 0, rows[r][2], 18.0)
			i += 1
			x += 5.0
	# fills standing in for the bounce: on the lounge floor under the 2F, on the 2F, in the atrium
	for fx: float in [-13.0, -1.0, 10.0]:
		for f: Array in [[Vector3(fx, 3.0, AISLES[0]), 0.45, 12.0], [Vector3(fx + 5.0, 3.0, 8.0), 0.45, 12.0],
				[Vector3(fx, 3.0, AISLES[1]), 0.45, 12.0], [Vector3(fx, MEZZ_Y + 4.0, 0.0), 0.7, 18.0],
				[Vector3(fx + 5.0, MEZZ_Y + 4.0, 16.0), 0.7, 18.0], [Vector3(fx + 5.0, 8.0, 22.0), 0.7, 18.0],
				[Vector3(fx, 9.0, 26.0), 0.6, 16.0]]:
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
	# two spots up in the dark over the glass side left on over where the airliner came to rest: its nose and its hull
	# where it broke in, in the light (each from a little north-east of it)
	for target: Vector3 in [_wreck_point(Vector3(0, 2.0, 24.0)), _wreck_point(Vector3(0, 3.0, 19.0))]:
		var from := Vector3(target.x + 3.5, LoungeShaft.LAMP_Y, target.z - 4.0)
		var sp := Geo.spot(self, from, target, ZONE_LIGHT, 8.0, 38.0, 32.0)
		sp.light_volumetric_fog_energy = 0.0        # no glow: looking up along them the middle stays black
		z.add_light(sp)
	LoungeShaft.lights(self, z)
	for sx: float in [-6.0, 0.0, 6.0]:
		z.add_panel(Vector3(sx, STRIP_H - 0.08, -5.5), Vector2(0.5, 2.4), sx == 0.0, 1.4, 10.0)
	for h: Vector3 in [Vector3(-10, 7, 4), Vector3(8, 7, 4), Vector3(-10, 8, 20), Vector3(8, 8, 20)]:
		z.add_hum(h, -19.0)
	z.add_hum(Vector3(0, 3.2, -5.5), -20.0)


## The lounge's columns (floor points): the edge of the grid (COL_X x COL_Z), the middle left open.
static func lounge_columns() -> Array:
	var out := []
	for cx: float in COL_X:
		for i in COL_Z.size():
			if cx == COL_X[0] or cx == COL_X[-1] or i == 0 or i == COL_Z.size() - 1:
				out.append(Vector3(cx, 0, COL_Z[i]))
	return out


## A graphite column of the lounge grid on a steel base: up to the 2F's floor where the 2F is over it or on its edge
## (no column stands on the 2F), up to the ceiling where it stands under the ceiling's edge, and the row standing out
## over the glass side, where there is no ceiling, on up into the dark with the walls (LoungeShaft, user: "가운데
## 기둥도 천장이랑 같은 높이로"); a digital ad screen on its east face (what you see down the hall from the east end)
## and one on the face toward the aisle beside it (`side` +1: the +Z face, -1: the -Z face).
func _lounge_column(p: Vector3, side: float) -> void:
	var s := 1.3
	var h := HALL_H
	var mat := Mats.get_mat("column")
	if p.z <= ATRIUM.position.y + 0.1:
		h = MEZZ_Y - 0.005
	elif p.z > ROOF_Z + s:
		h = LoungeShaft.TOP
		mat = Mats.get_mat("column_shaft")
	Geo.box(self, p + Vector3(0, h * 0.5, 0), Vector3(s, h, s), mat)
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


## A pair of stopped escalators from the 2F's edge down into the atrium, toward the airliner (Escalator, rising
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
## here) and the door the chase comes back to. Built after the police-station concept art the user gave (Hitman
## Absolution's; "이렇게해줘 보안실, 이런 기역자"), about twice the size of the room it was: an L (ㄱ). Its south arm
## (SEC_LEG) runs north along the staff passage with both doors in it; from where you start at its south end you look
## up it as in the concept art — steel-framed windows with papers taped on them down both walls between pilasters,
## the passage door near on your right, and at the far end the CCTV room's corner block (SEC_CCTV) with its counter
## window and a television on a bracket at its corner (no clocks in the office any more — user); past it on the left the north arm
## (SEC_BAR) turns west. Black-and-white checkerboard vinyl, cream plaster with a darker band at the foot, steel beams
## under a plaster ceiling, pipes, twin-tube fluorescent fittings hung on rods (one dead), brass ceiling fans turning;
## steel desks in pairs buried in folders and papers with old PCs, the reception counter with its glazing, beige,
## olive and grey filing cabinets, lockers, a water cooler, the radio chargers, a coat rack, posters.
## Its one door is the west door (sec_entry: the steel key card door; past it a dark vestibule — the prologue's way out
## to the staff passage and ch1's way in and then out to the corridors, both through portals); it rattles until a story
## opens it. The night-duty room's door opens (open_dorm). The east wall is plain inside; on the passage side it has a
## door (sec_door), the one the prologue comes out of. (The store room's door in the north arm's north wall was removed — user.) Drawers that
## open ([E], Drawer; sec_drawers): the CRT desk's (a), the guard's (c; the key card is in c3), a filing cabinet (f)
## and two lateral cabinets (l). It all stands on VIS_OFFICE, the only render layer its lights reach (office_layers).
func _build_security_office() -> void:
	sec_root = Node3D.new()
	sec_root.name = "SecurityOffice"
	add_child(sec_root)
	var o := sec_root
	_sec_shell(o)
	_sec_ceiling(o)
	# a little smoke hanging in the air, so the light under the fittings shows faintly (user: "약간의 스모크도")
	for r: Rect2 in sec_floor_rects():
		_smoke(AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, SEC_CEIL, r.size.y)), 31, 0.062, Color(0.8, 0.78, 0.72)).height_falloff = 0.0
	_cctv_room(o)
	var sets := {}
	_sec_south(o, sets)
	_sec_desks(o, sets)
	_sec_walls(o, sets)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2170
	for k: String in sets:
		var arr: Array = sets[k]
		for i in arr.size():
			var dr: Drawer = arr[i]
			sec_drawers["%s%d" % [k, i + 1]] = dr
			OfficeKit.clutter(dr.inside, rng, dr.size.x, dr.size.z)
	sec_reader = CardReader.create(o, Vector3(SEC_LEG.position.x + 0.165, 1.2, SEC_ENTRY_Z + 0.83), PI / 2)   # latch side
	sec_reader.interactable.enabled = false
	_security_door()
	# outside the west door: a short dark vestibule (black, no light), its far wall where the way in arrives
	var black := Mats.get_mat("black")
	var vx := SEC_LEG.position.x - 1.25
	sec_vestibule.append(Geo.box(self, Vector3(vx, -0.05, SEC_ENTRY_Z), Vector3(2.3, 0.1, 2.9), black))
	sec_vestibule.append(Geo.box(self, Vector3(vx, 2.55, SEC_ENTRY_Z), Vector3(2.3, 0.1, 2.9), black, false))
	for sz in [-1.0, 1.0]:
		sec_vestibule.append(Geo.box(self, Vector3(vx, 1.3, SEC_ENTRY_Z + sz * 1.4), Vector3(2.3, 2.6, 0.1), black))
	sec_vestibule_end = Geo.box(self, Vector3(SEC_LEG.position.x - 2.35, 1.3, SEC_ENTRY_Z), Vector3(0.1, 2.6, 2.9), black)
	sec_vestibule.append(sec_vestibule_end)
	for dd: Dictionary in sec_locked:
		var d := dd
		(d.use as Interactable).callback = func(): rattle(d)
	office_layers(o)
	office_layers(zones.secoffice)
	# the window backings show sec_view to your eye only: off the office's layer, so the maze's view in through the
	# same windows (sec_inview, which sees only that layer) looks straight through them
	for p in sec_view_panes:
		p.layers = Geo.VIS_PORTAL_HIDDEN
	_build_dorm()
	# what the big windows look out on: the maze of corridors round the office, far below, its lights always on
	service_hall = ServiceHall.new()
	add_child(service_hall)
	service_hall.build()
	service_hall.zone.set_on(true, true)


## The way between the 4th floor — the security office and the corridors round it (ServiceHall, built far below) —
## and the lounge's 1st floor (user: "출구 문을 엘리베이터로 바꿔줘", "계단으로 이동하는 공간도 필요해", "보안실은
## 4층이고 공항 라운지는 1층"): the lift's car and the stair lobby are each built twice, behind the corridors' walls
## and behind the lounge's east wall (Lift, StairCore), and linked; either one carries you over while it is shut
## (crossed). On the lounge side: the lift by the north aisle's east end, the stairs' door beside it, a sign over both.
func _build_vertical() -> void:
	var lift_l := Lift.car(self, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(HALL_E - 0.2, 0, LIFT_Z)), 0.4, 1, 4)
	var lobby_l := StairCore.lobby(self, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(HALL_E + 0.2, 0, STAIR_Z)), true, false, 0.4)
	lift = Lift.link(self, service_hall.lift_car, lift_l, 4, 1, 0)
	stairs = StairCore.link(self, service_hall.stair_lobby, lobby_l, service_hall.stair_door)
	lift.carried.connect(func(to: int): crossed.emit(to == 1))
	stairs.carried.connect(func(to: int): crossed.emit(to == 1))
	var face := HALL_E - 0.2
	# a light washing the wall with the two doors, so they read from across the lounge
	var wash := Geo.spot(self, Vector3(face - 1.5, MEZZ_Y - SLAB - 0.1, (LIFT_Z + STAIR_Z) * 0.5),
			Vector3(face, 0.9, (LIFT_Z + STAIR_Z) * 0.5), ZONE_LIGHT, 2.6, 7.0, 64.0)
	wash.light_volumetric_fog_energy = 0.2
	zones.hall.add_light(wash)
	LevelKit.wall_sign(self, Vector3(face, 3.2, (LIFT_Z + STAIR_Z) * 0.5), -90.0, "엘리베이터 · 비상계단  ELEVATOR · STAIRS", Vector2(3.6, 0.5))
	var s := Node3D.new()
	add_child(s)
	s.position = Vector3(face - 0.03, StairCore.DOOR_H + 0.38, STAIR_Z)
	s.rotation.y = -PI / 2
	Geo.box(s, Vector3.ZERO, Vector3(0.8, 0.24, 0.05), Mats.std(Color(0.12, 0.13, 0.13), 0.5), false)
	Geo.box(s, Vector3(0, 0, 0.026), Vector3(0.74, 0.19, 0.004), Mats.emissive(Color(0.15, 0.85, 0.45), 1.1, Color(0.05, 0.4, 0.2)), false)
	Geo.fit(Geo.label(s, "비상계단  STAIRS", Vector3(0, 0, 0.03), 0.0, 48, Color(1, 1, 1), 0.003), 0.66, 0.15).set_meta("no_fit", true)


## The night-duty room behind the office's south wall (user: "사무실 안에 숙직실 있잖아, 거기 작은 숙직 공간 임의로
## 만들어줘" — the colleague on the shift before yours tells you the rules, goes in there and is gone): a small room,
## 3.5 x 1.8 m between the office and the corridor along its south side, no other door, no window. Yellow vinyl floor
## (장판), papered walls, a low ceiling with its lamp off; a steel-frame bed made up with a grey wool blanket against the
## east wall, a low cabinet with a small television, kettle and cup noodles, a mini fridge with a little lamp on it (the
## only light: on), a tall steel locker, coat hooks with a jacket and a cap, slippers by the door, a calendar (its clock was
## removed — user). On Geo.VIS_SEALED with its own lamp (the office's lights do not reach through its walls). Its door: sec_dorm,
## open_dorm.
func _build_dorm() -> void:
	var r := Node3D.new()
	r.name = "NightDutyRoom"
	add_child(r)
	var x0 := SEC_LEG.position.x + 0.15        # -22.25
	var x1 := -18.75
	var z0 := SEC_LEG.end.y + 0.15              # -14.85: the office wall's back face
	var z1 := -13.05                            # the corridor's wall along it (ServiceHall's S)
	var ht := 2.6
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var paper := Mats.std(Color(0.74, 0.71, 0.62), 0.9)
	var vinyl := Mats.std(Color(0.66, 0.47, 0.22), 0.32)
	var ceil_m := Mats.std(Color(0.78, 0.77, 0.72), 0.9)
	Geo.box(r, Vector3(cx, -0.05, cz), Vector3(x1 - x0, 0.1, z1 - z0), vinyl)
	Geo.box(r, Vector3(cx, ht + 0.05, cz), Vector3(x1 - x0 + 0.4, 0.1, z1 - z0 + 0.4), ceil_m, false)
	Geo.box(r, Vector3(x0 - 0.15, ht * 0.5, cz), Vector3(0.3, ht, z1 - z0), paper)
	Geo.box(r, Vector3(x1 + 0.1, ht * 0.5, cz), Vector3(0.2, ht, z1 - z0), paper)
	Geo.box(r, Vector3(cx, ht * 0.5, z1 + 0.1), Vector3(x1 - x0 + 0.5, ht, 0.2), paper)
	# the office wall's back face lined (round the door)
	var dl := SEC_DORM_X - 0.475 - 0.03
	var dr := SEC_DORM_X + 0.475 + 0.03
	Geo.box(r, Vector3((x0 + dl) * 0.5, ht * 0.5, z0 + 0.006), Vector3(dl - x0, ht, 0.012), paper, false)
	Geo.box(r, Vector3((dr + x1) * 0.5, ht * 0.5, z0 + 0.006), Vector3(x1 - dr, ht, 0.012), paper, false)
	Geo.box(r, Vector3(SEC_DORM_X, (2.19 + ht) * 0.5, z0 + 0.006), Vector3(dr - dl, ht - 2.19, 0.012), paper, false)
	# skirting all round
	var skirt := Mats.std(Color(0.36, 0.25, 0.15), 0.5)
	Geo.box(r, Vector3(x0 + 0.006, 0.04, cz), Vector3(0.012, 0.08, z1 - z0), skirt, false)
	Geo.box(r, Vector3(x1 - 0.006, 0.04, cz), Vector3(0.012, 0.08, z1 - z0), skirt, false)
	Geo.box(r, Vector3(cx, 0.04, z1 - 0.006), Vector3(x1 - x0, 0.08, 0.012), skirt, false)
	# the ceiling lamp (off)
	Geo.cyl(r, Vector3(cx + 0.4, ht - 0.03, cz), 0.2, 0.06, Mats.std(Color(0.86, 0.85, 0.8), 0.4))
	# the bed, made up, against the east wall (its head there)
	var bed := Node3D.new()
	r.add_child(bed)
	bed.position = Vector3(x1 - 0.98, 0, z1 - 0.47)
	dorm_bed = bed
	var frame := Mats.std(Color(0.22, 0.27, 0.25), 0.45, 0.4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.box(bed, Vector3(sx * 0.95, 0.2, sz * 0.43), Vector3(0.04, 0.4, 0.04), frame, false)
		Geo.box(bed, Vector3(sx * 0.95, 0.38 + (0.25 if sx > 0 else 0.0), 0), Vector3(0.03, 0.03, 0.86), frame, false)
	Geo.box(bed, Vector3(0.95, 0.5, 0), Vector3(0.04, 0.5, 0.04), frame, false)
	for sz in [-1.0, 1.0]:
		Geo.box(bed, Vector3(0, 0.33, sz * 0.43), Vector3(1.9, 0.04, 0.03), frame, false)
	Geo.box(bed, Vector3(0, 0.42, 0), Vector3(1.88, 0.14, 0.84), Mats.std(Color(0.55, 0.6, 0.66), 0.85), false)
	var wool := Mats.std(Color(0.47, 0.44, 0.37), 0.95)
	var blanket := Geo.box(bed, Vector3(-0.22, 0.515, 0.0), Vector3(1.4, 0.05, 0.9), wool, false)
	blanket.rotation.y = 0.03
	var fold := Geo.box(bed, Vector3(0.42, 0.53, 0.02), Vector3(0.3, 0.09, 0.9), wool, false)
	fold.rotation.z = 0.12
	var pillow := Geo.box(bed, Vector3(0.74, 0.54, 0.0), Vector3(0.32, 0.1, 0.5), Mats.std(Color(0.84, 0.83, 0.78), 0.9), false)
	pillow.rotation.y = -0.06
	Geo.blocker(bed, Vector3(0, 0.3, 0), Vector3(1.96, 0.6, 0.9))
	# a low cabinet on the south wall west of the bed: a small television, kettle, cup noodles, an ashtray
	var cab := Node3D.new()
	r.add_child(cab)
	cab.position = Vector3(-21.25, 0, z1 - 0.23)
	var wood := Mats.std(Color(0.36, 0.25, 0.16), 0.55)
	Geo.box(cab, Vector3(0, 0.27, 0), Vector3(0.85, 0.54, 0.44), wood)
	Geo.box(cab, Vector3(0, 0.27, -0.222), Vector3(0.8, 0.002, 0.004), Mats.std(Color(0.1, 0.07, 0.05), 0.6), false)
	for sx in [-1.0, 1.0]:
		Geo.box(cab, Vector3(sx * 0.06, 0.4, -0.226), Vector3(0.05, 0.015, 0.012), Mats.get_mat("metal"), false)
	OfficeKit.crt(cab, Vector3(-0.15, 0.54, 0.0), PI)
	Geo.cyl(cab, Vector3(0.26, 0.65, -0.02), 0.07, 0.22, Mats.std(Color(0.8, 0.8, 0.78), 0.35))
	Geo.box(cab, Vector3(0.26, 0.77, -0.02), Vector3(0.05, 0.03, 0.17), Mats.get_mat("plastic_dark"), false)
	for i in 2:
		Geo.cyl(cab, Vector3(0.14 - i * 0.02, 0.6 + i * 0.1, 0.12), 0.05, 0.1, Mats.std(Color(0.85, 0.3, 0.12) if i == 0 else Color(0.9, 0.88, 0.8), 0.6))
	Geo.cyl(cab, Vector3(0.33, 0.555, 0.12), 0.06, 0.03, Mats.std(Color(0.5, 0.52, 0.55), 0.3, 0.6))
	# along the office wall east of the door: a mini fridge with the lamp on it, a tall locker
	var fr := Node3D.new()
	r.add_child(fr)
	fr.position = Vector3(-19.82, 0, z0 + 0.23)
	Geo.box(fr, Vector3(0, 0.42, 0), Vector3(0.5, 0.84, 0.44), Mats.std(Color(0.82, 0.8, 0.74), 0.4))
	Geo.box(fr, Vector3(0.16, 0.5, 0.222), Vector3(0.02, 0.18, 0.012), Mats.get_mat("plastic_dark"), false)
	var lamp := Node3D.new()
	fr.add_child(lamp)
	lamp.position = Vector3(-0.08, 0.84, 0.0)
	var brass := Mats.std(Color(0.55, 0.42, 0.2), 0.35, 0.7)
	Geo.cyl(lamp, Vector3(0, 0.015, 0), 0.07, 0.03, brass)
	Geo.cyl(lamp, Vector3(0, 0.17, 0), 0.012, 0.3, brass)
	Geo.cyl(lamp, Vector3(0, 0.34, 0), 0.1, 0.13, Mats.emissive(Color(1.0, 0.8, 0.52), 0.9, Color(0.86, 0.78, 0.6)))
	var warm := Geo.omni(lamp, Vector3(0, 0.3, 0.12), Color(1.0, 0.76, 0.48), 0.85, 3.6)
	warm.light_volumetric_fog_energy = 0.0
	var fill := Geo.omni(r, Vector3(cx, 2.2, cz), Color(0.62, 0.72, 0.78), 0.12, 4.0)
	fill.light_volumetric_fog_energy = 0.0
	fill.light_specular = 0.0
	OfficeKit.lockers(r, Vector3(-19.05, 0, z0 + 0.25), 0.0, 1, ["숙직"])
	Geo.blocker(fr, Vector3(0, 0.42, 0), Vector3(0.5, 0.84, 0.44))
	Geo.blocker(r, Vector3(-19.05, 0.9, z0 + 0.25), Vector3(0.42, 1.8, 0.5))
	# coat hooks with a jacket and a cap on the west wall, slippers by the door
	var hooks := Node3D.new()
	r.add_child(hooks)
	hooks.position = Vector3(x0 + 0.02, 1.72, -13.9)
	hooks.rotation.y = PI / 2
	Geo.box(hooks, Vector3.ZERO, Vector3(0.6, 0.06, 0.02), wood, false)
	var navy := Mats.std(Color(0.1, 0.12, 0.18), 0.9)
	var jacket := Geo.box(hooks, Vector3(-0.12, -0.38, 0.06), Vector3(0.44, 0.72, 0.07), navy, false)
	jacket.rotation.z = 0.04
	Geo.cyl(hooks, Vector3(0.2, -0.05, 0.07), 0.09, 0.07, navy).rotation.x = PI / 2
	for i in 2:
		var sl := Geo.box(r, Vector3(-21.95 + i * 0.13, 0.015, -14.25), Vector3(0.1, 0.03, 0.26), Mats.std(Color(0.2, 0.35, 0.55), 0.7), false)
		sl.rotation.y = 0.15 - i * 0.2
	# the calendar (no clock — user)
	OfficeKit.wall_calendar(r, Vector3(x0 + 0.002, 1.5, -14.55), PI / 2)
	Lift._reverb(r, Vector3(cx, ht * 0.5, cz), Vector3(x1 - x0, ht, z1 - z0), "RevTight", 0.24)
	Geo.seal(r)


## Opens (or shuts) changing locker 04 on the north arm's north wall (sec_locker): its door swings out on its hinge with a tinny creak / a
## small steel slam; locker_toggled tells the story.
func open_locker(open: bool) -> void:
	sec_locker.open = open
	(sec_locker.use as Interactable).prompt = "사물함 닫기" if open else "사물함 열기"
	var door: Node3D = sec_locker.door
	var tw := door.create_tween()
	tw.tween_property(door, "rotation:y", -1.9 if open else 0.0, 0.55 if open else 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	var at := door.global_position + Vector3(0, 1.0, 0)
	if open:
		Snd.play_at("drawer_open_2", at, -10.0, 0.72, 4.0)
		Snd.play_at("lock_click", at, -14.0, 1.25, 3.0)
	else:
		tw.tween_callback(func(): Snd.play_at("door_slam", at, -20.0, 1.7, 4.0))
	locker_toggled.emit(open)


## Opens (or shuts) the night-duty room's door, into the room, over `time` s. The door is the player's to open and
## shut ([E]) and the story's: the shift colleague goes in there and is not seen again.
func open_dorm(open: bool, time := 0.7) -> void:
	var leaf: Node3D = sec_dorm.leaf
	if not open:
		# not on whoever stands in the doorway
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			var q := (sec_dorm.root as Node3D).global_transform.affine_inverse() * p.global_position
			if absf(q.x) < 0.5 and absf(q.z) < 0.85:
				return
	sec_dorm.open = open
	(sec_dorm.use as Interactable).prompt = "문 닫기" if open else "문 열기"
	(sec_dorm.block as StaticBody3D).collision_layer = 0 if open else Geo.LAYER_WORLD
	var at := (sec_dorm.root as Node3D).global_position + Vector3(0, 1.0, 0)
	Snd.play_at("amb_creak_1" if open else "door_slam", at, -8.0 if open else -12.0, 1.1, 4.0)
	var tw := leaf.create_tween()
	tw.tween_property(leaf, "rotation:y", deg_to_rad(-86.0) if open else 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)


## Puts `node` and everything under it on the security office's render layer (VIS_OFFICE), the only one the office's
## own lights reach: nothing here casts shadows, so without it they would light the dark staff passage and the
## baggage hall through the walls. Anything the story adds to the office later goes through here too.
static func office_layers(node: Node) -> void:
	var all: Array = [node]
	all.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for n in all:
		if n is Light3D:
			(n as Light3D).light_cull_mask = VIS_OFFICE
			(n as Light3D).layers |= VIS_OFFICE      # a camera that sees only the office (sec_inview) keeps its lights
		elif n is VisualInstance3D:
			(n as VisualInstance3D).layers = VIS_OFFICE


## What has a floor and a ceiling: the office (the L as it was) and the CCTV room in it. The corner block the CCTV room
## once filled, outside its own north and east walls, is outside the building now.
static func sec_floor_rects() -> Array[Rect2]:
	var cw := SEC_CCTV.position.x               # the CCTV room's west face (the office's wall up to the north wall)
	var cs := SEC_CCTV.end.y                    # its south face (the office's wall out to the east wall)
	return [Rect2(SEC_LEG.position.x, cs, SEC_LEG.size.x, SEC_LEG.end.y - cs),
		Rect2(SEC_LEG.position.x, SEC_LEG.position.y, SEC_CCTV.end.x - SEC_LEG.position.x, cs - SEC_LEG.position.y),
		Rect2(SEC_BAR.position.x, SEC_BAR.position.y, cw - SEC_BAR.position.x, SEC_BAR.size.y),
		Rect2(cw, SEC_CCTV.position.y, SEC_CCTV.size.x, SEC_BAR.end.y - SEC_CCTV.position.y)]


## Floor, walls, pilasters and doors. The east wall is the staff passage's (3 m, _build_baggage): it goes on up to the
## ceiling over it and is lined on the room side round the passage door.
func _sec_shell(o: Node3D) -> void:
	var wm := Mats.get_mat("plaster_wall")
	for r: Rect2 in sec_floor_rects():
		var c := r.get_center()
		Geo.box(o, Vector3(c.x, -0.05, c.y), Vector3(r.size.x, 0.1, r.size.y), Mats.get_mat("floor_office_stone"))
	var h := SEC_CEIL + 0.2
	var west := SEC_LEG.position.x
	var north := SEC_BAR.position.y
	var bx := SEC_BAR.position.x
	var ls := SEC_LEG.position.y
	var south := SEC_LEG.end.y
	Geo.wall(o, Vector2(west, south), Vector2(-12.4, south), h, wm, 0.3, [[SEC_DORM_X - west - 0.475, SEC_DORM_X - west + 0.475, 2.13]])
	# the west wall and the north arm's south wall are holed for the big windows (head and sill, SEC_VIEW_*), each
	# with a blocker in its plane
	var hw := SEC_VIEW_SIZE.x * 0.5
	var head := SEC_VIEW_Y + SEC_VIEW_SIZE.y * 0.5
	var sill := SEC_VIEW_Y - SEC_VIEW_SIZE.y * 0.5
	var cuts_w := [[SEC_ENTRY_Z - ls - 0.55, SEC_ENTRY_Z - ls + 0.55, 2.2]]      # the steel key card door's opening
	for z: float in SEC_VIEW_W:
		cuts_w.append([z - ls - hw, z - ls + hw, head, sill])
		Geo.blocker(o, Vector3(west, SEC_VIEW_Y, z), Vector3(0.3, SEC_VIEW_SIZE.y, SEC_VIEW_SIZE.x))
	Geo.wall(o, Vector2(west, ls), Vector2(west, south), h, wm, 0.3, cuts_w)
	var cuts_n := []
	for x: float in SEC_VIEW_N:
		cuts_n.append([x - bx - hw, x - bx + hw, head, sill])
		Geo.blocker(o, Vector3(x, SEC_VIEW_Y, ls), Vector3(SEC_VIEW_SIZE.x, SEC_VIEW_SIZE.y, 0.3))
	Geo.wall(o, Vector2(bx, ls), Vector2(west, ls), h, wm, 0.3, cuts_n)
	Geo.wall(o, Vector2(bx, north), Vector2(bx, ls), h, wm, 0.3)     # (its archive door was removed — user: "문서고 문 없애")
	Geo.wall(o, Vector2(bx, north), Vector2(SEC_CCTV.position.x + 0.2, north), h, wm, 0.3)   # (its store-room door removed — user)
	# (where the store room's door was hung a framed aircraft print — taken down for the lockers, user: "액자 치우고")
	Geo.wall(o, Vector2(-12.4, north), Vector2(-12.4, south), h - 3.0, wm, 0.3, [], 3.0)
	# the room side lined in one piece: no door in it (the 관계자 외 출입금지 door was removed — user: "사무실 내부에
	# 자제창고랑 관계자 출입금지 문 없애줘"); the passage's door stays on its far side (_security_door), and a collider
	# in the lining keeps you (and the [E] ray) out of its opening
	Geo.box(o, Vector3(-12.555, SEC_CEIL * 0.5, (SEC_CCTV.end.y + south - 0.15) * 0.5), Vector3(0.02, SEC_CEIL, south - 0.15 - SEC_CCTV.end.y), wm, false)
	Geo.blocker(o, Vector3(-12.555, 1.1, -16.0), Vector3(0.02, 2.2, 1.1))
	# pilasters under the beams, down both walls of the south arm and on the north arm's walls
	for zz: float in SEC_BEAMS_Z:
		_pilaster(o, Vector3(west + 0.3, 0, zz), true)
		if zz > SEC_CCTV.end.y:
			_pilaster(o, Vector3(-12.55 - 0.15, 0, zz), true)
	for x: float in SEC_BEAMS_X:
		_pilaster(o, Vector3(x, 0, north + 0.3), false)
	_pilaster(o, Vector3(SEC_BEAMS_X[1], 0, ls - 0.3), false)
	# the west door is the steel key card door (it and the '관계자 외 출입금지' door swapped places — user: "카드 키
	# 대고 나갈 수 있는 문을 관계자 외 출입금지 문 위치로"); turned so it opens into the room (rotation.y > 0)
	sec_entry = steel_door(o, Vector3(west, 0, SEC_ENTRY_Z), PI)
	# the night-duty room's door opens (its room is _build_dorm; a threshold under it on the office's layer)
	sec_dorm = OfficeKit.door(o, Vector3(SEC_DORM_X, 0, south), PI / 2, "숙직실")
	sec_dorm.open = false
	(sec_dorm.use as Interactable).callback = func(): open_dorm(not sec_dorm.open)
	Geo.box(o, Vector3(SEC_DORM_X, -0.0175, south + 0.075), Vector3(0.95, 0.045, 0.15), Mats.std(Color(0.3, 0.22, 0.14), 0.6))
	sec_locked = [sec_entry]


## A framed print on a wall face (facing +Z after `rot_y`, `at` on the face): a thin black frame, a white mat, the
## picture `tex` once across `size` (m).
func _framed_print(o: Node3D, at: Vector3, rot_y: float, tex: String, size: Vector2) -> void:
	var h := Node3D.new()
	o.add_child(h)
	h.position = at
	h.rotation.y = rot_y
	var mat_w := 0.05
	var fw := 0.025
	var outer := size + Vector2(mat_w + fw, mat_w + fw) * 2.0
	var black := Mats.std(Color(0.05, 0.05, 0.05), 0.4)
	Geo.box(h, Vector3(0, 0, 0.004), Vector3(outer.x - fw * 2.0, outer.y - fw * 2.0, 0.008), Mats.std(Color(0.9, 0.89, 0.85), 0.85), false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (outer.x - fw) * 0.5, 0, 0.012), Vector3(fw, outer.y, 0.024), black, false)
		Geo.box(h, Vector3(0, sx * (outer.y - fw) * 0.5, 0.012), Vector3(outer.x, fw, 0.024), black, false)
	var q := QuadMesh.new()
	q.size = size
	var pic := MeshInstance3D.new()
	pic.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex)
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pic.material_override = m
	h.add_child(pic)
	pic.position = Vector3(0, 0, 0.0085)
	# a sheet of glass over it, catching the light a little
	var glass := Mats.std(Color(1, 1, 1, 0.06), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Geo.box(h, Vector3(0, 0, 0.016), Vector3(outer.x - fw * 2.0, outer.y - fw * 2.0, 0.002), glass, false)


## A plaster pilaster against a wall (0.6 wide, standing 0.3 proud of it) with a base and a plain capital under the
## beam; `along_z`: on a wall running along Z.
func _pilaster(o: Node3D, at: Vector3, along_z: bool) -> void:
	var wm := Mats.get_mat("plaster_wall")
	var s := Vector3(0.3, SEC_CEIL, 0.6) if along_z else Vector3(0.6, SEC_CEIL, 0.3)
	Geo.box(o, at + Vector3(0, SEC_CEIL * 0.5, 0), s, wm)
	var grow := Vector3(0.06, 0, 0.12) if along_z else Vector3(0.12, 0, 0.06)
	Geo.box(o, at + Vector3(0, SEC_CEIL - 0.45, 0), s * Vector3(1, 0, 1) + grow + Vector3(0, 0.1, 0), wm, false)
	Geo.box(o, at + Vector3(0, 0.06, 0), s * Vector3(1, 0, 1) + grow * 0.5 + Vector3(0, 0.12, 0), Mats.get_mat("metal_dark"), false)


## The plaster ceiling and its steel beams, the pipes along it, the fluorescent fittings hung on rods (the zone's
## panels with no housing of their own; one dead), the brass ceiling fans.
func _sec_ceiling(o: Node3D) -> void:
	var y := SEC_CEIL
	for r: Rect2 in sec_floor_rects():
		var c := r.get_center()
		Geo.box(o, Vector3(c.x, y + 0.15, c.y), Vector3(r.size.x, 0.3, r.size.y), Mats.get_mat("plaster_ceiling"), false)
	var west := SEC_LEG.position.x
	var north := SEC_BAR.position.y
	for zz: float in SEC_BEAMS_Z:
		var be := -12.4 if zz > SEC_CCTV.end.y else SEC_CCTV.end.x      # the one over the CCTV room ends at its east wall
		_ibeam(o, Vector3((west + be) * 0.5, y, zz), be - west, true)
	for x: float in SEC_BEAMS_X:
		_ibeam(o, Vector3(x, y, SEC_BAR.get_center().y), SEC_BAR.size.y, false)
	_ibeam(o, Vector3((west + SEC_CCTV.position.x) * 0.5, y - 0.005, -29.0), SEC_CCTV.position.x - west, true)
	# pipes along the south arm's east side, and along its west side on into the north arm along its north wall — that
	# run between the big windows' heads and the beams' bottom flanges, so it never crosses a window
	var pipe := Mats.std(Color(0.42, 0.4, 0.36), 0.45, 0.6)
	var conduit := Mats.std(Color(0.3, 0.32, 0.3), 0.5, 0.5)
	var py := (SEC_VIEW_Y + SEC_VIEW_SIZE.y * 0.5 + y - 0.3825) * 0.5
	_duct_run(o, Vector3(-13.05, y - 0.54, SEC_LEG.end.y - 0.3), Vector3(-13.05, y - 0.54, SEC_CCTV.end.y - 0.05), 0.065, pipe)
	_duct_run(o, Vector3(-13.3, y - 0.53, SEC_LEG.end.y - 0.3), Vector3(-13.3, y - 0.53, SEC_CCTV.end.y - 0.05), 0.04, conduit)
	_duct_run(o, Vector3(west + 0.6, py, SEC_LEG.end.y - 0.3), Vector3(west + 0.6, py, north + 0.6), 0.05, pipe)
	Geo.sphere(o, Vector3(west + 0.6, py, north + 0.6), 0.055, pipe)
	_duct_run(o, Vector3(west + 0.6, py, north + 0.6), Vector3(SEC_BAR.position.x + 0.3, py, north + 0.6), 0.05, pipe)
	# the fittings: [x, z, along x, energy (0 = dead)]
	var z: LightZone = zones.secoffice
	# (over each desk island, the south arm's and the north arm's: a row of three along it, one over each block —
	# user: "자리위에 조명도 추가해주고")
	for p: Array in [[-19.9, -16.4, false, 2.4], [-14.9, -16.4, false, 2.4],
			[-18.65, -19.6, true, 2.4], [-17.15, -19.6, true, 2.4], [-15.65, -19.6, true, 2.4], [-19.9, -23.75, false, 2.4], [-14.9, -23.75, false, 2.4],     # (-19.9 was dead; lit — user: "여기에 천장조명 하나 달자")
			[-19.1, -27.4, false, 2.0], [-19.1, -30.3, false, 1.8], [-24.975, -28.8, true, 2.0], [-23.475, -28.8, true, 2.0],
			[-21.725, -28.8, true, 2.0]]:        # (a little east of its desk: its chain clears the pipe overhead)
		_sec_fitting(o, z, Vector3(p[0], y - 0.72, p[1]), p[2], p[3])        # the tubes' level (the trough hangs 7 cm lower)
	z.add_hum(Vector3(-17.4, y - 0.9, -18.0), -24.0)
	z.add_hum(Vector3(-23.5, y - 0.9, -28.8), -26.0)
	for f: Vector2 in [Vector2(-17.4, -16.4), Vector2(-17.15, -21.0), Vector2(-18.6, -23.6), Vector2(-24.0, -27.0), Vector2(-26.1, -30.85)]:
		OfficeKit.ceiling_fan(o, Vector3(f.x, 0, f.y), y, true, 0.75)


## A steel I-beam under the ceiling, `length` along X (`along_x`) or Z, centred on `c` (its top at c.y).
func _ibeam(o: Node3D, c: Vector3, length: float, along_x: bool) -> void:
	var m := Mats.std(Color(0.22, 0.24, 0.22), 0.55, 0.45)
	var l := Vector3(length, 0, 0) if along_x else Vector3(0, 0, length)
	var w := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	Geo.box(o, c + Vector3(0, -0.2, 0), l + Vector3(0, 0.36, 0) + w * 0.016, m, false)
	for fy in [-0.03, -0.37]:
		Geo.box(o, c + Vector3(0, fy, 0), l + Vector3(0, 0.025, 0) + w * 0.19, m, false)


## One of the office's light fittings, its tubes at `at` (lengthwise along X or Z): the old industrial twin-tube kind
## (OfficeKit.tube_fitting — user, with photos of one: "조명 이런 형태로 바꿔줘"), its tubes and slots lit by the zone's
## panel material, or dead and grey. Its light keeps close to it (user, with a dark old-office reference: "어두운데 불이
## 켜져있고, 그 조명 주변만 밝은 연출"): a shadowed spot under the trough throws a warm pool on the floor and desks, a
## short area light lights what stands just round it, a small light inside the trough lights the reflector, an up-light
## the ceiling round the fitting (a soft glow in the haze), and only a faint fill reaches the dark between the pools.
func _sec_fitting(o: Node3D, z: LightZone, at: Vector3, along_x: bool, energy: float) -> void:
	var len := 1.3
	var ps := Vector2(len - 0.1, 0.12) if along_x else Vector2(0.12, len - 0.1)
	if energy <= 0.0:
		OfficeKit.tube_fitting(o, at, along_x, SEC_CEIL, Mats.std(Color(0.55, 0.56, 0.54), 0.3), Mats.get_mat("black"))
		return
	OfficeKit.tube_fitting(o, at, along_x, SEC_CEIL, z.panel_mat, z.panel_mat)
	var inner := Geo.omni(z, at + Vector3(0, 0.03, 0), SEC_LIGHT, energy * 0.35, 0.36)
	inner.light_specular = 0.5
	inner.light_volumetric_fog_energy = 0.0
	z.add_light(inner)
	if energy > 0.0:
		var area := Geo.area_light(z, at + Vector3(0, -0.03, 0), ps, SEC_LIGHT, energy * 0.6, 3.2)
		area.light_volumetric_fog_energy = 0.2
		z.add_light(area)
		var pool := Geo.spot(z, at + Vector3(0, -0.09, 0), at + Vector3(0, -0.09, 0), SEC_LIGHT, energy * 3.9, 6.0, 46.0, true)
		pool.rotation.x = -PI / 2
		pool.spot_attenuation = 1.3
		pool.spot_angle_attenuation = 1.9
		pool.shadow_blur = 2.2
		pool.light_specular = 0.45
		pool.light_volumetric_fog_energy = 0.5
		z.add_light(pool)
		var up := Geo.omni(z, at + Vector3(0, 0.35, 0), SEC_LIGHT, energy * 0.24, 2.4)
		up.light_specular = 0.0
		up.light_volumetric_fog_energy = 0.35
		z.add_light(up)
		var fill := Geo.omni(z, at + Vector3(0, -0.8, 0), SEC_SHADE, energy * 0.42, 6.5)      # cool, like the bounce in the dark (a little up — user: "아주 살짝만 밝았으면")
		fill.light_specular = 0.0
		fill.light_volumetric_fog_energy = 0.0
		z.add_light(fill)


## A straight horizontal run of pipe from `a` to `b` (along X or Z): flanged every couple of metres, hung on rods.
static func _duct_run(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	var l := d.length()
	var along_x := absf(d.x) > absf(d.z)
	var run := Geo.cyl(parent, (a + b) * 0.5, r, l, mat, false, 12)
	if along_x:
		run.rotation.z = PI / 2
	else:
		run.rotation.x = PI / 2
	var n := int(l / 2.2)
	for k in range(1, n + 1):
		var p := a + d * (float(k) / (n + 1))
		var f := Geo.cyl(parent, p, r + 0.015, 0.04, mat, false, 12)
		if along_x:
			f.rotation.z = PI / 2
		else:
			f.rotation.x = PI / 2
		Geo.cyl(parent, Vector3(p.x, (p.y + r + SEC_CEIL) * 0.5, p.z), 0.006, SEC_CEIL - p.y - r, Mats.get_mat("metal_dark"), false, 6)


## An office chair (the Tripo one, else a plain seat) facing +Z at rot 0.
func _sec_chair(o: Node3D, pos: Vector3, rot_y: float) -> void:
	if TripoProps.exists("security", "SEC_OfficeChair"):
		TripoProps.spawn(o, "security", "SEC_OfficeChair", pos, rot_y, true)
	else:
		Geo.box(o, pos + Vector3(0, 0.45, 0), Vector3(0.5, 0.08, 0.5), Mats.get_mat("seat"))


## A pair of steel desks pushed together face to face across `at` (along X), a low screen between them; returns the
## south desk's drawers when `live`.
func _sec_pair(o: Node3D, at: Vector3, south: Array, north_items: Array, seed_n: int, live := false) -> Array[Drawer]:
	var dk := Vector3(SEC_DESK_W, OfficeKit.DESK_H, 0.75)
	var dr := OfficeKit.desk(o, at + Vector3(0, 0, 0.375), 0.0, dk, -1.0, live, "steel")
	OfficeKit.desk(o, at + Vector3(0, 0, -0.375), PI, dk, 1.0, false, "steel")
	OfficeKit.dress(o, at + Vector3(0, 0, 0.375), 0.0, Vector2(dk.x, dk.z), south, seed_n)
	OfficeKit.dress(o, at + Vector3(0, 0, -0.375), PI, Vector2(dk.x, dk.z), north_items, seed_n + 1)
	return dr


## An island of pairs of desks pushed together along X round `c`, every desk the same size and the pairs evenly
## spaced (user: "책상마다 크기 간격 다 같게 하고 칸막이도 해줘"): `items` = [[south items, north items], …] per pair
## west to east, `seeds` and `live` per pair, `chairs` = per pair whether its [south, north] seat has a chair ("chair"
## or ""), the one office chair (_sec_chair) centred on its desk at the same distance. Partitions make every seat
## a cubby. Returns each pair's south-desk drawers.
func _sec_island(o: Node3D, c: Vector3, items: Array, seeds: Array, live: Array, chairs: Array) -> Array:
	var out := []
	var n := items.size()
	var x0 := c.x - SEC_DESK_W * n * 0.5
	var turn := [0.15, -0.2, 0.1, -0.1]
	for i in n:
		var at := Vector3(x0 + SEC_DESK_W * (i + 0.5), 0, c.z)
		out.append(_sec_pair(o, at, items[i][0], items[i][1], seeds[i], live[i]))
		for s in 2:
			var kind: String = chairs[i][s]
			var p := at + Vector3(0, 0, 1.15 if s == 0 else -1.15)
			var r: float = (PI + turn[i % 4]) if s == 0 else -turn[(i + 1) % 4]
			if kind != "":
				_sec_chair(o, p, r)
	_desk_screens(o, x0, x0 + SEC_DESK_W * n, c.z, n)
	return out


## Office partitions on a desk island from x0 to x1 along z zc (the pairs 1.5 m deep): a fabric screen down the
## middle between the facing desks and one across the island at every join and at both ends, in steel frames,
## standing 0.48 m over the desk tops.
func _desk_screens(o: Node3D, x0: float, x1: float, zc: float, n: int) -> void:
	var fabric := Mats.std(Color(0.34, 0.36, 0.35), 0.95)
	var frame := Mats.std(Color(0.2, 0.21, 0.21), 0.5, 0.5)
	var top := OfficeKit.DESK_H
	var h := 0.48
	var t := 0.04
	Geo.box(o, Vector3((x0 + x1) * 0.5, top + h * 0.5, zc), Vector3(x1 - x0, h, t), fabric, false)
	Geo.box(o, Vector3((x0 + x1) * 0.5, top + h + 0.012, zc), Vector3(x1 - x0 + 0.02, 0.024, t + 0.014), frame, false)
	for k in n + 1:
		var x := x0 + (x1 - x0) * k / n
		if k == 0:
			x -= t * 0.5 + 0.004
		elif k == n:
			x += t * 0.5 + 0.004
		Geo.box(o, Vector3(x, top + h * 0.5, zc), Vector3(t, h, 1.5), fabric, false)
		Geo.box(o, Vector3(x, top + h + 0.012, zc), Vector3(t + 0.014, 0.024, 1.52), frame, false)
		for sz in [-1.0, 1.0]:
			Geo.box(o, Vector3(x, top + h * 0.5, zc + sz * 0.75), Vector3(t + 0.014, h, 0.024), frame, false)


## The south end, where you start (cut down to just before the desks — user: "여기 책상없는 공간 잘라. 줄여"): along the
## south wall the night-duty room's door, the CRT desk (a), a filing cabinet with a fan on it, a plant, the water
## cooler and the guard's small CCTV stack, the key box and the extinguisher by the passage door; posters, the
## calendar. (Every chair in the office is the one office chair, at a desk — user: "의자 디자인 하나로 통일하고 책상 앞에만")
func _sec_south(o: Node3D, sets: Dictionary) -> void:
	var south := SEC_LEG.end.y - 0.15            # the south wall's room face
	var beige := Color(0.62, 0.58, 0.46)
	sets["a"] = OfficeKit.desk(o, Vector3(-19.75, 0, south - 0.375), PI, Vector3(SEC_DESK_W, OfficeKit.DESK_H, 0.75), 1.0, true, "steel")
	OfficeKit.dress(o, Vector3(-19.75, 0, south - 0.375), PI, Vector2(SEC_DESK_W, 0.75), [["blotter", -0.1, 0.15],
			["pc", 0.35, 0.0], ["phone_beige", -0.6, -0.3, 0.3], ["folders", -0.7, 0.35, 0.2], ["trays", 0.85, -0.35],
			["pens", -0.25, -0.65], ["mug", 0.85, 0.55], ["lamp", -0.3, -0.5, 0.4]], 3)
	_sec_chair(o, Vector3(-19.45, 0, south - 0.9), 0.15)          # pushed in, clear of the way in from the west door
	OfficeKit.filing_cabinet(o, Vector3(-18.6, 0, south - 0.31), PI, 4, beige, false)
	OfficeKit.fan(o, Vector3(-18.6, 1.32, south - 0.35), PI + 0.5, false)
	OfficeKit.mug(o, Vector3(-18.45, 1.32, south - 0.55))
	OfficeKit.wall_calendar(o, Vector3(-16.3, 1.75, south + 0.002), PI)
	OfficeKit.potted_plant(o, Vector3(-16.4, 0, south - 0.18), 1.0, 5)
	OfficeKit.water_cooler(o, Vector3(-15.75, 0, south - 0.17), PI)
	# the guard's small CCTV stack on a cabinet against the south wall, a notice board over it
	OfficeKit.low_cabinet(o, Vector3(-14.4, 0, south - 0.21), PI, Vector3(1.3, 0.85, 0.42))
	OfficeKit.crt_bank(o, Vector3(-14.4, 0, south), PI, 1.2, ["crt", "snow", "crt", "crt"], 9, 0.91, 1.83)
	OfficeKit.notice_board(o, Vector3(-14.4, 2.4, south), PI, Vector2(1.1, 0.7), 11)
	# by the passage door (kept clear of its leaf): the key box, the extinguisher; the no-smoking sign over the door
	OfficeKit.key_box(o, Vector3(-13.15, 1.6, south), PI)
	Geo.cyl(o, Vector3(-12.95, 0.3, south - 0.12), 0.075, 0.5, Mats.std(Color(0.75, 0.08, 0.06), 0.35, 0.2))
	Geo.box(o, Vector3(-12.95, 0.6, south - 0.12), Vector3(0.05, 0.08, 0.05), Mats.get_mat("metal_dark"), false)
	var ns := Node3D.new()
	o.add_child(ns)
	ns.position = Vector3(-12.553, 2.48, -16.0)
	ns.rotation.y = -PI / 2
	Geo.box(ns, Vector3.ZERO, Vector3(0.62, 0.15, 0.01), Mats.std(Color(0.92, 0.91, 0.86), 0.6), false)
	Geo.fit(Geo.label(ns, "금연  NO SMOKING", Vector3(0, 0, 0.006), 0.0, 40, Color(0.7, 0.08, 0.06), 0.0026, false, "print"), 0.54, 0.11)


## The desks: two pairs of steel desks across the south arm (the guard's, c, nearest the doors), the reception counter
## by the west wall with its desk behind, and in the north arm two more pairs and a book trolley.
func _sec_desks(o: Node3D, sets: Dictionary) -> void:
	# the south arm's island of three pairs pushed together (user: "책상 하나 더 추가해서 3개 연결해서 붙여줘"), the
	# guard's (c, the key card in c3) at its west end
	sets["c"] = _sec_island(o, Vector3(-17.15, 0, -19.6), [
			[[_ISLAND_PC_L, ["phone_beige", 0.45, 0.45, -0.2], ["folders", 0.55, -0.35, 0.1], ["pens", 0.85, 0.3], ["mug", 0.88, -0.1]],
			[_ISLAND_PC_R, ["typewriter", -0.6, 0.0]]],
			[[_ISLAND_PC_L, ["lamp", 0.75, -0.45, 0.3], ["pile", 0.4, 0.45, 0.15], ["mug", 0.9, 0.5]],
			[_ISLAND_PC_R, ["folders", -0.55, -0.35, -0.15], ["phone_beige", -0.78, 0.4, 0.2]]],
			[[_ISLAND_PC_R, ["folders", -0.5, -0.35, 0.15], ["folders", -0.5, -0.35, -0.1, 0.18], ["ashtray", -0.85, 0.45],
				["pile", -0.35, 0.45, -0.2]],
			[_ISLAND_PC_L, ["photos", 0.5, 0.4], ["lamp", 0.75, -0.5, -0.4]]]],
			[9, 17, 13], [true, false, false], [["chair", "chair"], ["chair", "chair"], ["chair", "chair"]])[0]
	# the reception counter, glazed, across the room (user: "칸막이 가로로 돌려줘"): it runs west from the CCTV room's
	# corner, its front flush with that room's south face, so the two make one front line facing the doors; the way
	# on into the north arm is past its west end. The clerk's desk is pushed against its back. 3 m: three panels, five
	# glazed bays (one of each shorter than at first — user: "여기서 한칸 짧게해줘").
	var cz := SEC_CCTV.end.y - 0.25
	var cx := SEC_CCTV.position.x - 1.5
	OfficeKit.counter_screen(o, Vector3(cx, 0, cz), 0.0, 3.0, 5, 3)
	var dz := cz - 0.25 - 0.375
	OfficeKit.desk(o, Vector3(cx + 0.4, 0, dz), PI, Vector3(SEC_DESK_W, OfficeKit.DESK_H, 0.75), 1.0, false, "steel")
	OfficeKit.dress(o, Vector3(cx + 0.4, 0, dz), PI, Vector2(SEC_DESK_W, 0.75), [["pc_form", 0.3, 0.0],
			["folders", -0.6, -0.3], ["phone", -0.2, 0.45, 0.2], ["radio", 0.9, -0.2]], 27)
	_sec_chair(o, Vector3(cx + 0.55, 0, dz - 0.8), 0.25)
	# the north arm: a book trolley, two pairs of desks (the whiteboard on a stand that stood here was removed — user:
	# "이거 없애")
	OfficeKit.trolley(o, Vector3(-19.0, 0, -29.6), 1.4, 5)
	# the north arm's island of three (user: "여기도 … 3개 연결해서 붙여줘"), in the elbow by the CCTV room
	_sec_island(o, Vector3(-23.475, 0, -28.8), [
			[[["pc_off", -0.4, 0.04], ["folders", 0.55, -0.35], ["ashtray", 0.85, 0.45]],
			[_ISLAND_PC_R, ["folders", -0.5, -0.35, 0.3], ["phone_beige", -0.75, 0.35]]],
			[[_ISLAND_PC_R, ["folders", -0.5, -0.3, -0.15], ["pile", -0.6, 0.45, 0.2], ["mug", -0.25, 0.5]],
			[["pc_form", -0.4, 0.04], ["lamp", 0.75, -0.45, -0.3], ["photos", 0.4, 0.4]]],
			[[_ISLAND_PC_L, ["folders", 0.5, -0.3, 0.2], ["pile", 0.55, 0.45], ["mug", 0.88, 0.5]],
			[_ISLAND_PC_R, ["typewriter", -0.55, 0.0]]]],
			[33, 35, 31], [false, false, false], [["chair", "chair"], ["chair", "chair"], ["chair", "chair"]])


## Along the walls: the windows between the pilasters with cabinets under them (the lateral cabinets, l, and the
## filing cabinet f), lockers, bookshelves, document and glass cabinets (no posters — user: "벽에 붙은 수배지랑 바닥에 굴러다니는
## 종이 치워줘").
func _sec_walls(o: Node3D, sets: Dictionary) -> void:
	var west := SEC_LEG.position.x + 0.15
	var east := -12.565
	var north := SEC_BAR.position.y + 0.15
	var south_bar := SEC_LEG.position.y - 0.15
	var beige := Color(0.62, 0.58, 0.46)
	var olive := Color(0.34, 0.36, 0.28)
	var grey := Color(0.46, 0.47, 0.45)
	# the south arm's west wall: two big windows onto the maze outside (sec_view), the lateral cabinets (l) and a low
	# cabinet under the first
	for i in 2:
		sec_view_panes.append(OfficeKit.steel_window(o, Vector3(west + 0.005, SEC_VIEW_Y, SEC_VIEW_W[i]), PI / 2, SEC_VIEW_SIZE, 4, 3, 61 + i, true, true, i))
	var lat: Array = []
	lat.append_array(OfficeKit.lateral_cabinet(o, Vector3(west + 0.23, 0, -18.65), PI / 2))
	lat.append_array(OfficeKit.lateral_cabinet(o, Vector3(west + 0.23, 0, -19.6), PI / 2, 0.65))
	sets["l"] = lat
	OfficeKit.binders(o, Vector3(west + 0.23, 0.74, -19.0), PI / 2, 6, 31)
	OfficeKit.trays(o, Vector3(west + 0.25, 0.74, -19.6), PI / 2, 2)
	# the radio chargers on a low cabinet under the window
	OfficeKit.low_cabinet(o, Vector3(west + 0.21, 0, -20.75), PI / 2, Vector3(1.0, 0.85, 0.42))
	Geo.box(o, Vector3(west + 0.19, 1.0, -20.75), Vector3(0.34, 0.04, 0.8), Mats.get_mat("steel_frame"), false)
	for i in 3:
		var rz := -21.0 + i * 0.25
		Geo.box(o, Vector3(west + 0.17, 1.06, rz), Vector3(0.14, 0.08, 0.16), Mats.get_mat("plastic_dark"), false)
		Geo.box(o, Vector3(west + 0.17, 1.2, rz), Vector3(0.035, 0.2, 0.06), Mats.get_mat("plastic_grey"), false)
		Geo.cyl(o, Vector3(west + 0.17, 1.38, rz + 0.02), 0.006, 0.16, Mats.get_mat("plastic_dark"))
		Geo.box(o, Vector3(west + 0.097, 1.06, rz + 0.05), Vector3(0.004, 0.015, 0.015), Mats.get_mat("lamp_green"), false)
	# the south arm's east wall: a window with filing cabinets under it (f), then lockers, a bookshelf, a cabinet
	OfficeKit.steel_window(o, Vector3(east - 0.005, 2.1, -19.7), -PI / 2, Vector2(3.2, 1.2), 4, 2, 63, false, false, 2)
	sets["f"] = OfficeKit.filing_cabinet(o, Vector3(east - 0.31, 0, -18.35), -PI / 2, 4, olive)
	var tints := [beige, grey, beige, olive]
	for i in 4:
		OfficeKit.filing_cabinet(o, Vector3(east - 0.31, 0, -18.85 - i * 0.5), -PI / 2, 4, tints[i], false)
	OfficeKit.folders(o, Vector3(east - 0.3, 1.32, -19.3), -0.1, 7, RandomNumberGenerator.new())
	OfficeKit.fan(o, Vector3(east - 0.32, 1.32, -20.2), -PI / 2 - 0.5, false)
	# the north arm's north wall: a window over a run of filing cabinets; a bookshelf, then the changing lockers
	# (the arm's west end came in — user: "여기 공간 너무 빈다. 줄여줘" — and took the second window and run)
	OfficeKit.steel_window(o, Vector3(-24.4, 2.1, north + 0.005), 0.0, Vector2(3.0, 1.2), 4, 2, 64, false, false, 2)
	var run := [beige, olive, grey, beige, beige]
	for i in 5:
		OfficeKit.filing_cabinet(o, Vector3(-25.55 + i * 0.5, 0, north + 0.31), 0.0, 4, run[i], false)
	OfficeKit.carton(o, Vector3(-25.45, 1.32, north + 0.3), Vector3(0.42, 0.28, 0.38), 0.2)
	OfficeKit.folders(o, Vector3(-24.8, 1.32, north + 0.3), 0.15, 10, RandomNumberGenerator.new())
	OfficeKit.radio_base(o, Vector3(-23.9, 1.32, north + 0.32), 0.0)
	OfficeKit.bookshelf(o, Vector3(-21.6, 0, north + 0.19), 0.0, Vector3(1.0, 2.0, 0.38), 14)
	# from the bookshelf to the coat rack, the staff's changing lockers (user: "액자 치우고 저 보관소도 치우고 옷 갈아
	# 입을 수 있는 사물함으로 채워줘"): seven, 01–07; 04 in the middle (its card 신규) opens, the uniform is in it
	sec_locker = OfficeKit.lockers(o, Vector3(-19.6, 0, north + 0.26), 0.0, 7,
		["김동현", "", "이재석", "신규", "최민호", "", "박정우"], -1, 1, 3, 3)      # 04's card red (user: "이름표가 빨간색")
	sec_locker["open"] = false
	var ld: Node3D = sec_locker.door
	var luse := Interactable.create(ld, Vector3(float(sec_locker.door_w) * 0.5, 1.0, 0.05), Vector3(float(sec_locker.door_w), 1.6, 0.1),
		"사물함 열기", func(): open_locker(not sec_locker.open))
	luse.press_sound = ""
	sec_locker["use"] = luse
	# the north arm's south wall: a big window onto the maze outside (sec_view — user: "이쪽 벽에 큰 창문들 달아줘
	# 밖에 보이게"; one since the arm's west end came in) with a low cabinet under it; a coat rack in the corner
	var wx_bar := SEC_VIEW_N
	for i in wx_bar.size():
		sec_view_panes.append(OfficeKit.steel_window(o, Vector3(wx_bar[i], SEC_VIEW_Y, south_bar - 0.005), PI, SEC_VIEW_SIZE, 4, 3, 67 + i, true, true, 0))
		OfficeKit.low_cabinet(o, Vector3(wx_bar[i], 0, south_bar - 0.21), PI, Vector3(1.5, 0.85, 0.42))
	OfficeKit.folders(o, Vector3(-24.0, 0.85, south_bar - 0.22), 0.2, 8, RandomNumberGenerator.new())
	OfficeKit.potted_plant(o, Vector3(-24.9, 0.85, south_bar - 0.2), 0.6, 8)
	OfficeKit.coat_rack(o, Vector3(-17.65, 0, -30.85), 0.9)
	# the west end wall: lockers, a document cabinet and a bookshelf
	var wend := SEC_BAR.position.x + 0.15
	OfficeKit.lockers(o, Vector3(wend + 0.25, 0, -27.25), PI / 2, 4, ["", "정태호", "", "임수빈"], 2, 9)
	OfficeKit.steel_cabinet(o, Vector3(wend + 0.225, 0, -28.8), PI / 2, Vector3(1.1, 1.8, 0.45), ["보안문서 85–90", "출입 기록", "근무 일지"])
	OfficeKit.bookshelf(o, Vector3(wend + 0.19, 0, -29.9), PI / 2, Vector3(1.0, 2.0, 0.38), 15)


## The CCTV room (CCTV 관제실, SEC_CCTV) against the office's south face and west face, which are as they were when it
## filled the whole corner block (x -17.2..-12.4, z -34..-22.6): plaster walls to the ceiling, a counter window in the
## south face with the clock and the room's name over it and a television on a bracket at its corner, a big window and
## the doorway in the west face. The room itself is a third of that block (user: "cctv관제실 사이즈 3분의1로", "밖에서
## 줄여야해, 사무실 크기 그대로"): its north and east walls stand in from the old outer walls and the rest of the block
## is outside the building (no floor or ceiling there, sec_floor_rects). Inside, under the fitting over the counter
## window: an L of console along its north and east walls — built-in CRTs, control panels, open under the worktop where
## the operators sit — under banks of CRT monitors (cameras, static, dead ones), a rack of VCRs, chairs, cartons,
## cables, the screens' green glow.
func _cctv_room(o: Node3D) -> void:
	var wm := Mats.get_mat("plaster_wall")
	var x0 := SEC_CCTV.position.x                   # its west face (outside)
	var z1 := SEC_CCTV.end.y                        # its south face (outside)
	var t := 0.2
	var y := SEC_CEIL
	# the south face: the counter window (wc ± 0.9, y 1.0..2.1)
	var sz := z1 - t * 0.5
	var wc := x0 + 2.2
	for seg in [[x0, wc - 0.9], [wc + 0.9, -12.4]]:
		Geo.box(o, Vector3((seg[0] + seg[1]) * 0.5, y * 0.5, sz), Vector3(seg[1] - seg[0], y, t), wm)
	Geo.box(o, Vector3(wc, 0.5, sz), Vector3(1.8, 1.0, t), wm)
	Geo.box(o, Vector3(wc, (2.1 + y) * 0.5, sz), Vector3(1.8, y - 2.1, t), wm)
	Geo.box(o, Vector3(wc, 1.02, sz), Vector3(2.0, 0.05, 0.62), Mats.std(Color(0.32, 0.27, 0.2), 0.45), false)
	var plate := Node3D.new()
	o.add_child(plate)
	plate.position = Vector3(wc, 2.36, z1 + 0.008)
	Geo.box(plate, Vector3.ZERO, Vector3(1.3, 0.22, 0.012), Mats.std(Color(0.93, 0.92, 0.87), 0.6), false)
	Geo.fit(Geo.label(plate, "CCTV 관제실 · 접수", Vector3(0, 0, 0.007), 0.0, 48, Color(0.12, 0.14, 0.3), 0.003, false, "print"), 1.16, 0.16)
	# (no clock over it — user: "시계도 없었으면 좋겠어")
	OfficeKit.tv_bracket(o, Vector3(x0 + 0.3, 2.7, z1 + 0.012), -PI / 4 + 0.2, 7.0)
	# the west face, the office's wall all the way up to the north wall as before: the window z -27.0..-23.6 (y
	# 1.0..2.45) onto the clerk's desk; the doorway just north of it (past the room's north wall the wall is plain, a
	# notice board and posters on it)
	var wx := x0 + t * 0.5
	var wz := -25.3
	var dz := -27.75
	for seg in [[SEC_BAR.position.y, dz - 0.5], [dz + 0.5, wz - 1.7], [wz + 1.7, z1]]:
		Geo.box(o, Vector3(wx, y * 0.5, (seg[0] + seg[1]) * 0.5), Vector3(t, y, seg[1] - seg[0]), wm)
	Geo.box(o, Vector3(wx, (2.15 + y) * 0.5, dz), Vector3(t, y - 2.15, 1.0), wm)
	Geo.box(o, Vector3(wx, 0.5, wz), Vector3(t, 1.0, 3.4), wm)
	Geo.box(o, Vector3(wx, (2.45 + y) * 0.5, wz), Vector3(t, y - 2.45, 3.4), wm)
	OfficeKit.steel_window(o, Vector3(x0 - 0.002, 1.725, wz), -PI / 2, Vector2(3.4, 1.45), 4, 2, 66, true, false, 2)
	for sx in [-1.0, 1.0]:
		Geo.box(o, Vector3(wx, 1.07, dz + sx * 0.52), Vector3(t + 0.04, 2.14, 0.05), OfficeKit.frame_steel(), false)
	Geo.box(o, Vector3(wx, 2.16, dz), Vector3(t + 0.04, 0.05, 1.09), OfficeKit.frame_steel(), false)
	OfficeKit.tag(o, Vector3(x0 - 0.002, 2.4, dz), -PI / 2, "관계자 외 출입금지", Vector2(0.5, 0.1), Color(0.95, 0.85, 0.8))
	OfficeKit.notice_board(o, Vector3(x0 - 0.012, 1.7, -29.4), -PI / 2, Vector2(1.3, 0.8), 37)
	# its own north and east walls: past them is outside the building
	var x1 := SEC_CCTV.end.x
	var z0 := SEC_CCTV.position.y
	Geo.box(o, Vector3((x0 + x1) * 0.5, y * 0.5, z0 + t * 0.5), Vector3(x1 - x0, y, t), wm)
	Geo.box(o, Vector3(x1 - t * 0.5, y * 0.5, (z0 + z1) * 0.5), Vector3(t, y, z1 - z0), wm)
	# inside (3 x 5.5 m), under the fitting over the counter window: a console along the north wall
	# clear of the doorway and two along the east wall, the monitor banks over them, the VCRs, the receptionist's desk
	# under the counter window
	var ix := x0 + t                                # the west wall's inner face
	var e := x1 - t                                 # the east wall's
	var n := z0 + t                                 # the north wall's
	OfficeKit.console(o, Vector3(ix + 1.975, 0, n), 0.0, 1.95, ["crt", "panel", "crt"], 49, true)
	OfficeKit.crt_bank(o, Vector3((ix + 1.0 + e - 0.46) * 0.5, 0, n), 0.0, (e - 0.46) - (ix + 1.0),
			["crt", "snow", "off", "crt", "crt", "snow"], 4, 1.55, 2.6)
	OfficeKit.console(o, Vector3(e, 0, n + 1.48), -PI / 2, 1.4, ["panel", "snow", "crt"], 41)
	OfficeKit.console(o, Vector3(e, 0, n + 2.78), -PI / 2, 1.2, ["crt", "crt"], 42, true)
	OfficeKit.crt_bank(o, Vector3(e, 0, n + 1.69), -PI / 2, 3.38,
			["crt", "snow", "crt", "off", "crt", "crt", "snow", "crt", "off", "crt", "crt", "crt", "snow", "crt"], 3, 1.55, 2.6)
	OfficeKit.vcr_rack(o, Vector3(e - 0.225, 0, -24.4), -PI / 2, 5)
	OfficeKit.desk(o, Vector3(wc, 0, z1 - t - 0.375), PI, Vector3(SEC_DESK_W, OfficeKit.DESK_H, 0.75), 1.0, false, "steel")
	OfficeKit.dress(o, Vector3(wc, 0, z1 - t - 0.375), PI, Vector2(SEC_DESK_W, 0.75), [["pc_form", 0.4, 0.0],
			["folders", -0.55, -0.3], ["phone_beige", -0.15, 0.4, 0.3], ["mug", -0.85, 0.5]], 51)
	_sec_chair(o, Vector3(wc, 0, z1 - t - 1.25), 0.0)
	OfficeKit.filing_cabinet(o, Vector3(ix + 0.31, 0, z1 - t - 0.31), PI, 4, Color(0.62, 0.58, 0.46), false)
	_sec_chair(o, Vector3(ix + 1.9, 0, n + 1.35), PI + 0.2)
	_sec_chair(o, Vector3(ix + 1.75, 0, n + 2.8), PI / 2 + 0.2)
	OfficeKit.carton(o, Vector3(ix + 0.28, 0, -25.9), Vector3(0.5, 0.4, 0.4), 0.1)
	OfficeKit.carton(o, Vector3(ix + 0.31, 0.4, -25.93), Vector3(0.4, 0.28, 0.34), -0.2)
	Geo.blocker(o, Vector3(ix + 0.28, 0.34, -25.9), Vector3(0.55, 0.68, 0.45))
	var cable := Mats.std(Color(0.05, 0.05, 0.055), 0.6)
	for cb in [[Vector3(ix + 1.4, 0.006, -27.0), 0.9, 0.5], [Vector3(ix + 2.3, 0.006, -25.9), 0.8, -0.35]]:
		Geo.box(o, cb[0], Vector3(cb[1], 0.012, 0.012), cable, false, cb[2])
	var glow := Geo.omni(o, Vector3(ix + 1.7, 1.7, -26.0), Color(0.5, 0.82, 0.74), 0.8, 4.0)
	glow.light_specular = 0.3
	glow.light_volumetric_fog_energy = 0.2


## The security office's door: a steel leaf with a narrow wired-glass light, a push plate on the passage side and a
## pull handle in the room, hung on the south jamb; it opens into the room. Shut and dead to [E] until the story
## gives it a prompt and a callback.
func _security_door() -> void:
	# a panel door in the passage's wall, seen from the passage only: its frame and leaf stay inside the wall (the
	# office's side is lined over it), its [E] on the passage side; turned so it would open toward the office
	sec_passage = OfficeKit.door(sec_root, Vector3(-12.37, 0.0, -16.0), PI, "", 0.24)   # its frame 2 cm proud on the passage side
	var u := sec_passage.use as Interactable
	u.position.x = -0.2                                  # (local -X is the passage)
	((u.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = Vector3(0.3, 2.0, 0.9)
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
	var fill := Geo.spot(wreck, Vector3(WRECK_AT.x + 8.0, 21.0, HALL_S + 1.5), Vector3(WRECK_AT.x + 8.0, 2.0, HALL_S + 16.0), Color(0.6, 0.7, 0.92), 7.0, 40.0, 40.0)
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
	fids.position = Vector3(-13.0, MEZZ_Y + 3.6, -2.07)     # between units n1 and n2 (Shops)
	fids.build(4.4, 2.05, true)
	fids.control_box.position = Vector3(-15.45, MEZZ_Y + 1.45, -2.23) - fids.position
	facilities["fids"] = fids
	# arrivals board hung from the ceiling over the 2F's edge west of the escalators, turned to the atrium: seen from
	# the lounge floor and from the 2F, and not in the way of the view from the staff doors
	arrivals = FidsBoard.new()
	arrivals.id = "fids_arr"
	arrivals.zone = "hall"
	add_child(arrivals)
	arrivals.position = Vector3(ATRIUM.position.x + 0.45, 7.6, 7.0)     # over the west gallery's edge, out of the view from the staff doors
	arrivals.rotation.y = deg_to_rad(70.0)
	arrivals.build(4.4, 2.05, false)
	arrivals.screen.title = "도착  ARRIVALS"
	arrivals.screen.icon = load("res://assets/textures/level/icon_arrivals.png")
	var rod := HALL_H - arrivals.position.y - 1.175
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
	for p in [Vector3(-17, 2.4, HALL_S - 1.5), Vector3(-2, 3, 6), Vector3(10, 3, 4), Vector3(5, 3, 20), Vector3(-24, 3, -50), Vector3(-42, 2.5, -50)]:
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
		"hall": [Vector3((HALL_E - 20.0) * 0.5, HALL_ROOF * 0.5, (HALL_S - 2.5) * 0.5), Vector3(HALL_E + 20.0, HALL_ROOF, HALL_S + 2.5)],
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
	_update_sec_view()
	if air_haze:
		var hz: LightZone = zones.airhall
		air_haze.emission = AirHall.HAZE_GLOW * (hz.panel_mat.emission_energy_multiplier / hz.panel_energy)
	for zn in _probes:
		var z: LightZone = zones[zn]
		var want := 0.7 if z.is_on and z.powered else 0.0
		var p: ReflectionProbe = _probes[zn]
		if p.is_inside_tree():
			p.intensity = move_toward(p.intensity, want, delta * 2.0)


## The security office's big windows both ways. From the office (sec_view_panes) a PortalView renders the maze round
## it as if your eye stood at the same spot in the maze (ServiceHall.ORIGIN off: the maze is laid out in the office's
## own coordinates), at half resolution — live only while your eye is in the office. From the maze (its window panes)
## sec_inview renders the office from your spot taken back by the same offset, seeing nothing but the office's own
## layer (VIS_OFFICE: its walls, holed for the windows, hide everything round it) — live only while your eye is in
## the maze where those windows can be seen. Either is plain black when not live. Made the first frame there is a
## camera to look from.
func _update_sec_view() -> void:
	if sec_view_panes.is_empty() or service_hall == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if sec_view == null:
		var env: Environment = null
		for we: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			env = we.environment
			break
		var src := Transform3D(Basis(), Vector3(SEC_LEG.position.x, 0, SEC_LEG.position.y))
		var dst := Transform3D(Basis(), src.origin + ServiceHall.ORIGIN)
		sec_view = PortalView.create(self, src, dst, cam, env)
		sec_view.res_scale = 0.5
		var m := sec_view.surface_material()
		for p in sec_view_panes:
			p.material_override = m
		sec_inview = PortalView.create(self, dst, src, cam, env)
		sec_inview.res_scale = 0.6
		sec_inview.set_cull_mask(VIS_OFFICE)
		sec_inview.set_volumetric_fog(false)           # the maze's haze stays in the maze, the aircraft hall's out of it
		var mi := sec_inview.surface_material()
		for p in service_hall.office_panes:
			p.material_override = mi
	sec_view.eye = cam
	sec_inview.eye = cam
	var q := cam.global_position
	var inside := q.y > -1.0 and q.y < SEC_CEIL + 1.0 and zone_at(q) == "secoffice"
	if inside != sec_view.is_processing():
		sec_view.set_active(inside)
	var looking_in := service_hall.sees_office(q)
	if looking_in != sec_inview.is_processing():
		sec_inview.set_active(looking_in)


## Reverb zones: every 3D sound (doors, machines, the colleague's voice) sends into the hall or room reverb of
## the zone it is played in, so the big halls ring and the small rooms stay dry. Rooms inside a hall win (priority).
func _build_reverb() -> void:
	var defs := {
		"hall": ["RevHall", 0.32, HALL_H], "security": ["RevMid", 0.28, SEC_H], "corridor": ["RevLong", 0.32, COR_H],
		"baggage": ["RevMid", 0.28, BAG_H], "gates": ["RevLong", 0.3, 5.5],
		"office": ["RevRoom", 0.22, 3.2], "secoffice": ["RevMid", 0.24, SEC_CEIL], "storage": ["RevRoom", 0.24, 3.2], "maint": ["RevRoom", 0.26, 3.0],
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
