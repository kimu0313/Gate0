# GATE 0 — PA announcement voice generator (Windows SAPI TTS).
# Usage (from project root):  powershell -ExecutionPolicy Bypass -File tools\gen_voice.ps1 [-Only <id prefix>]
#   (the file is UTF-8 without BOM; under Windows PowerShell 5.1 run it as
#    powershell -Command "& ([scriptblock]::Create((Get-Content -Raw -Encoding UTF8 tools\gen_voice.ps1))) -Only pa_")
# Output: assets\audio\voice\*.wav  (22.05 kHz 16-bit mono)
# Godot routes these through the "PA" audio bus (reverb + band-pass) so the raw TTS reads as a terminal PA system.
param([string]$Only = "")

Add-Type -AssemblyName System.Speech

# run from the project root when invoked as a script block ($PSScriptRoot is empty then)
$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$outDir = Join-Path $root "assets\audio\voice"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$KO = "Microsoft Heami Desktop"
$EN = "Microsoft Zira Desktop"

# id = @(voice, rate(-10..10), text)
$lines = [ordered]@{
	# 표준 테스트 방송 (정상 기준) — 근무 수칙 p.4 에 문안이 실려 있다.
	"pa_test_normal_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_normal_en"        = @($EN, -1, "Attention please. Facility inspection is currently in progress in this terminal. Authorized personnel only. Thank you.")
	# 이상 변형: 단어 하나만 바뀐다.
	"pa_test_anom_a_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 탑승 수속이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_anom_b_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 승객 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_anom_c_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 기다리고 있겠습니다.")
	# 이상 변형: 표준 문안 뒤에 문장이 하나 더 붙는다 (수칙 p.4 ③ — 끝날 때까지 움직이지 말 것)
	"pa_test_anom_d_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다. 지금 움직이시는 분, 거기 계신 거 다 보입니다.")
	# 03:00 정기 방송 (수칙 p.9 ③) — 이어서 단어 하나가 다른 문안(pa_test_anom_b_ko)이 나온다
	"pa_regular_intro_ko"      = @($KO, -2, "현재 시각, 새벽 세 시입니다. 터미널 정기 안내 방송을 시작합니다.")
	# 03:00 정기 방송 첫 문장 — 날마다 날짜와 시각을 알린다 (DAY 2는 1987년 11월 3일 23:40, DAY 4는 23:40 · 서해비행장)
	"pa_regular_intro_d1"      = @($KO, -2, "시월 십구일, 현재 시각 새벽 세 시입니다. 터미널 정기 안내 방송을 시작합니다.")
	"pa_regular_intro_d2"      = @($KO, -2, "천구백팔십칠년 십일월 삼일, 현재 시각 밤 열한 시 사십 분입니다. 터미널 정기 안내 방송을 시작합니다.")
	"pa_regular_intro_d3"      = @($KO, -2, "시월 이십일일, 현재 시각 새벽 세 시입니다. 터미널 정기 안내 방송을 시작합니다.")
	"pa_regular_intro_d4"      = @($KO, -2, "시월 이십이일, 현재 시각 밤 열한 시 사십 분입니다. 서해비행장 정기 안내 방송을 시작합니다.")
	"pa_regular_intro_d5"      = @($KO, -2, "시월 이십삼일, 현재 시각 새벽 세 시입니다. 터미널 정기 안내 방송을 시작합니다.")
	# 엔딩 A (탑승) — 좌석에 앉으면
	"pa_boarded_ko"            = @($KO, -3, "탑승이 완료되었습니다.")
	# 0편 관련
	"pa_flight0_move_ko"       = @($KO, -2, "영편 승객께서는 출국장으로 이동해 주시기 바랍니다.")
	"pa_flight0_move_en"       = @($EN, -2, "Passengers of flight zero, please proceed to the departure area.")
	"pa_flight0_checkin_ko"    = @($KO, -2, "영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다.")
	"pa_last_baggage_ko"       = @($KO, -2, "마지막 수하물이 도착했습니다.")
	"pa_one_passenger_ko"      = @($KO, -2, "승객 한 분이 탑승 수속을 마쳤습니다.")
	"pa_passenger_confirmed_ko"= @($KO, -3, "승객 확인되었습니다.")
	"pa_boarding_complete_ko"  = @($KO, -3, "탑승 수속이 완료되었습니다. 안녕히 가십시오.")
	"pa_final_call_ko"         = @($KO, -2, "영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다.")
	"pa_final_call_en"         = @($EN, -2, "This is the final boarding call for flight zero. Remaining passenger, please proceed to gate zero immediately.")
	"pa_call_generic_ko"       = @($KO, -3, "승객님. 승객님. 영번 게이트로 오시기 바랍니다. 기다리고 있습니다.")
	"pa_3am_ko"                = @($KO, -2, "현재 시각, 새벽 세 시입니다. 영편 탑승을 마감합니다.")
	"pa_destination_home_ko"   = @($KO, -3, "목적지는, 집입니다.")
	# 낮 / 엔딩
	"pa_welcome_ko"            = @($KO, -1, "서해국제공항에 오신 것을 환영합니다. 즐거운 여행 되십시오.")
	"pa_welcome_en"            = @($EN, -1, "Welcome to Seohae International Airport. Have a pleasant journey.")
	"pa_arrived_ko"            = @($KO, -3, "도착했습니다.")
	"pa_grand_opening_ko"      = @($KO, -1, "서해국제공항이 오늘 정식 개장합니다. 승객 여러분을 진심으로 환영합니다.")
	"pa_flight0_boarding_en"   = @($EN, -2, "Flight zero is now boarding.")
	"pa_next_worker_ko"        = @($KO, -3, "안내 말씀 드립니다. 다음 근무자께서는, 근무 수칙을 꼭 지켜 주시기 바랍니다.")
	# Gate 0 v2 — 프롤로그 SCENE 04 (탑승교 끝 스피커) 와 타이틀 SCENE 05. "Flight 000" 은 공공공편으로 읽는다.
	"pa_v2_attention"          = @($KO, -2, "승객 여러분께 안내 말씀드립니다.")
	"pa_v2_boarding_start"     = @($KO, -3, "플라이트 공공공편의 탑승을 시작하겠습니다.")
	"pa_v2_boarding_started"   = @($KO, -3, "플라이트 공공공편의 탑승이 시작되었습니다.")
	# Gate 0 v2 — 1장, 뒤틀린 터미널: 출발 안내 (한국어 다음 영어). 마지막 둘은 0편이 플레이어를 부른다.
	"pa_v3_000_ready_ko"       = @($KO, -2, "서해항공 플라이트 공공공편이 출발 준비를 마쳤습니다. 아직 탑승하지 않으신 승객께서는, 영번 탑승구로 오시기 바랍니다.")
	"pa_v3_000_ready_en"       = @($EN, -2, "Seohae Air flight zero zero zero is ready for departure. Passengers not yet on board, please come to gate zero.")
	"pa_v3_depart_ko"          = @($KO, -1, "서해항공 이백십칠편 제주행, 서해항공 사백일편 김포행 항공기가, 지금 출발합니다.")
	"pa_v3_depart_en"          = @($EN, -1, "Seohae Air flight two one seven to Jeju, and flight four zero one to Gimpo, are now departing.")
	"pa_v3_000_wait_ko"        = @($KO, -3, "플라이트 공공공편은, 승객 한 분을 기다리고 있습니다. 승객님, 영번 탑승구로 오시기 바랍니다.")
	"pa_v3_000_wait_en"        = @($EN, -3, "Flight zero zero zero is waiting for one passenger. Passenger, please come to gate zero.")
	"pa_v3_000_final_ko"       = @($KO, -4, "플라이트 공공공편, 최종 탑승 안내입니다. 탑승하지 않으신 승객께서는, 저희가, 모시러 가겠습니다.")
	"pa_v3_000_final_en"       = @($EN, -4, "This is the final call for flight zero zero zero. If you will not come to us, we will come for you.")
}

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)

foreach ($id in $lines.Keys) {
	if ($Only -and -not $id.StartsWith($Only)) {
		continue
	}
	$voice, $rate, $text = $lines[$id]
	$path = Join-Path $outDir ($id + ".wav")
	try {
		$synth.SelectVoice($voice)
	} catch {
		Write-Warning "voice '$voice' missing, using default for $id"
	}
	$synth.Rate = $rate
	$synth.Volume = 100
	try {
		$synth.SetOutputToWaveFile($path, $fmt)
	} catch {
		Write-Warning "cannot write $path"
		continue   # never fall back to speaking through the speakers
	}
	$synth.Speak($text)
	$synth.SetOutputToNull()
	Write-Output ("{0,-28} {1,8} bytes" -f $id, (Get-Item $path).Length)
}
$synth.Dispose()
